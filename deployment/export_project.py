#!/usr/bin/env python3
"""
Automated Godot export script.

Behavior:
- On Linux: exports release build for preset "Linux/X11" (export project)
  and exports release pack for preset "Windows Desktop" (export pck).
- On macOS: exports release build for preset "macOS" (export project).
- On Windows: exports release build for preset "Windows Desktop" (export project).

All exports use the export paths defined in app/export_presets.cfg.
For pack export, the output .pck path is derived from the preset's export_path
by replacing ".exe" with ".pck" (or appending ".pck" if no extension found).

Special case: when exporting Windows pack from Linux host, override output path to
"/media/common/Projects/thegates-folder/AppBuilds/Windows/TheGates.pck".

Editor binaries to use:
- Linux:  godot/bin/godot.linuxbsd.editor.dev.x86_64.llvm
- macOS:  godot/bin/godot.macos.editor.dev.arm64
- Windows: godot/bin/godot.windows.editor.dev.x86_64.exe

Only release builds are exported (uses --export-release).
"""

from __future__ import annotations

import os
import platform
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional


REPO_ROOT = Path(__file__).resolve().parent.parent
APP_DIR = REPO_ROOT / "app"
EXPORT_PRESETS_PATH = APP_DIR / "export_presets.cfg"


LINUX_EDITOR_RELATIVE = Path("godot/bin/godot.linuxbsd.editor.dev.x86_64.llvm")
MACOS_EDITOR_RELATIVE = Path("godot/bin/godot.macos.editor.dev.arm64")
WINDOWS_EDITOR_RELATIVE = Path("godot/bin/godot.windows.editor.dev.x86_64.exe")

LINUX_WINDOWS_PCK_OVERRIDE_PATH = Path("/media/common/Projects/thegates-folder/AppBuilds/Windows/TheGates.pck")


@dataclass
class ExportPreset:
    index: int
    name: str
    platform: Optional[str]
    export_path: Optional[str]


def read_export_presets(cfg_path: Path) -> Dict[str, ExportPreset]:
    """Parse Godot export_presets.cfg and return presets keyed by name.

    We only care about fields under [preset.N]: name, platform, export_path.
    """
    if not cfg_path.exists():
        raise FileNotFoundError(f"export presets not found: {cfg_path}")

    presets: Dict[str, ExportPreset] = {}
    current: Optional[ExportPreset] = None

    with cfg_path.open("r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("["):
                # Starting a new section.
                if line.startswith("[preset.") and line.endswith("]"):
                    try:
                        idx_str = line[len("[preset.") : -1]
                        idx = int(idx_str)
                    except ValueError:
                        current = None
                    else:
                        current = ExportPreset(index=idx, name="", platform=None, export_path=None)
                else:
                    # Any non-preset section ends current preset parsing
                    current = None
                continue

            if current is None:
                continue

            if line.startswith("name="):
                current.name = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("platform="):
                current.platform = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("export_path="):
                current.export_path = line.split("=", 1)[1].strip().strip('"')

            # Once we have a name, keep it indexed so later lookups are easy
            if current.name:
                presets[current.name] = current

    return presets


def ensure_editor_binary() -> Path:
    system = platform.system()
    if system == "Linux":
        editor_rel = LINUX_EDITOR_RELATIVE
    elif system == "Darwin":
        editor_rel = MACOS_EDITOR_RELATIVE
    elif system == "Windows":
        editor_rel = WINDOWS_EDITOR_RELATIVE
    else:
        raise RuntimeError(f"Unsupported OS for this script: {system}")

    editor_path = (REPO_ROOT / editor_rel).resolve()
    if not editor_path.exists():
        raise FileNotFoundError(
            f"Godot editor binary not found: {editor_path}\n"
            f"Expected relative path: {editor_rel}"
        )
    return editor_path


def run_cmd(cmd: List[str], cwd: Path) -> None:
    print(f"Running: {shlex.join(cmd)}\n  in: {cwd}")
    subprocess.run(cmd, cwd=str(cwd), check=True)


def derive_pck_path_from_export_path(export_path: str) -> Path:
    path = Path(export_path)
    if path.suffix.lower() == ".exe":
        return path.with_suffix(".pck")
    if path.suffix:
        # Replace any existing extension with .pck
        return path.with_suffix(".pck")
    return path.with_suffix(".pck")


def export_linux_and_windows_pack(editor: Path, presets: Dict[str, ExportPreset]) -> None:
    # Linux project export (uses export path defined in preset)
    linux_preset_name = "Linux/X11"
    if linux_preset_name not in presets:
        raise KeyError(f"Preset not found: {linux_preset_name}")

    run_cmd(
        [str(editor), "--headless", "--export-release", linux_preset_name],
        cwd=APP_DIR,
    )

    # Windows pack export (override .pck path per requirement when on Linux)
    windows_preset_name = "Windows Desktop"
    win_preset = presets.get(windows_preset_name)
    if win_preset is None:
        raise KeyError(f"Preset not found: {windows_preset_name}")

    # Use the override path instead of preset-defined path
    pck_out_path = LINUX_WINDOWS_PCK_OVERRIDE_PATH

    # Ensure output directory exists for the pack
    pck_out_dir = Path(pck_out_path).parent
    try:
        pck_out_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        # If directory is not creatable (e.g., Windows drive on Linux), let Godot handle/raise.
        pass

    run_cmd(
        [
            str(editor),
            "--headless",
            "--export-pack",
            windows_preset_name,
            str(pck_out_path),
        ],
        cwd=APP_DIR,
    )


def export_macos(editor: Path, presets: Dict[str, ExportPreset]) -> None:
    mac_preset_name = "macOS"
    if mac_preset_name not in presets:
        raise KeyError(f"Preset not found: {mac_preset_name}")

    run_cmd(
        [str(editor), "--headless", "--export-release", mac_preset_name],
        cwd=APP_DIR,
    )


def export_windows(editor: Path, presets: Dict[str, ExportPreset]) -> None:
    windows_preset_name = "Windows Desktop"
    if windows_preset_name not in presets:
        raise KeyError(f"Preset not found: {windows_preset_name}")

    run_cmd(
        [str(editor), "--headless", "--export-release", windows_preset_name],
        cwd=APP_DIR,
    )


def import_project(editor: Path) -> None:
    # Ensure all assets are imported prior to export
    run_cmd([str(editor), "--headless", "--import"], cwd=APP_DIR)


def main() -> int:
    try:
        presets = read_export_presets(EXPORT_PRESETS_PATH)
        editor = ensure_editor_binary()
        system = platform.system()

        # Always import project before any export
        import_project(editor)

        if system == "Linux":
            export_linux_and_windows_pack(editor, presets)
        elif system == "Darwin":
            export_macos(editor, presets)
        elif system == "Windows":
            export_windows(editor, presets)
        else:
            raise RuntimeError(f"Unsupported OS: {system}")

        print("All exports completed successfully.")
        return 0
    except subprocess.CalledProcessError as e:
        print(f"Export command failed with exit code {e.returncode}")
        return e.returncode
    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())


