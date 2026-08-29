"""Serve the report and persist its single metadata JSON document."""

from __future__ import annotations

import argparse
import json
import os
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


REPORT_FOLDER = Path(__file__).resolve().parent
METADATA_FILE = REPORT_FOLDER / "data" / "report-metadata.json"
METADATA_ENDPOINT = "/api/report-metadata"
MAX_METADATA_BYTES = 2 * 1024 * 1024


class ReportHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(REPORT_FOLDER), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path.split("?", 1)[0] == METADATA_ENDPOINT:
            self._send_metadata()
            return
        super().do_GET()

    def do_PUT(self):
        if self.path.split("?", 1)[0] != METADATA_ENDPOINT:
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > MAX_METADATA_BYTES:
                raise ValueError("Invalid metadata payload size.")
            metadata = json.loads(self.rfile.read(content_length))
            self._validate_metadata(metadata)
            metadata["updated_at"] = self.date_time_string()
            temporary_file = METADATA_FILE.with_suffix(".json.tmp")
            temporary_file.write_text(
                json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
            os.replace(temporary_file, METADATA_FILE)
        except (ValueError, json.JSONDecodeError) as error:
            self.send_error(HTTPStatus.BAD_REQUEST, str(error))
            return

        body = b'{"saved":true}'
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_metadata(self):
        body = METADATA_FILE.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    @staticmethod
    def _validate_metadata(metadata):
        if not isinstance(metadata, dict):
            raise ValueError("Metadata must be a JSON object.")
        for key in ("version", "report", "settings", "files"):
            if key not in metadata:
                raise ValueError(f"Metadata is missing '{key}'.")
        if metadata["version"] != 1:
            raise ValueError("Unsupported metadata version.")
        if not isinstance(metadata["report"], dict):
            raise ValueError("Metadata report must be an object.")
        if not isinstance(metadata["settings"], dict):
            raise ValueError("Metadata settings must be an object.")
        if not isinstance(metadata["files"], dict):
            raise ValueError("Metadata files must be an object.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8010, type=int)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), ReportHandler)
    print(f"RTHS report: http://{args.host}:{args.port}/")
    print(f"Metadata: {METADATA_FILE}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
