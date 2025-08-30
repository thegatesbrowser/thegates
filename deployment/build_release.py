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


def build_expected_zip_paths(builds_dir: Path, version: str, os_name: str) -> list[Path]:
	paths: list[Path] = []
	if os_name == "Linux":
		paths.append(builds_dir / "Linux" / f"TheGates_Linux_{version}.zip")
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
	print(f"==> Using repo root: {repo_root}")
	print(f"==> Detected OS: {os_name}")

	if os_name not in ("Linux", "Darwin"):
		print(f"Unsupported OS: {os_name}. Only Linux and macOS are supported.")
		return 1

	# 1) Export release builds
	run([sys.executable, str(export_script)], cwd=repo_root)

	# 2) Extract version
	version = parse_version(app_dir / "project.godot")
	print(f"==> App version: {version}")

	uploaded: list[Path] = []

	if os_name == "Linux":
		builds_dir = Path("/media/common/Projects/thegates-folder/AppBuilds")
		compress_src = repo_root / "deployment" / "compress_builds_linux.py"
		compress_dst = builds_dir / "compress_builds_linux.py"

		print(f"==> Switching to builds dir: {builds_dir}")
		builds_dir.mkdir(parents=True, exist_ok=True)

		# Ensure compressor resides in builds dir so its __file__ parent matches expected root
		if not compress_dst.exists():
			print("==> Copying compressor to builds dir...")
			shutil.copy2(compress_src, compress_dst)

		print(f"==> Compressing Linux/Windows builds with version {version}...")
		run([sys.executable, str(compress_dst), version, "--force"], cwd=builds_dir)

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
