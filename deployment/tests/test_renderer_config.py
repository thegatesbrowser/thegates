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
