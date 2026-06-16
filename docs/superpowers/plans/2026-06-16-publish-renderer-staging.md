# Publish Renderer-Bundle Staging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make it structurally impossible for the `/publish` pipeline to ship a stale bundled renderer on a renderer-side release.

**Architecture:** A single `stage_renderer.py` copies the freshly-built renderer into the app bundle *and* produces the server zip from the same binary (one source). The compress step gains a `--renderer-release` guard that, for the host platform, fails unless the bundled renderer byte-matches the fresh build output, and for cross-built non-host platforms skips + flags the zip. All gated on the `RENDERER_RELEASE` flag the pipeline already computes; launcher-only releases are untouched. Verification is by content (md5) — no version tags or marker files.

**Tech Stack:** Python 3 (stdlib only: `argparse`, `pathlib`, `zipfile`, `hashlib`, `re`, `platform`). Tests are dependency-free self-running scripts (plain `assert` + a `__main__` runner).

**Spec:** `docs/superpowers/specs/2026-06-16-publish-renderer-staging-design.md`

---

## File Structure

- **Create** `deployment/renderer_config.py` — single source of truth: reads `app/resources/renderer_executable.tres` for the current godot version and per-platform renderer filename pattern; md5 helper.
- **Create** `deployment/stage_renderer.py` — the only thing that writes a bundle renderer; also produces the server zip from the same binary.
- **Modify** `deployment/compress_builds_linux.py` — add `--renderer-release` + `--host-renderer-build`; host (Linux) bundle md5-verified, non-host (Windows) bundle skipped + flagged.
- **Modify** `deployment/compress_build_windows.py` — same `--renderer-release` guard, host = Windows only.
- **Modify** `deployment/build_release.py` — add `--renderer-release`, forward it + the build-output path to the compress script.
- **Modify** `.claude/commands/publish.md` — Step 4 calls `stage_renderer.py`; Step 5 passes `--renderer-release`.
- **Create** `deployment/tests/test_renderer_config.py`, `deployment/tests/test_stage_renderer.py`, `deployment/tests/test_compress_guard.py` — hermetic tests using temp dirs + fake renderer files.

macOS (`compress_build_macos.py`, `.app`/Frameworks staging) is a deferred extension point per the spec — not in this plan.

---

## Task 1: `renderer_config.py` — shared config + md5

**Files:**
- Create: `deployment/renderer_config.py`
- Test: `deployment/tests/test_renderer_config.py`

- [ ] **Step 1: Write the failing test**

```python
# deployment/tests/test_renderer_config.py
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import renderer_config as rc

FAKE_TRES = '''[resource]
current_godot_version = "4.5"
supported_godot_versions = Array[String](["4.3", "4.5"])
linux = "renderer/Renderer-godot_v%s.x86_64"
windows = "renderer/Renderer-godot_v%s.exe"
macos = "renderer/Renderer-godot_v%s.universal"
'''


def _tres(tmp: Path) -> Path:
    p = tmp / "renderer_executable.tres"
    p.write_text(FAKE_TRES)
    return p


def test_current_godot_version(tmp_path):
    assert rc.current_godot_version(_tres(tmp_path)) == "4.5"


def test_bundle_relpath_linux(tmp_path):
    assert rc.bundle_renderer_relpath("linux", "4.5", _tres(tmp_path)) == "renderer/Renderer-godot_v4.5.x86_64"


def test_bundle_relpath_windows_43(tmp_path):
    assert rc.bundle_renderer_relpath("windows", "4.3", _tres(tmp_path)) == "renderer/Renderer-godot_v4.3.exe"


def test_os_dir():
    assert rc.os_dir("linux") == "Linux"
    assert rc.os_dir("windows") == "Windows"


def test_file_md5(tmp_path):
    f = tmp_path / "x.bin"
    f.write_bytes(b"hello")
    assert rc.file_md5(f) == "5d41402abc4b2a76b9719d911017c592"


def _run_all():
    import tempfile
    failures = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            with tempfile.TemporaryDirectory() as d:
                try:
                    fn(Path(d)) if fn.__code__.co_argcount else fn()
                    print(f"PASS {name}")
                except AssertionError as e:
                    print(f"FAIL {name}: {e}"); failures += 1
    return failures


if __name__ == "__main__":
    sys.exit(1 if _run_all() else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 deployment/tests/test_renderer_config.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'renderer_config'`.

- [ ] **Step 3: Write the module**

