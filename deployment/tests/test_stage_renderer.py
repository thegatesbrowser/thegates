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
