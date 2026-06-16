#!/usr/bin/env python3
"""Zip the Windows release build (run on a Windows host).

Usage:
  python3 compress_build_windows.py 1.0.4 [--force]
  python3 compress_build_windows.py 1.0.4 --force --renderer-release --host-renderer-build PATH

Run with the builds directory as the working directory. Creates:
  Windows/TheGates_Windows_<version>.zip  (TheGates.exe + TheGates.pck + renderer/)

With --renderer-release the Windows bundle renderer is verified against the freshly
-built one.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_zip
import renderer_config as rc

WINDOWS_ENTRIES = ["TheGates.exe", "TheGates.pck", "renderer"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Zip Windows build.")
    parser.add_argument("version", help="App version, e.g. 1.0.4")
    parser.add_argument("--force", action="store_true", help="Overwrite existing zip file.")
    parser.add_argument("--renderer-release", action="store_true",
                        help="Verify the Windows bundle renderer is freshly staged.")
    parser.add_argument("--host-renderer-build", type=Path, default=None,
                        help="Path to the freshly-built Windows renderer (required with --renderer-release).")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    build_zip.validate_version(args.version)

    if args.renderer_release:
        rc.verify_host_bundle_for_release("windows", args.host_renderer_build)

    print(f"Created: {build_zip.build_zip(Path('.'), 'Windows', WINDOWS_ENTRIES, args.version, args.force)}")


if __name__ == "__main__":
    main()