```python
# deployment/renderer_config.py
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 deployment/tests/test_renderer_config.py`
Expected: PASS — all 5 lines `PASS test_…`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add deployment/renderer_config.py deployment/tests/test_renderer_config.py
git commit -m "deploy: shared renderer_config (tres reader + md5) for staging/guard"
```

---

## Task 2: `stage_renderer.py` — stage to bundle + produce server zip

**Files:**
- Create: `deployment/stage_renderer.py`
- Test: `deployment/tests/test_stage_renderer.py`

Behavior: produce `<server-zip-dir>/<platform>-<godot_version>.zip` (entry = renderer basename) from `--built`; and **if `--godot-version` is the current version**, copy `--built` into `<app-builds>/<OS>/<relpath>`. Sanity-check `--built` is a real renderer.

- [ ] **Step 1: Write the failing test**

```python
# deployment/tests/test_stage_renderer.py
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

DEPLOY = Path(__file__).resolve().parent.parent
SCRIPT = DEPLOY / "stage_renderer.py"

FAKE_TRES = '''[resource]
current_godot_version = "4.5"
linux = "renderer/Renderer-godot_v%s.x86_64"
'''


def _fake_renderer(path: Path):
    # contains the RENDERER-START marker the staging sanity-check looks for
    path.write_bytes(b"ELF\x00padding...RENDERER-START..." + b"\x00" * 4096)


def _run(args, tres):
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--tres", str(tres), *args],
        capture_output=True, text=True,
    )


def test_current_version_copies_bundle_and_makes_server_zip():
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        tres = tmp / "r.tres"; tres.write_text(FAKE_TRES)
        built = tmp / "built.x86_64"; _fake_renderer(built)
        app_builds = tmp / "AppBuilds"
        zip_dir = tmp / "zips"; zip_dir.mkdir()

        r = _run(["--built", str(built), "--godot-version", "4.5",
                  "--platform", "linux", "--app-builds", str(app_builds),
                  "--server-zip-dir", str(zip_dir)], tres)
        assert r.returncode == 0, r.stderr

        bundle = app_builds / "Linux" / "renderer" / "Renderer-godot_v4.5.x86_64"
        assert bundle.exists() and bundle.read_bytes() == built.read_bytes()

        server_zip = zip_dir / "linux-4.5.zip"
        assert server_zip.exists()
        assert zipfile.ZipFile(server_zip).namelist() == ["Renderer-godot_v4.5.x86_64"]


def test_non_current_version_server_zip_only():
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        tres = tmp / "r.tres"; tres.write_text(FAKE_TRES)
        built = tmp / "built43.x86_64"; _fake_renderer(built)
        app_builds = tmp / "AppBuilds"
        zip_dir = tmp / "zips"; zip_dir.mkdir()

        r = _run(["--built", str(built), "--godot-version", "4.3",
                  "--platform", "linux", "--app-builds", str(app_builds),
                  "--server-zip-dir", str(zip_dir)], tres)
        assert r.returncode == 0, r.stderr
        assert (zip_dir / "linux-4.3.zip").exists()
        assert not (app_builds / "Linux").exists()  # 4.3 is download-only, never bundled


def test_rejects_non_renderer_input():
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        tres = tmp / "r.tres"; tres.write_text(FAKE_TRES)
        bogus = tmp / "notrenderer.bin"; bogus.write_bytes(b"x" * 4096)  # no RENDERER-START
        r = _run(["--built", str(bogus), "--godot-version", "4.5",
                  "--platform", "linux", "--app-builds", str(tmp / "AppBuilds"),
                  "--server-zip-dir", str(tmp)], tres)
        assert r.returncode != 0
        assert "RENDERER-START" in (r.stderr + r.stdout)


def _run_all():
    failures = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn(); print(f"PASS {name}")
            except AssertionError as e:
                print(f"FAIL {name}: {e}"); failures += 1
    return failures


