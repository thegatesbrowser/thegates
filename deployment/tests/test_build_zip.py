import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build_zip


def test_validate_version_accepts_release(tmp_path):
    build_zip.validate_version("1.0.4")  # must not raise


def test_validate_version_rejects_garbage(tmp_path):
    try:
        build_zip.validate_version("not-a-version")
        assert False, "should have raised"
    except ValueError:
        pass


def test_build_zip_packs_files_and_dirs(tmp_path):
    linux = tmp_path / "Linux"
    (linux / "renderer").mkdir(parents=True)
    (linux / "TheGates.x86_64").write_bytes(b"launcher")
    (linux / "renderer" / "Renderer-godot_v4.5.x86_64").write_bytes(b"renderer")

    out = build_zip.build_zip(tmp_path, "Linux", ["TheGates.x86_64", "renderer"], "1.0.4", overwrite=True)

    assert out == tmp_path / "Linux" / "TheGates_Linux_1.0.4.zip"
    assert set(zipfile.ZipFile(out).namelist()) == {
        "TheGates.x86_64",
        "renderer/Renderer-godot_v4.5.x86_64",
    }


def test_build_zip_refuses_overwrite_without_force(tmp_path):
    win = tmp_path / "Windows"
    win.mkdir()
    (win / "TheGates.exe").write_bytes(b"exe")
    build_zip.build_zip(tmp_path, "Windows", ["TheGates.exe"], "1.0.0", overwrite=True)
    try:
        build_zip.build_zip(tmp_path, "Windows", ["TheGates.exe"], "1.0.0", overwrite=False)
        assert False, "should have raised FileExistsError"
    except FileExistsError:
        pass


def test_build_zip_missing_entry_raises(tmp_path):
    (tmp_path / "Linux").mkdir()
    try:
        build_zip.build_zip(tmp_path, "Linux", ["TheGates.x86_64"], "1.0.0", overwrite=True)
        assert False, "should have raised FileNotFoundError"
    except FileNotFoundError:
        pass


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
