#!/usr/bin/env python3

from __future__ import annotations

import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path


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


def open_folder_and_url(builds_dir: Path, url: str) -> None:
	os_name = platform.system()
	try:
		if os_name == "Linux":
			# fire-and-forget
			subprocess.Popen(["xdg-open", str(builds_dir)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
		elif os_name == "Darwin":
			subprocess.Popen(["open", str(builds_dir)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			subprocess.Popen(["open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	except Exception:
		# Non-fatal if opening fails
		pass


def main() -> int:
	script_dir = Path(__file__).resolve().parent
	repo_root = script_dir.parent
	app_dir = repo_root / "app"
	export_script = repo_root / "deployment" / "export_project.py"
	open_url = "https://devs.thegates.io/files/builds/"

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
		run([sys.executable, str(compress_dst), version], cwd=builds_dir)

		open_folder_and_url(builds_dir, open_url)

	elif os_name == "Darwin":
		builds_dir = Path("/Users/nordup/Projects/thegates-folder/AppBuilds")
		compress_script = repo_root / "deployment" / "compress_build_macos.py"

		print(f"==> Switching to builds dir: {builds_dir}")
		builds_dir.mkdir(parents=True, exist_ok=True)

		print(f"==> Compressing macOS build with version {version}...")
		run([sys.executable, str(compress_script), version], cwd=builds_dir)

		open_folder_and_url(builds_dir, open_url)

	print("==> Done.")
	return 0


if __name__ == "__main__":
	sys.exit(main())
