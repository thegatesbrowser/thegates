#!/usr/bin/env python3
"""Serve a Godot 3.6 gate and its renderer from localhost, for end-to-end testing.

There is no `linux-3.6` renderer on app.thegates.io yet, so the launcher cannot
reach one the normal way. This stands in for the whole backend: point
app/resources/api_settings.tres at host_type = 0 (Local) and open
http://127.0.0.1:8000/test.gate.

    python3 tests/godot3/testgate/serve.py --renderer godot/bin/godot.x11.opt.debug.renderer.64
"""

from __future__ import annotations

import argparse
import base64
import json
import shutil
import sys
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent.parent
GODOT_VERSION = "3.6"
RENDERER_NAME = "Renderer-godot_v%s.x86_64" % GODOT_VERSION

# 1x1 opaque PNG; the launcher fetches the gate's icon and image unconditionally.
PIXEL_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

GATE_TEMPLATE = """[gate]
title = "Godot 3 Test Gate"
description = "End-to-end check for the Godot 3.6 renderer"
icon = "icon.png"
image = "image.png"
resource_pack = "world.zip"
godot_version = "%s"
discoverable = false
""" % GODOT_VERSION


def build_world(out_dir: Path) -> Path:
    project = HERE / "project"
    world = out_dir / "world.zip"
    with ZipFile(world, "w", ZIP_DEFLATED) as zf:
        for path in sorted(project.rglob("*")):
            if path.is_file():
                zf.write(path, arcname=str(path.relative_to(project)))
    print("[serve] world pack: %s" % world)
    return world


def build_renderer_zip(renderer: Path, out_dir: Path) -> Path:
    api_dir = out_dir / "api" / "download_renderer"
    api_dir.mkdir(parents=True, exist_ok=True)
    # RendererExecutable requests <platform>-<version> with no extension, and
    # UnZip.extract_renderer_files wants the binary at the archive root under
    # the name renderer_executable.tres derives.
    target = api_dir / ("linux-%s" % GODOT_VERSION)
    with ZipFile(target, "w", ZIP_DEFLATED) as zf:
        zf.write(renderer, arcname=RENDERER_NAME)
    print("[serve] renderer zip: %s (%s)" % (target, RENDERER_NAME))
    return target


class Handler(SimpleHTTPRequestHandler):
    def _send_json(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/featured_gates":
            return self._send_json([])
        if path == "/api/create_user_id":
            return self._send_json({"user_id": "local-test-user"})
        if path in ("/api/search", "/api/prompt", "/api/discover_gate"):
            return self._send_json([])
        return SimpleHTTPRequestHandler.do_GET(self)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        return self._send_json({"ok": True})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--renderer", type=Path, required=True, help="built Godot 3 renderer binary")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--out", type=Path, default=HERE / "www")
    args = parser.parse_args()

    renderer = args.renderer if args.renderer.is_absolute() else REPO_ROOT / args.renderer
    if not renderer.is_file():
        print("renderer not found: %s" % renderer, file=sys.stderr)
        return 1

    if args.out.exists():
        shutil.rmtree(args.out)
    args.out.mkdir(parents=True)

    build_world(args.out)
    build_renderer_zip(renderer, args.out)
    (args.out / "test.gate").write_text(GATE_TEMPLATE)
    (args.out / "icon.png").write_bytes(PIXEL_PNG)
    (args.out / "image.png").write_bytes(PIXEL_PNG)

    handler = partial(Handler, directory=str(args.out))
    server = HTTPServer(("127.0.0.1", args.port), handler)
    print("[serve] http://127.0.0.1:%d/test.gate" % args.port)
    print("[serve] set api_settings.tres host_type = 0 (Local) before running the launcher")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
