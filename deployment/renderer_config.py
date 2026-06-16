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
