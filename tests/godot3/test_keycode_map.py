#!/usr/bin/env python3
"""Check input_event_compat's Godot 4 -> Godot 3 keycode mapping.

The mapping is re-derived here from the same source of truth the C++ uses --
the two engines' core/os/keyboard.h -- so a wrong table entry fails instead of
silently delivering the wrong key to a gate.

The Godot 4 header comes from the working tree; the Godot 3 header and the
input_event_compat source come from the `tg-3.6` branch of the same `godot/`
submodule, so both engines stay checked in one place.

Run: python3 tests/godot3/test_keycode_map.py
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_REPO = REPO_ROOT / "godot"
GODOT3_BRANCH = "tg-3.6"

GODOT4_KEYBOARD = GODOT_REPO / "core" / "os" / "keyboard.h"


def branch_blob(path_in_branch: str) -> Path:
    """Materialize a file from the tg-3.6 branch so the parsers can read it."""
    result = subprocess.run(
        ["git", "-C", str(GODOT_REPO), "show", "%s:%s" % (GODOT3_BRANCH, path_in_branch)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(
            "cannot read %s from %s: %s (fetch/checkout the branch in godot/ first)"
            % (path_in_branch, GODOT3_BRANCH, result.stderr.strip())
        )
    handle = tempfile.NamedTemporaryFile("w", suffix=".h" if path_in_branch.endswith(".h") else ".cpp", delete=False)
    handle.write(result.stdout)
    handle.close()
    return Path(handle.name)


GODOT3_KEYBOARD = branch_blob("core/os/keyboard.h")
COMPAT_SOURCE = branch_blob("modules/the_gates/ipc/input_event_compat.cpp")

GODOT4_SPECIAL = 1 << 22
GODOT3_SPKEY = 1 << 24

# Names that exist in both engines but were spelled differently.
NAME_ALIASES = {
    "HYPER": "HYPER_L",
    "KEY_DELETE": "DELETE",
    "CTRL": "CONTROL",
}


def parse_special_keys(path: Path, base_symbol: str, strip_prefix: str = "") -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(r"^\s*(\w+)\s*=\s*%s\s*\|\s*(0x[0-9a-fA-F]+),?\s*$" % base_symbol, re.MULTILINE)
    keys = {}
    for name, value in pattern.findall(text):
        if strip_prefix and name.startswith(strip_prefix):
            name = name[len(strip_prefix):]
        keys[name] = int(value, 16)
    if not keys:
        raise SystemExit("no special keys parsed from %s" % path)
    return keys


def parse_remap_table(path: Path) -> dict[int, int]:
    text = path.read_text(encoding="utf-8")
    block = re.search(r"KEYCODE_REMAPS\[\]\s*=\s*\{(.*?)\};", text, re.DOTALL)
    if not block:
        raise SystemExit("KEYCODE_REMAPS not found in %s" % path)
    pairs = re.findall(r"\{\s*(0x[0-9a-fA-F]+)\s*,\s*(0x[0-9a-fA-F]+)\s*\}", block.group(1))
    return {int(a, 16): int(b, 16) for a, b in pairs}


def parse_int_constant(path: Path, name: str) -> int:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"const int %s = (0x[0-9a-fA-F]+|\d+);" % name, text)
    if not match:
        raise SystemExit("%s not found in %s" % (name, path))
    return int(match.group(1), 0)


class Mapper:
    """Python mirror of tg_keycode_godot4_to_godot3."""

    def __init__(self, source: Path):
        self.remaps = parse_remap_table(source)
        self.f16 = parse_int_constant(source, "GODOT4_F16")
        self.kp_first = parse_int_constant(source, "GODOT4_KP_FIRST")
        self.unknown_low = parse_int_constant(source, "GODOT4_UNKNOWN_LOW")
        self.launch0_g4 = parse_int_constant(source, "GODOT4_LAUNCH0")
        self.launchf_g4 = parse_int_constant(source, "GODOT4_LAUNCHF")
        self.launch0_g3 = parse_int_constant(source, "GODOT3_LAUNCH0")

    def __call__(self, keycode: int) -> int:
        if not keycode & GODOT4_SPECIAL:
            return keycode
        low = keycode & (GODOT4_SPECIAL - 1)
        if low == self.unknown_low:
            return GODOT3_SPKEY | 0xFFFFFF
        if low <= self.f16 or low >= self.kp_first:
            return GODOT3_SPKEY | low
        if self.launch0_g4 <= low <= self.launchf_g4:
            return GODOT3_SPKEY | (self.launch0_g3 + (low - self.launch0_g4))
        if low in self.remaps:
            return GODOT3_SPKEY | self.remaps[low]
        return GODOT3_SPKEY | 0xFFFFFF  # KEY_UNKNOWN


def main() -> int:
    g4 = parse_special_keys(GODOT4_KEYBOARD, "SPECIAL")
    g3 = parse_special_keys(GODOT3_KEYBOARD, "SPKEY", strip_prefix="KEY_")
    mapper = Mapper(COMPAT_SOURCE)

    failures = []
    shared = 0
    for name, g4_low in sorted(g4.items()):
        g3_name = NAME_ALIASES.get(name, name)
        if g3_name not in g3:
            continue
        shared += 1
        expected = GODOT3_SPKEY | g3[g3_name]
        actual = mapper(GODOT4_SPECIAL | g4_low)
        if actual != expected:
            failures.append("%s: got 0x%X, keyboard.h says 0x%X" % (name, actual, expected))

    # Printable keys must pass through untouched.
    for codepoint in (ord("A"), ord("z"), ord("0"), ord(" "), 0x00E9):
        if mapper(codepoint) != codepoint:
            failures.append("printable 0x%X was rewritten" % codepoint)

    # A Godot 4 key with no Godot 3 counterpart must degrade, not collide.
    f17 = GODOT4_SPECIAL | 0x2C
    if mapper(f17) != (GODOT3_SPKEY | 0xFFFFFF):
        failures.append("F17 should map to KEY_UNKNOWN, got 0x%X" % mapper(f17))

    if shared < 60:
        failures.append("only %d shared key names found; parsing is probably broken" % shared)

    for failure in failures:
        print("FAIL %s" % failure)
    print("%d shared special keys checked, %d failures" % (shared, len(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
