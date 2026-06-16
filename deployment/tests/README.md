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
