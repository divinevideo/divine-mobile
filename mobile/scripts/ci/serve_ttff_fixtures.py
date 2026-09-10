#!/usr/bin/env python3
"""Serve immutable video fixtures with HTTP range support at a fixed rate."""

from __future__ import annotations

import argparse
import os
import re
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

_RANGE = re.compile(r"bytes=(\d*)-(\d*)$")


class ThrottledFixtureHandler(SimpleHTTPRequestHandler):
    """HTTP file handler with byte ranges and per-connection throttling."""

    rate_bytes_per_second = 625_000
    chunk_size = 64 * 1024

    def do_GET(self) -> None:  # noqa: N802
        self._request_started = time.monotonic()
        self._bytes_sent = 0
        cancelled = False
        try:
            super().do_GET()
        except (BrokenPipeError, ConnectionResetError):
            cancelled = True
        finally:
            elapsed_ms = round((time.monotonic() - self._request_started) * 1000)
            print(
                f"TTFF_HTTP path={self.path} "
                f"range={self.headers.get('Range', 'none')} "
                f"bytes={self._bytes_sent} durationMs={elapsed_ms} "
                f"cancelled={str(cancelled).lower()}",
                flush=True,
            )

    def send_head(self):  # type: ignore[no-untyped-def]
        path = Path(self.translate_path(self.path))
        if not path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND)
            return None

        file = path.open("rb")
        size = path.stat().st_size
        start, end = 0, size - 1
        range_header = self.headers.get("Range")
        if range_header:
            match = _RANGE.fullmatch(range_header.strip())
            if match is None:
                file.close()
                self.send_error(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                return None
            first, last = match.groups()
            if first:
                start = int(first)
                end = min(int(last), end) if last else end
            elif last:
                start = max(size - int(last), 0)
            if start > end or start >= size:
                file.close()
                self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                self.send_header("Content-Range", f"bytes */{size}")
                self.end_headers()
                return None
            self.send_response(HTTPStatus.PARTIAL_CONTENT)
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        else:
            self.send_response(HTTPStatus.OK)

        self.send_header("Content-Type", "video/mp4")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        file.seek(start)
        self._remaining = end - start + 1
        return file

    def copyfile(self, source, outputfile):  # type: ignore[no-untyped-def]
        remaining = self._remaining
        started = time.monotonic()
        sent = 0
        while remaining:
            chunk = source.read(min(self.chunk_size, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            outputfile.flush()
            sent += len(chunk)
            self._bytes_sent = sent
            remaining -= len(chunk)
            target_elapsed = sent / self.rate_bytes_per_second
            delay = target_elapsed - (time.monotonic() - started)
            if delay > 0:
                time.sleep(delay)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--rate", type=int, default=625_000)
    args = parser.parse_args()

    if not args.directory.is_dir():
        parser.error(f"fixture directory does not exist: {args.directory}")
    if args.rate <= 0:
        parser.error("--rate must be positive")

    os.chdir(args.directory)
    ThrottledFixtureHandler.rate_bytes_per_second = args.rate
    server = ThreadingHTTPServer(("127.0.0.1", args.port), ThrottledFixtureHandler)
    print(f"Serving {args.directory} on port {args.port} at {args.rate} B/s", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
