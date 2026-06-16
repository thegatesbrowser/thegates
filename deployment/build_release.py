#!/usr/bin/env python3

from __future__ import annotations

import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path
import argparse


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
	print(f"==> Running: {' '.join(cmd)}" + (f"\n    in: {cwd}" if cwd else ""))
	return subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=check)


def parse_version(project_path: Path) -> str:
	content = project_path.read_text(encoding="utf-8", errors="ignore").splitlines()
	pattern = re.compile(r'^config/version="([0-9]+(?:\.[0-9]+){1,3})"$')
	for line in content:
		m = pattern.match(line.strip())
		if m:
			return m.group(1)
	raise RuntimeError(f"Failed to parse version from {project_path}")


def parse_preset_template_path(preset_path: Path, preset_name: str) -> Path:
	"""Read custom_template/release from a named preset in export_presets.cfg.

	The preset file is the single source of truth for which template binary
	gets used during export. Reading it here keeps the deployment pipeline
	(e.g., the Windows manifest patch step) in sync with whatever Godot
	itself will pick up — no parallel hardcoded path to drift.
	"""
	target_idx: str | None = None
	current_section: str | None = None
	for raw in preset_path.read_text(encoding="utf-8", errors="ignore").splitlines():
		line = raw.strip()
		if line.startswith("[") and line.endswith("]"):
			current_section = line[1:-1]
			continue
		if current_section is None:
			continue
		# Find the [preset.N] block matching preset_name.
		if (
			target_idx is None
			and current_section.startswith("preset.")
			and "." not in current_section[len("preset.") :]
			and line == f'name="{preset_name}"'
		):
			target_idx = current_section[len("preset.") :]
			continue
		# Then pull custom_template/release from [preset.N.options].
		if (
			target_idx is not None
			and current_section == f"preset.{target_idx}.options"
			and line.startswith('custom_template/release="')
		):
			return Path(line.split('"', 2)[1])
	raise RuntimeError(
		f"custom_template/release not found for preset {preset_name!r} in {preset_path}"
	)


def build_expected_zip_paths(builds_dir: Path, version: str, os_name: str) -> list[Path]:
	paths: list[Path] = []
	if os_name == "Linux":
		paths.append(builds_dir / "Linux" / f"TheGates_Linux_{version}.zip")
		paths.append(builds_dir / "Windows" / f"TheGates_Windows_{version}.zip")
	elif os_name == "Windows":
		paths.append(builds_dir / "Windows" / f"TheGates_Windows_{version}.zip")
	elif os_name == "Darwin":
		paths.append(builds_dir / f"TheGates_MacOS_{version}.zip")
	return paths


def open_cursor_on_linux(folder: Path) -> None:
	"""Best-effort: open a new Cursor window for the given folder on Linux."""
	if platform.system() != "Linux":
		return
	try:
		candidates: list[list[str]] = []
		if shutil.which("cursor"):
			candidates.append(["cursor", "-n", str(folder)])
			candidates.append(["cursor", str(folder)])
		# Fallback to VS Code CLI if Cursor not available in PATH
		if shutil.which("code"):
			candidates.append(["code", "-n", str(folder)])

		for cmd in candidates:
			try:
				subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
				return
			except Exception:
				continue
	except Exception:
		pass


def main() -> int:
	script_dir = Path(__file__).resolve().parent
	repo_root = script_dir.parent
	app_dir = repo_root / "app"
	export_script = repo_root / "deployment" / "export_project.py"
	uploader = repo_root / "deployment" / "upload_build.py"

	os_name = platform.system()

	ap = argparse.ArgumentParser(description="Export + compress + upload a release.")
	ap.add_argument("--renderer-release", action="store_true",
	                help="Renderer-side release: verify/stage the bundle renderer and skip cross-built non-host zips.")
	cli = ap.parse_args()

	print(f"==> Using repo root: {repo_root}")
	print(f"==> Detected OS: {os_name}")

	if os_name not in ("Linux", "Darwin", "Windows"):
		print(f"Unsupported OS: {os_name}. Only Linux, macOS and Windows are supported.")
		return 1

	# 1) Export release builds
	run([sys.executable, str(export_script)], cwd=repo_root)

	# 2) Extract version
	version = parse_version(app_dir / "project.godot")
	print(f"==> App version: {version}")

	uploaded: list[Path] = []

	if os_name == "Linux":
		builds_dir = Path("/media/common/Projects/thegates-folder/AppBuilds")
		compress_script = repo_root / "deployment" / "compress_builds_linux.py"

		print(f"==> Switching to builds dir: {builds_dir}")
		builds_dir.mkdir(parents=True, exist_ok=True)

		print(f"==> Compressing Linux/Windows builds with version {version}...")
		compress_cmd = [sys.executable, str(compress_script), version, "--force"]
		if cli.renderer_release:
			host_renderer = repo_root / "godot" / "bin" / "godot.linuxbsd.template_release.renderer.x86_64"
			compress_cmd += ["--renderer-release", "--host-renderer-build", str(host_renderer)]
		run(compress_cmd, cwd=builds_dir)

		uploaded = build_expected_zip_paths(builds_dir, version, os_name)

	elif os_name == "Windows":
		builds_dir = Path("D:/Projects/thegates-folder/AppBuilds")
		compress_script = repo_root / "deployment" / "compress_build_windows.py"
		manifest_script = repo_root / "deployment" / "patch_windows_manifest.py"
		exported_exe = builds_dir / "Windows" / "TheGates.exe"
		template_exe = parse_preset_template_path(
			app_dir / "export_presets.cfg", "Windows Desktop"
		)

		print(f"==> Switching to builds dir: {builds_dir}")
		builds_dir.mkdir(parents=True, exist_ok=True)

		# Godot's exporter (TemplateModifier::_create_resources) drops the RT_MANIFEST
		# resource when application/modify_resources=true. Reinject it from the
		# launcher template so chromium-sandbox's BrokerServices::SpawnTarget can
		# set up AppContainer in the exported broker process.
		print(f"==> Patching manifest in: {exported_exe}")
		run([sys.executable, str(manifest_script), str(template_exe), str(exported_exe)], cwd=repo_root)

		print(f"==> Compressing Windows build with version {version}...")
		run([sys.executable, str(compress_script), version, "--force"], cwd=builds_dir)

		uploaded = build_expected_zip_paths(builds_dir, version, os_name)

	elif os_name == "Darwin":
		builds_dir = Path("/Users/nordup/Projects/thegates-folder/AppBuilds")
		compress_script = repo_root / "deployment" / "compress_build_macos.py"

		print(f"==> Switching to builds dir: {builds_dir}")
		builds_dir.mkdir(parents=True, exist_ok=True)

		print(f"==> Compressing macOS build with version {version}...")
		run([sys.executable, str(compress_script), version], cwd=builds_dir)

		uploaded = build_expected_zip_paths(builds_dir, version, os_name)

	# Upload created zip files via uploader
	existing = [p for p in uploaded if p.exists()]
	if not existing:
		print("No compressed build files found to upload.")
		return 1

	print("==> Uploading:")
	for p in existing:
		print(f" - {p}")

	run([sys.executable, str(uploader), *[str(p) for p in existing]], cwd=repo_root)

	# Open terminal in requested directory on Linux only
	if os_name == "Linux":
		open_cursor_on_linux(Path("/home/nordup/programs/io.itch.nordup.TheGates"))

	print("==> Done.")
	return 0


if __name__ == "__main__":
	sys.exit(main())
