#!/usr/bin/env python3
"""
Script to extract TheGates.app from DMG file, compress it, and rename with version.

Usage:
  python compress_build_macos.py <version>
  python compress_build_macos.py <version> --renderer-release --host-renderer-build PATH
Example: python compress_build_macos.py 0.17.1

With --renderer-release the renderer bundled inside TheGates.app/Contents/Frameworks
is verified against the freshly-built one.
"""

import argparse
import sys
import os
import subprocess
import shutil
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import renderer_config as rc

def run_command(command, check=True):
	"""Run a shell command and return the result."""
	try:
		result = subprocess.run(command, shell=True, check=check, capture_output=True, text=True)
		return result
	except subprocess.CalledProcessError as e:
		print(f"Error running command: {command}")
		print(f"Error: {e}")
		if check:
			sys.exit(1)
		return e

def extract_dmg(dmg_path):
	"""Extract TheGates.app from the DMG file."""
	print(f"Extracting {dmg_path}...")
	
	# Create a temporary mount point
	mount_point = "/tmp/TheGates_mount"
	os.makedirs(mount_point, exist_ok=True)
	
	# Mount the DMG
	mount_cmd = f"hdiutil attach '{dmg_path}' -mountpoint '{mount_point}' -readonly"
	result = run_command(mount_cmd)
	
	if result.returncode != 0:
		print("Failed to mount DMG file")
		sys.exit(1)
	
	# Copy TheGates.app from mount point
	app_source = os.path.join(mount_point, "TheGates.app")
	if not os.path.exists(app_source):
		print("TheGates.app not found in DMG file")
		# Unmount before exiting
		run_command(f"hdiutil detach '{mount_point}'", check=False)
		sys.exit(1)
	
	# Copy to current directory
	app_dest = "TheGates.app"
	if os.path.exists(app_dest):
		print("Removing existing TheGates.app...")
		shutil.rmtree(app_dest)
	
	print("Copying TheGates.app...")
	shutil.copytree(app_source, app_dest)
	
	# Unmount the DMG
	print("Unmounting DMG...")
	run_command(f"hdiutil detach '{mount_point}'", check=False)
	
	print("Extraction completed successfully!")

def compress_app(version):
	"""Compress TheGates.app into a zip file with version naming."""
	app_path = "TheGates.app"
	zip_name = f"TheGates_MacOS_{version}.zip"
	
	if not os.path.exists(app_path):
		print(f"Error: {app_path} not found. Make sure extraction was successful.")
		sys.exit(1)
	
	print(f"Compressing {app_path} to {zip_name}...")
	
	# Remove existing zip if it exists
	if os.path.exists(zip_name):
		os.remove(zip_name)
	
	# Create zip file
	with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
		for root, dirs, files in os.walk(app_path):
			for file in files:
				file_path = os.path.join(root, file)
				arcname = os.path.relpath(file_path, os.path.dirname(app_path))
				zipf.write(file_path, arcname)
	
	print(f"Compression completed! Created: {zip_name}")
	
	# Clean up the extracted app
	print("Cleaning up extracted files...")
	shutil.rmtree(app_path)
	print("Cleanup completed!")

def parse_args():
	"""Parse command line arguments."""
	parser = argparse.ArgumentParser(description="Extract TheGates.app from DMG and compress it for release.")
	parser.add_argument("version", help="App version, e.g. 0.17.2")
	parser.add_argument("--renderer-release", action="store_true",
						help="Verify the renderer bundled inside TheGates.app is freshly staged.")
	parser.add_argument("--host-renderer-build", type=Path, default=None,
						help="Path to the freshly-built macOS renderer (required with --renderer-release).")
	return parser.parse_args()

def main():
	"""Main function to orchestrate the extraction and compression process."""
	args = parse_args()
	version = args.version
	dmg_path = "TheGates.app.dmg"

	# Check if DMG file exists
	if not os.path.exists(dmg_path):
		print(f"Error: {dmg_path} not found in current directory")
		sys.exit(1)

	print(f"Starting extraction and compression for version {version}")
	print(f"DMG file: {dmg_path}")
	print("-" * 50)

	try:
		# Step 1: Extract TheGates.app from DMG
		extract_dmg(dmg_path)

		# Step 2: Verify the bundled renderer (renderer-side release only)
		if args.renderer_release:
			basename = Path(rc.bundle_renderer_relpath("macos_framework", rc.current_godot_version())).name
			bundle_path = Path("TheGates.app") / "Contents" / "Frameworks" / basename
			rc.verify_host_bundle_for_release("macos", args.host_renderer_build, bundle_path=bundle_path)

		# Step 3: Compress TheGates.app
		compress_app(version)

		print("-" * 50)
		print(f"Successfully created: TheGates_MacOS_{version}.zip")

	except Exception as e:
		print(f"An error occurred: {e}")
		sys.exit(1)

if __name__ == "__main__":
	main()

