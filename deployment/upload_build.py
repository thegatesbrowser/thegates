#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
import mimetypes
import uuid
from pathlib import Path
from typing import Iterable
from urllib import request, error


DEFAULT_ENDPOINT = "https://app.thegates.io/api/upload_build"


def read_api_key(repo_root: Path) -> str:
	# Allow override via env. Default to deployment/upload_api.key
	key_file_env = os.environ.get("TG_UPLOAD_API_KEY_FILE")
	if key_file_env:
		key_path = Path(key_file_env).expanduser().resolve()
	else:
		key_path = (repo_root / "deployment" / "upload_api.key").resolve()

	if not key_path.exists():
		raise FileNotFoundError(
			f"API key file not found: {key_path}. Set TG_UPLOAD_API_KEY_FILE or create the file."
		)

	key = key_path.read_text(encoding="utf-8").strip()
	if not key:
		raise ValueError(f"API key file {key_path} is empty")
	return key


def build_multipart_body(field_name: str, file_path: Path, boundary: str) -> tuple[bytes, str]:
	filename = file_path.name
	content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
	file_bytes = file_path.read_bytes()

	boundary_bytes = boundary.encode("utf-8")
	crlf = b"\r\n"

	body = []
	body.append(b"--" + boundary_bytes + crlf)
	body.append(
		(
			f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"'
		).encode("utf-8")
		+ crlf
	)
	body.append((f"Content-Type: {content_type}").encode("utf-8") + crlf + crlf)
	body.append(file_bytes + crlf)
	body.append(b"--" + boundary_bytes + b"--" + crlf)

	body_bytes = b"".join(body)
	content_type_header = f"multipart/form-data; boundary={boundary}"
	return body_bytes, content_type_header


def upload_file(endpoint: str, api_key: str, file_path: Path) -> int:
	if not file_path.exists():
		raise FileNotFoundError(f"File not found: {file_path}")

	boundary = f"----TheGatesBoundary{uuid.uuid4().hex}"
	body, content_type = build_multipart_body("file", file_path, boundary)

	req = request.Request(endpoint, method="POST")
	req.add_header("Content-Type", content_type)
	req.add_header("Content-Length", str(len(body)))
	req.add_header("X-API-Key", api_key)

	try:
		with request.urlopen(req, data=body, timeout=300) as resp:
			status = resp.getcode()
			print(f"Uploaded {file_path.name}: HTTP {status}")
			return status
	except error.HTTPError as e:
		print(f"Upload failed for {file_path.name}: HTTP {e.code} - {e.read().decode(errors='ignore')}")
		return e.code
	except Exception as e:
		print(f"Upload error for {file_path.name}: {e}")
		return 1


def main(argv: list[str]) -> int:
	if len(argv) < 2:
		print("Usage: upload_build.py <file1> [<file2> ...]")
		return 2

	repo_root = Path(__file__).resolve().parent.parent
	endpoint = os.environ.get("TG_UPLOAD_ENDPOINT", DEFAULT_ENDPOINT)
	api_key = read_api_key(repo_root)

	statuses: list[int] = []
	for arg in argv[1:]:
		file_path = Path(arg).expanduser().resolve()
		statuses.append(upload_file(endpoint, api_key, file_path))

	# Return non-zero if any upload failed (status >= 400 or ==1)
	for s in statuses:
		if isinstance(s, int) and (s >= 400 or s == 1):
			return 1
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv))
