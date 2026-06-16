"""Generic release-zip helper, shared by the per-platform compress scripts.

Packs the chosen entries from a platform's build directory into
``<OS>/TheGates_<OS>_<version>.zip``. The per-platform compress scripts own
only their entry list and their renderer-staleness guard; the zipping mechanics
live here so they're written and tested once.
"""
from __future__ import annotations

import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

_VERSION_RE = re.compile(r"^[0-9]+(\.[0-9]+){1,3}$")


def validate_version(version: str) -> None:
    if not _VERSION_RE.match(version):
        raise ValueError(f"Invalid version '{version}'. Expected format like 0.17.2")


def build_zip(builds_root: Path, os_name: str, entries: list[str], version: str, overwrite: bool) -> Path:
    """Zip ``entries`` (files or directories, relative to ``builds_root/os_name``)
    into ``builds_root/os_name/TheGates_<os_name>_<version>.zip`` and return its path.

    ``builds_root`` is normally ``Path(".")`` — the compress scripts run with the
    builds directory as CWD — but is explicit so the behavior is testable.
    """
    base = Path(builds_root) / os_name
    output = base / f"TheGates_{os_name}_{version}.zip"

    if output.exists():
        if not overwrite:
            raise FileExistsError(f"Output already exists: {output}. Use --force to overwrite.")
        output.unlink()

    if not base.is_dir():
        raise FileNotFoundError(f"Missing required path: {base}")

    with ZipFile(output, mode="w", compression=ZIP_DEFLATED) as zf:
        for entry in entries:
            entry_path = base / entry
            if not entry_path.exists():
                raise FileNotFoundError(f"Missing required path: {entry_path}")
            if entry_path.is_file():
                zf.write(entry_path, arcname=entry)
            else:
                for file_path in sorted(entry_path.rglob("*")):
                    if file_path.is_file():
                        zf.write(file_path, arcname=str(file_path.relative_to(base)))
    return output
