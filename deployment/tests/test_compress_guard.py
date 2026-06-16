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
