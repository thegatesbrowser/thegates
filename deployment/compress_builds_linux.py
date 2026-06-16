#!/usr/bin/env python3
"""Zip the Linux and Windows release builds.

Usage:
  python3 compress_builds_linux.py 1.0.4 [--force]
  python3 compress_builds_linux.py 1.0.4 --force --renderer-release --host-renderer-build PATH

Run with the builds directory (AppBuilds) as the working directory. Creates:
  Linux/TheGates_Linux_<version>.zip      (TheGates.x86_64 + renderer/)
  Windows/TheGates_Windows_<version>.zip  (TheGates.exe + TheGates.pck + renderer/)

With --renderer-release the Linux bundle renderer is verified against the freshly
-built one and the cross-built Windows zip is skipped — its renderer can't be built
on a Linux host, so Windows is released from its own machine.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_zip
import renderer_config as rc

LINUX_ENTRIES = ["TheGates.x86_64", "renderer"]
WINDOWS_ENTRIES = ["TheGates.exe", "TheGates.pck", "renderer"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Zip Linux and Windows builds.")
    parser.add_argument("version", help="App version, e.g. 1.0.4")
    parser.add_argument("--force", action="store_true", help="Overwrite existing zip files.")
    parser.add_argument("--renderer-release", action="store_true",
                        help="Verify the Linux bundle renderer is freshly staged; skip the cross-built Windows zip.")
    parser.add_argument("--host-renderer-build", type=Path, default=None,
                        help="Path to the freshly-built Linux renderer (required with --renderer-release).")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    build_zip.validate_version(args.version)

    if args.renderer_release:
        rc.verify_host_bundle_for_release("linux", args.host_renderer_build)

    print(f"Created: {build_zip.build_zip(Path('.'), 'Linux', LINUX_ENTRIES, args.version, args.force)}")

    if args.renderer_release:
        print("[STALE-RENDERER] Windows: cross-built on a Linux host cannot carry a freshly-built "
              "Windows renderer — skipping Windows zip. Build + publish Windows on its own machine.")
    else:
        print(f"Created: {build_zip.build_zip(Path('.'), 'Windows', WINDOWS_ENTRIES, args.version, args.force)}")


if __name__ == "__main__":
    main()
