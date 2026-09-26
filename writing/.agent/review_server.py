"""Local server for the manuscript review page.

Serves writing/ (the review page) and stores review comments per version in comments/v<N>.json,
so the page saves automatically without any file picker.
Run: python review_server.py   (or double-click open_review.cmd)
"""
import datetime
import hashlib
import json
import os
import re
import tempfile
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # writing/, which holds the review page
COMMENTS = os.path.join(HERE, "comments")
VERSIONS = os.path.join(HERE, "manuscript2_journal_versions.js")
DRAFT = os.path.join(HERE, "manuscript2_journal_draft.json")
WRITE_LOCK = threading.RLock()
HEAD = "window.MANUSCRIPT_VERSIONS = "
PORT = 8765
ROUTE = re.compile(r"^/api/comments/(\d+)$")


def read_versions():
    with open(VERSIONS, encoding="utf-8") as f:
        first, rest = f.read().split("\n", 1)
    return json.loads(first[len(HEAD):].rstrip().rstrip(";")), rest


def atomic_write(path, text):
    fd, temporary = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_draft(versions):
    latest = versions[-1]
    if os.path.exists(DRAFT):
        with open(DRAFT, encoding="utf-8") as f:
            draft = json.load(f)
        # Follow externally generated versions only when there are no working edits.
        base = next((v for v in versions if v["v"] == draft["base"]), None)
        if base and draft["html"] == base["html"]:
            draft = {"base": latest["v"], "html": latest["html"]}
    else:
        draft = {"base": latest["v"], "html": latest["html"]}
    draft["revision"] = hashlib.sha256(
        json.dumps([latest["v"], draft["base"], draft["html"]]).encode("utf-8")
    ).hexdigest()
    return draft


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/ping":
            return self.send_json({"ok": True})
        if self.path == "/api/draft":
            with WRITE_LOCK:
                versions, _ = read_versions()
                return self.send_json(read_draft(versions))
        m = ROUTE.match(self.path)
        if not m:
            return super().do_GET()
        path = os.path.join(COMMENTS, f"v{m[1]}.json")
        data = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {"comments": []}
        self.send_json(data)

    def do_PUT(self):
        try:
            data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        except (ValueError, TypeError):
            return self.send_json({"error": "Invalid request"}, 400)
        if self.path in ("/api/draft", "/api/versions", "/api/restore"):
            try:
                with WRITE_LOCK:
                    return self.save_manuscript(data)
            except OSError:
                return self.send_json({"error": "Could not save to disk. Your paragraph is still open; try again."}, 500)
        m = ROUTE.match(self.path)
        if not m:
            return self.send_json({"error": "not found"}, 404)
        os.makedirs(COMMENTS, exist_ok=True)
        with open(os.path.join(COMMENTS, f"v{m[1]}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        self.send_json({"ok": True})

    def do_DELETE(self):
        m = re.match(r"^/api/versions/(\d+)$", self.path)
        if not m:
            return self.send_json({"error": "not found"}, 404)
        with WRITE_LOCK:
            versions, rest = read_versions()
            if len(versions) < 2:
                return self.send_json({"error": "The only version cannot be deleted"}, 400)
            kept = [v for v in versions if v["v"] != int(m[1])]
            if len(kept) == len(versions):
                return self.send_json({"error": "Version not found"}, 404)
            atomic_write(VERSIONS, HEAD + json.dumps(kept, ensure_ascii=False) + ";\n" + rest)
            comments = os.path.join(COMMENTS, f"v{m[1]}.json")
            if os.path.exists(comments):
                os.remove(comments)
            # The working copy lives in its own file, so deleting a version never loses it.
            self.send_json({"draft": read_draft(kept), "versions": kept})

    def save_manuscript(self, data):
        versions, rest = read_versions()
        draft = read_draft(versions)
        if data.get("revision") != draft["revision"]:
            return self.send_json({"error": "The manuscript changed in another window. Copy your open paragraph before reloading."}, 409)

        def append_version(html, note):
            versions.append({"v": versions[-1]["v"] + 1,
                             "date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
                             "note": note, "author": "user", "html": html})
            atomic_write(VERSIONS, HEAD + json.dumps(versions, ensure_ascii=False) + ";\n" + rest)

        if self.path == "/api/restore":
            source = next((v for v in versions if v["v"] == data.get("v")), None)
            if source is None:
                return self.send_json({"error": "Version not found"}, 404)
            if draft["html"] != versions[-1]["html"]:
                append_version(draft["html"], f"Recovery copy before reverting to v{source['v']}")
            html = source["html"]
        else:
            html = data.get("html")
            if not isinstance(html, str) or not html.strip():
                return self.send_json({"error": "The manuscript cannot be empty"}, 400)
            if self.path == "/api/versions":
                append_version(html, "Saved from the review page")
        atomic_write(DRAFT, json.dumps({"base": versions[-1]["v"], "html": html}, ensure_ascii=False))
        self.send_json({"draft": read_draft(versions), "versions": versions})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    url = f"http://127.0.0.1:{PORT}/manuscript2_journal.html"
    print(f"Review page: {url}  (Ctrl+C to stop)")
    if not os.environ.get("REVIEW_NO_BROWSER"):
        webbrowser.open(url)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