if __name__ == "__main__":
    sys.exit(1 if _run_all() else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 deployment/tests/test_stage_renderer.py`
Expected: FAIL — non-zero exit / `can't open file '…/stage_renderer.py'`.

- [ ] **Step 3: Write the script**

```python
# deployment/stage_renderer.py
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
    if built.stat().st_size < 1_000_000:
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 deployment/tests/test_stage_renderer.py`
Expected: PASS — `PASS test_current_version_copies_bundle_and_makes_server_zip`, `PASS test_non_current_version_server_zip_only`, `PASS test_rejects_non_renderer_input`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add deployment/stage_renderer.py deployment/tests/test_stage_renderer.py
git commit -m "deploy: stage_renderer.py — bundle + server zip from one binary"
```

---

## Task 3: Guard helper + wire into `compress_builds_linux.py`

**Files:**
- Modify: `deployment/renderer_config.py` (add `guard_host_bundle`)
- Modify: `deployment/compress_builds_linux.py:86-105` (add args + call the guard, skip non-host)
- Test: `deployment/tests/test_compress_guard.py`

- [ ] **Step 1: Write the failing test**

```python
# deployment/tests/test_compress_guard.py
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import renderer_config as rc


def _write(p: Path, data: bytes):
    p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(data)


def test_host_bundle_matches_passes(tmp_path):
    bundle = tmp_path / "Linux" / "renderer" / "Renderer-godot_v4.5.x86_64"
    build = tmp_path / "godot" / "bin" / "built.x86_64"
    _write(bundle, b"SAMEBYTES" * 1000); _write(build, b"SAMEBYTES" * 1000)
    rc.guard_host_bundle(bundle, build)  # must not raise


def test_host_bundle_mismatch_raises(tmp_path):
    bundle = tmp_path / "Linux" / "renderer" / "Renderer-godot_v4.5.x86_64"
    build = tmp_path / "godot" / "bin" / "built.x86_64"
    _write(bundle, b"OLDBYTES" * 1000); _write(build, b"NEWBYTES" * 1000)
    try:
        rc.guard_host_bundle(bundle, build); assert False, "should have raised"
    except SystemExit as e:
        assert "stale" in str(e).lower()


def test_host_bundle_missing_build_raises(tmp_path):
    bundle = tmp_path / "Linux" / "renderer" / "Renderer-godot_v4.5.x86_64"
    _write(bundle, b"X" * 1000)
    try:
        rc.guard_host_bundle(bundle, tmp_path / "godot" / "bin" / "absent.x86_64")
        assert False, "should have raised"
    except SystemExit as e:
        assert "build output" in str(e).lower()


def _run_all():
    import tempfile
    failures = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            with tempfile.TemporaryDirectory() as d:
                try:
                    fn(Path(d)); print(f"PASS {name}")
                except AssertionError as e:
                    print(f"FAIL {name}: {e}"); failures += 1
    return failures


if __name__ == "__main__":
    sys.exit(1 if _run_all() else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 deployment/tests/test_compress_guard.py`
Expected: FAIL — `AttributeError: module 'renderer_config' has no attribute 'guard_host_bundle'`.

- [ ] **Step 3: Add `guard_host_bundle` to `renderer_config.py`**

Append to `deployment/renderer_config.py`:

```python
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
```

- [ ] **Step 4: Run the guard test to verify it passes**

Run: `python3 deployment/tests/test_compress_guard.py`
Expected: PASS — 3 `PASS` lines, exit 0.

- [ ] **Step 5: Wire the guard into `compress_builds_linux.py`**

Replace `parse_args` and `main` (lines 86-105) with:

```python
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Zip Linux and Windows builds.")
    parser.add_argument("version", help="App version, e.g. 0.17.2")
    parser.add_argument("--force", action="store_true", help="Overwrite existing zip files if they exist.")
    parser.add_argument("--renderer-release", action="store_true",
                        help="Renderer-side release: verify the Linux bundle renderer is freshly staged; skip the cross-built Windows zip (stale).")
    parser.add_argument("--host-renderer-build", type=Path, default=None,
                        help="Path to the freshly-built Linux renderer (required with --renderer-release).")
    return parser.parse_args()


def main() -> None:
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import renderer_config as rc

    args = parse_args()
    validate_version(args.version)

    if args.renderer_release:
        if args.host_renderer_build is None:
            raise SystemExit("--host-renderer-build is required with --renderer-release")
        cur = rc.current_godot_version()
        bundle = Path("Linux") / rc.bundle_renderer_relpath("linux", cur)
        rc.guard_host_bundle(bundle, args.host_renderer_build)

    linux_zip = build_linux_zip(args.version, args.force)
    print(f"Created: {linux_zip}")

    if args.renderer_release:
        print("[STALE-RENDERER] Windows: cross-built on a Linux host cannot carry a freshly-built "
              "Windows renderer — skipping Windows zip. Build + publish Windows on its own machine.")
    else:
        windows_zip = build_windows_zip(args.version, args.force)
        print(f"Created: {windows_zip}")
```

- [ ] **Step 6: Verify end-to-end with the real artifacts (manual)**

Run (current 1.0.4 bundle is already staged, build output present from the release):
```bash
cd /media/common/Projects/thegates-folder/AppBuilds
python3 /home/nordup/projects/thegates-folder/thegates/deployment/compress_builds_linux.py 1.0.4 --force \
  --renderer-release \
  --host-renderer-build /home/nordup/projects/thegates-folder/thegates/godot/bin/godot.linuxbsd.template_release.renderer.x86_64
```
Expected: `Created: Linux/TheGates_Linux_1.0.4.zip` AND a `[STALE-RENDERER] Windows … skipping` line, NO Windows zip created, exit 0.

- [ ] **Step 7: Commit**

```bash
git add deployment/renderer_config.py deployment/compress_builds_linux.py deployment/tests/test_compress_guard.py
git commit -m "deploy: --renderer-release guard in linux compress (verify host, skip+flag Windows)"
```

---

## Task 4: `build_release.py` — forward `--renderer-release`

**Files:**
- Modify: `deployment/build_release.py:103-135` (add arg, pass to the Linux compress call)

- [ ] **Step 1: Add the argument**

In `main()` of `deployment/build_release.py`, immediately after `os_name = platform.system()` (line 110), add:

```python
    ap = argparse.ArgumentParser(description="Export + compress + upload a release.")
    ap.add_argument("--renderer-release", action="store_true",
                    help="Renderer-side release: verify/stage the bundle renderer and skip cross-built non-host zips.")
    cli = ap.parse_args()
```

(`argparse` is already imported at line 12.)

- [ ] **Step 2: Pass it to the Linux compress call**

In the `if os_name == "Linux":` branch, replace the compress `run(...)` (line 135) with:

```python
        compress_cmd = [sys.executable, str(compress_script), version, "--force"]
        if cli.renderer_release:
            host_renderer = repo_root / "godot" / "bin" / "godot.linuxbsd.template_release.renderer.x86_64"
            compress_cmd += ["--renderer-release", "--host-renderer-build", str(host_renderer)]
        run(compress_cmd, cwd=builds_dir)
```

- [ ] **Step 3: Verify it parses + forwards (dry check)**

Run: `python3 deployment/build_release.py --help`
Expected: usage text shows `--renderer-release`. (Do NOT run it for real — it exports + uploads.)

- [ ] **Step 4: Commit**

```bash
git add deployment/build_release.py
git commit -m "deploy: build_release forwards --renderer-release + host renderer path"
```

---

## Task 5: `compress_build_windows.py` — host-Windows guard

**Files:**
- Modify: `deployment/compress_build_windows.py:74-90` (add args + guard, host = Windows)

- [ ] **Step 1: Replace `parse_args` and `main` (lines 74-90)**

```python
def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Zip Windows build.")
	parser.add_argument("version", help="App version, e.g. 0.17.2")
	parser.add_argument("--force", action="store_true", help="Overwrite existing zip file if it exists.")
	parser.add_argument("--renderer-release", action="store_true",
						help="Renderer-side release: verify the Windows bundle renderer is freshly staged.")
	parser.add_argument("--host-renderer-build", type=Path, default=None,
						help="Path to the freshly-built Windows renderer (required with --renderer-release).")
	return parser.parse_args()


def main() -> None:
	import sys
	sys.path.insert(0, str(Path(__file__).resolve().parent))
	import renderer_config as rc

	args = parse_args()
	validate_version(args.version)

	if args.renderer_release:
		if args.host_renderer_build is None:
			raise SystemExit("--host-renderer-build is required with --renderer-release")
		cur = rc.current_godot_version()
		bundle = Path("Windows") / rc.bundle_renderer_relpath("windows", cur)
		rc.guard_host_bundle(bundle, args.host_renderer_build)

	windows_zip = build_windows_zip(args.version, args.force)
	print(f"Created: {windows_zip}")
```

(Note: this file uses tabs — match it.)

- [ ] **Step 2: Verify it parses**

Run: `python3 deployment/compress_build_windows.py --help`
Expected: usage shows `--renderer-release` and `--host-renderer-build`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add deployment/compress_build_windows.py
git commit -m "deploy: --renderer-release guard in windows compress (host verify)"
```

---

## Task 6: Update `publish.md`

**Files:**
- Modify: `.claude/commands/publish.md` (Step 4 and Step 5)

- [ ] **Step 1: Rewrite Step 4's per-renderer packaging**

In `.claude/commands/publish.md`, in `## Step 4`, replace the manual rename/zip instructions for the 4.5 and 4.3 builds so each calls the staging script. Use this text for the step body:

```markdown
For each renderer you build, stage it with the single entrypoint (it puts the
renderer into the app bundle AND makes its server zip from the same binary):

- **4.5:** `./run_build_image.sh renderer-release` → then
  `python deployment/stage_renderer.py --built godot/bin/godot.linuxbsd.template_release.renderer.x86_64 --godot-version 4.5 --app-builds /media/common/Projects/thegates-folder/AppBuilds --server-zip-dir godot/bin`
  (produces `godot/bin/linux-4.5.zip` AND refreshes `AppBuilds/Linux/renderer/`).
- **4.3:** `git -C godot checkout tg-4.3` → `BUILD_NAME=4.3 ./run_build_image.sh renderer-release` → then
  `python deployment/stage_renderer.py --built godot/bin/godot.linuxbsd.template_release.renderer.4.3.x86_64 --godot-version 4.3 --app-builds /media/common/Projects/thegates-folder/AppBuilds --server-zip-dir godot/bin`
  (4.3 is download-only → server zip only). Then `git -C godot checkout tg-4.5`.
- **[CRITICAL CHECK]** `unzip -l godot/bin/linux-4.{3,5}.zip` shows the expected `Renderer-godot_v4.{3,5}.x86_64`. Then `scp godot/bin/linux-4.{3,5}.zip thegates:…/renderers/`.
```

- [ ] **Step 2: Update Step 5 to pass the flag**

In `## Step 5`, change the build_release invocation line to:

```markdown
- `python deployment/build_release.py --renderer-release`  (export → compress → upload). The compress step now **verifies** the Linux bundle renderer matches the freshly-built one and **skips the cross-built Windows zip** (stale on a Linux host) — Windows is released from its own machine. Omit `--renderer-release` for launcher-only releases.
```

- [ ] **Step 3: Add a one-line note under Step 4's FLAG about the staging guarantee**

Append to the existing `**FLAG (cannot do from this box):**` paragraph:

```markdown
  The Linux bundle renderer is now refreshed by `stage_renderer.py`; the compress guard will refuse to ship a stale Linux bundle and will skip the cross-built Windows zip. Build the Windows/macOS renderers + launchers on their own machines (their `/publish` runs stage their own bundles).
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/publish.md
git commit -m "publish: stage renderer into bundle in Step 4; pass --renderer-release in Step 5"
```

---

## Task 7: Full self-running test pass + README note

**Files:**
- Create: `deployment/tests/README.md`

- [ ] **Step 1: Run all three test files**

Run:
```bash
python3 deployment/tests/test_renderer_config.py && \
python3 deployment/tests/test_stage_renderer.py && \
python3 deployment/tests/test_compress_guard.py && echo ALL_GREEN
```
Expected: every `PASS …` line, then `ALL_GREEN`, exit 0.

- [ ] **Step 2: Write the tests README**

```markdown
# deployment/tests

Dependency-free tests for the publish renderer-staging path. Run each directly:

    python3 deployment/tests/test_renderer_config.py
    python3 deployment/tests/test_stage_renderer.py
    python3 deployment/tests/test_compress_guard.py

Each prints `PASS …` / `FAIL …` and exits non-zero on any failure. No pytest required.

What they cover:
- `test_renderer_config` — parsing renderer_executable.tres, bundle relpath, md5.
- `test_stage_renderer` — current version copies bundle + makes server zip; non-current is server-zip-only; non-renderer input is rejected.
- `test_compress_guard` — host bundle md5-match passes; mismatch / missing build output fail.
```

- [ ] **Step 3: Commit**

```bash
git add deployment/tests/README.md
git commit -m "deploy: tests README for the renderer-staging path"
```

---

## Self-Review (completed)

- **Spec coverage:** stage_renderer.py (§Design 1) → Task 2; compress guard with `--renderer-release`, host-verify + non-host skip+flag (§Design 2) → Tasks 3, 5; wiring into build_release.py + publish.md (§Design 3) → Tasks 4, 6; RENDERER_RELEASE gating → guard only runs under `--renderer-release` (Tasks 3-4); content-equality, no marker (§Goal) → `guard_host_bundle` md5 compare, no marker written; testing (§Testing) → Tasks 1-3, 7; macOS deferred (§Scope) → noted, excluded.
- **Placeholders:** none — every step has complete code/commands.
- **Type/name consistency:** `renderer_config` functions (`current_godot_version`, `bundle_renderer_relpath`, `os_dir`, `file_md5`, `guard_host_bundle`) are defined in Tasks 1/3 and called with the same signatures in stage_renderer.py and both compress scripts. Server-zip name `<platform>-<version>.zip` and bundle path `<OS>/<relpath>` are consistent across stage + guard.
