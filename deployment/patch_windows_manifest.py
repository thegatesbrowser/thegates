#!/usr/bin/env python3
"""
Reinject the launcher template's RT_MANIFEST resource into an exported
Windows executable.

Why: Godot's Windows exporter (see godot/platform/windows/export/template_modifier.cpp,
TemplateModifier::_create_resources) rebuilds the PE resource section from
scratch with only ICON + GROUP_ICON + VERSION when application/modify_resources
is true. RT_MANIFEST is dropped. Without a manifest, Windows applies legacy
execution context (no longPathAware, no supportedOS, no Common-Controls v6) and
chromium-sandbox's BrokerServices::SpawnTarget fails because the broker process
can't set up AppContainer properly.

This script reads the manifest bytes from the launcher template binary and
writes them back into the exported .exe via the Win32
BeginUpdateResource / UpdateResource / EndUpdateResource APIs. It then
re-reads the target and verifies the manifest round-tripped intact.

Usage:
  python patch_windows_manifest.py <source_template.exe> <target.exe>
"""

from __future__ import annotations

import ctypes
import sys
from ctypes import wintypes
from pathlib import Path

import pefile


RT_MANIFEST = 24


# MAKEINTRESOURCE in winuser.h: numeric resource IDs are passed to the Win32
# resource APIs as fake pointers whose low word holds the integer ID. A direct
# ctypes.cast(int, LPCWSTR) reproduces that contract — Windows never
# dereferences the "pointer" when the high bits are zero (IS_INTRESOURCE check).
def _make_int_resource(i: int):
	return ctypes.cast(i, wintypes.LPCWSTR)


def extract_manifest(template_path: Path) -> tuple[bytes, int, int]:
	"""Return (manifest_bytes, resource_name_id, language_id) from an .exe."""
	pe = pefile.PE(str(template_path), fast_load=True)
	pe.parse_data_directories(
		directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]]
	)
	try:
		for r in pe.DIRECTORY_ENTRY_RESOURCE.entries:
			if r.struct.Id == RT_MANIFEST:
				for ri in r.directory.entries:
					for lang in ri.directory.entries:
						off = lang.data.struct.OffsetToData
						size = lang.data.struct.Size
						data = pe.get_memory_mapped_image()[off : off + size]
						return data, ri.id, lang.id
	finally:
		pe.close()
	raise RuntimeError(f"No RT_MANIFEST resource found in {template_path}")


def inject_manifest(target_path: Path, manifest: bytes, name_id: int, lang_id: int) -> None:
	"""Embed `manifest` as RT_MANIFEST resource (name_id, lang_id) in target."""
	kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

	BeginUpdateResourceW = kernel32.BeginUpdateResourceW
	BeginUpdateResourceW.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
	BeginUpdateResourceW.restype = wintypes.HANDLE

	UpdateResourceW = kernel32.UpdateResourceW
	UpdateResourceW.argtypes = [
		wintypes.HANDLE,
		wintypes.LPCWSTR,
		wintypes.LPCWSTR,
		wintypes.WORD,
		wintypes.LPVOID,
		wintypes.DWORD,
	]
	UpdateResourceW.restype = wintypes.BOOL

	EndUpdateResourceW = kernel32.EndUpdateResourceW
	EndUpdateResourceW.argtypes = [wintypes.HANDLE, wintypes.BOOL]
	EndUpdateResourceW.restype = wintypes.BOOL

	# bDeleteExistingResources=False: keep ICON/GROUP_ICON/VERSION intact,
	# only add/replace the RT_MANIFEST entry.
	h = BeginUpdateResourceW(str(target_path), False)
	if not h:
		raise OSError(ctypes.get_last_error(), "BeginUpdateResource failed")

	buf = ctypes.create_string_buffer(manifest, len(manifest))
	ok = UpdateResourceW(
		h,
		_make_int_resource(RT_MANIFEST),
		_make_int_resource(name_id),
		lang_id,
		buf,
		len(manifest),
	)
	if not ok:
		err = ctypes.get_last_error()
		EndUpdateResourceW(h, True)  # discard
		raise OSError(err, "UpdateResource failed")

	# bDiscard=False: commit the pending update to disk.
	ok = EndUpdateResourceW(h, False)
	if not ok:
		raise OSError(ctypes.get_last_error(), "EndUpdateResource (commit) failed")


def verify_manifest(target_path: Path, expected: bytes) -> None:
	"""Re-read target and confirm RT_MANIFEST round-tripped intact.

	Catches silent Win32 update failures (antivirus interference, locked
	files, partially-applied resource updates) before a broken binary ships.
	"""
	got, _, _ = extract_manifest(target_path)
	if got != expected:
		raise RuntimeError(
			f"Manifest verification failed for {target_path}: "
			f"wrote {len(expected)} bytes, read back {len(got)} bytes"
		)


def main(argv: list[str]) -> int:
	if sys.platform != "win32":
		print(f"patch_windows_manifest.py is Windows-only (running on {sys.platform})")
		return 1
	if len(argv) != 3:
		print("Usage: patch_windows_manifest.py <source_template.exe> <target.exe>")
		return 2

	source = Path(argv[1]).resolve()
	target = Path(argv[2]).resolve()
	if not source.exists():
		print(f"Source template not found: {source}")
		return 1
	if not target.exists():
		print(f"Target not found: {target}")
		return 1

	manifest, name_id, lang_id = extract_manifest(source)
	print(f"==> manifest: {len(manifest)} bytes, id={name_id}, lang={lang_id}")
	inject_manifest(target, manifest, name_id, lang_id)
	verify_manifest(target, manifest)
	print(f"==> manifest injected and verified in {target}")
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv))
