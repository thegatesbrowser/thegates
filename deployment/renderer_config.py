"""Single source of truth for renderer naming, shared by the deployment scripts.

Reads app/resources/renderer_executable.tres so nothing hardcodes renderer
filenames or the current godot version. Verification in the publish guard is by
content (md5) — there are no marker files or version tags on the renderer.
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TRES_PATH = REPO_ROOT / "app" / "resources" / "renderer_executable.tres"

_OS_DIR = {"linux": "Linux", "windows": "Windows", "macos": "macOS"}


def os_dir(platform_key: str) -> str:
    """AppBuilds subdirectory for a platform key ('linux' -> 'Linux')."""
    return _OS_DIR[platform_key]


def _read_tres_value(key: str, tres_path: Path = TRES_PATH) -> str:
    text = Path(tres_path).read_text(encoding="utf-8")
    m = re.search(rf'^{re.escape(key)}\s*=\s*"([^"]*)"', text, re.MULTILINE)
    if not m:
        raise RuntimeError(f"{key} not found in {tres_path}")
    return m.group(1)


def current_godot_version(tres_path: Path = TRES_PATH) -> str:
    """The bundled renderer's godot version, e.g. '4.5'."""
    return _read_tres_value("current_godot_version", tres_path)


def bundle_renderer_relpath(platform_key: str, godot_version: str, tres_path: Path = TRES_PATH) -> str:
    """Bundle-relative renderer path, e.g. 'renderer/Renderer-godot_v4.5.x86_64'."""
    return _read_tres_value(platform_key, tres_path) % godot_version


def file_md5(path: Path) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def guard_host_bundle(bundle_renderer: Path, build_output: Path) -> None:
    """Fail (SystemExit) unless the bundled renderer is byte-identical to the
    freshly-built renderer. Catches a skipped staging step on a renderer-side
    release (the original stale-bundle bug)."""
    if not Path(build_output).is_file():
        raise SystemExit(
            f"[STALE-RENDERER] renderer build output missing: {build_output}. "
            f"Build the renderer before releasing, or drop --renderer-release."
        )
    if not Path(bundle_renderer).is_file():
        raise SystemExit(f"[STALE-RENDERER] bundle renderer missing: {bundle_renderer}. Run stage_renderer.py.")
    if file_md5(bundle_renderer) != file_md5(build_output):
        raise SystemExit(
            f"[STALE-RENDERER] bundle renderer is stale (does not match the freshly-built "
            f"{build_output.name}). Run stage_renderer.py for this release."
        )


def verify_host_bundle_for_release(
    platform_key: str, host_build, builds_root: Path = Path("."), bundle_path: Path | None = None
) -> None:
    """Renderer-side release guard for the host platform's own bundle: require the
    freshly-built renderer and fail unless the staged bundle matches it byte-for-byte.
    Resolves the bundle path the same way stage_renderer.py wrote it, so the two
    sides can't drift. ``host_build`` is the path passed via --host-renderer-build.
    ``bundle_path``, if given, overrides the resolved path outright — for layouts
    that don't mirror stage_renderer.py's AppBuilds/<OS>/<relpath> layout (macOS,
    where the shipped renderer lives inside the exported .app)."""
    if host_build is None:
        raise SystemExit("--host-renderer-build is required with --renderer-release")
    bundle = (
        Path(bundle_path)
        if bundle_path is not None
        else Path(builds_root) / os_dir(platform_key) / bundle_renderer_relpath(platform_key, current_godot_version())
    )
    guard_host_bundle(bundle, host_build)
