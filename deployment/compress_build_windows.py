#!/usr/bin/env python3
"""
Zip builder for TheGates Windows build.

Usage:
  python3 compress_build_windows.py 0.17.2

Creates, in-place:
  Windows/TheGates_Windows_<version>.zip containing: TheGates.exe, TheGates.pck, renderer/

By default, refuses to overwrite existing zip files. Use --force to overwrite.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED


def validate_version(version: str) -> None:
	pattern = re.compile(r"^[0-9]+(\.[0-9]+){1,3}$")
	if not pattern.match(version):
		raise ValueError(
			f"Invalid version '{version}'. Expected format like 0.17.2"
		)


def ensure_exists(path: Path) -> None:
	if not path.exists():
		raise FileNotFoundError(f"Missing required path: {path}")


def zip_entries(base_dir: Path, entries: list[str], output_zip: Path, overwrite: bool) -> None:
	if output_zip.exists():
		if not overwrite:
			raise FileExistsError(
				f"Output already exists: {output_zip}. Use --force to overwrite."
			)
		output_zip.unlink()

	# Ensure base directory exists
	ensure_exists(base_dir)

	with ZipFile(output_zip, mode="w", compression=ZIP_DEFLATED) as zf:
		for entry_name in entries:
			entry_path = base_dir / entry_name
			ensure_exists(entry_path)

			if entry_path.is_file():
				# Store at top-level inside the archive
				zf.write(entry_path, arcname=entry_name)
			else:
				# Walk directory and add files with relative paths rooted at base_dir
				for file_path in entry_path.rglob("*"):
					if file_path.is_file():
						arcname = file_path.relative_to(base_dir)
						zf.write(file_path, arcname=str(arcname))


def build_windows_zip(version: str, overwrite: bool) -> Path:
	windows_dir = Path("Windows")
	output_zip = windows_dir / f"TheGates_Windows_{version}.zip"
	entries = [
		"TheGates.exe",
		"TheGates.pck",
		"renderer",
	]
	zip_entries(windows_dir, entries, output_zip, overwrite)
	return output_zip


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Zip Windows build.")
	parser.add_argument("version", help="App version, e.g. 0.17.2")
	parser.add_argument(
		"--force",
		action="store_true",
		help="Overwrite existing zip file if it exists.",
	)
	return parser.parse_args()


def main() -> None:
	args = parse_args()
	validate_version(args.version)

	windows_zip = build_windows_zip(args.version, args.force)
	print(f"Created: {windows_zip}")


if __name__ == "__main__":
	main()
