"""Stage a freshly-built renderer into the app bundle AND produce its server zip
from the same binary, so the two can never diverge.

Only the current godot version (per renderer_executable.tres) is bundled; other
versions (e.g. 4.3) are download-only -> server zip only.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

sys.path.insert(0, str(Path(__file__).resolve().parent))
import renderer_config as rc

RENDERER_MARKER = b"RENDERER-START"


def _sanity_check(built: Path) -> None:
    if not built.is_file():
        raise SystemExit(f"--built not found: {built}")
    if built.stat().st_size < 1024:
        raise SystemExit(f"--built too small to be a renderer: {built}")
    if RENDERER_MARKER not in built.read_bytes():
        raise SystemExit(f"--built does not contain {RENDERER_MARKER.decode()} (not a renderer?): {built}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Stage a renderer into the bundle + make its server zip.")
    ap.add_argument("--built", required=True, type=Path)
    ap.add_argument("--godot-version", required=True)
    ap.add_argument("--platform", default="linux", choices=["linux", "windows", "macos"])
    ap.add_argument("--app-builds", required=True, type=Path)
    ap.add_argument("--server-zip-dir", required=True, type=Path)
    ap.add_argument("--tres", type=Path, default=rc.TRES_PATH)
    args = ap.parse_args()

    _sanity_check(args.built)

    relpath = rc.bundle_renderer_relpath(args.platform, args.godot_version, args.tres)
    basename = Path(relpath).name

    # Server zip (always): <platform>-<version>.zip with the renderer at top level.
    args.server_zip_dir.mkdir(parents=True, exist_ok=True)
    server_zip = args.server_zip_dir / f"{args.platform}-{args.godot_version}.zip"
    if server_zip.exists():
        server_zip.unlink()
    with ZipFile(server_zip, "w", ZIP_DEFLATED) as zf:
        zf.write(args.built, arcname=basename)
    print(f"[stage] server zip: {server_zip}")

    # Bundle copy (only for the current/bundled version).
    if args.godot_version == rc.current_godot_version(args.tres):
        dest = args.app_builds / rc.os_dir(args.platform) / relpath
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.built, dest)
        print(f"[stage] bundled: {dest}")
    else:
        print(f"[stage] {args.godot_version} is download-only; not bundled")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
