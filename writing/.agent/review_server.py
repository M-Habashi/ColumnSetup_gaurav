"""Local server for the manuscript review page.

Serves writing/ (the review page) and stores review comments per version in comments/v<N>.json,
so the page saves automatically without any file picker.
Run: python review_server.py   (or double-click open_review.cmd)
"""
import datetime
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import tokenize
import uuid
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


# ---- comment suggestions: an agent revises a copy of the builder, the page shows the diff,
# and Apply copies it back and builds a normal version. Comments and the old workflow are unchanged.
BUILDER = os.path.join(HERE, "build_manuscript2_journal.py")
SUGGEST = os.path.join(HERE, "suggest")
GUIDES = os.path.join(ROOT, "md")
JOBS = {}
PROMPT = """You revise one passage of a journal manuscript to address the author's review comment.
The manuscript text lives in the string literals of build.py in the current folder.
First read {guide}, and follow it, especially "Precision of claims and words" and "Change little".
Read {paper2} only if the comment needs Paper 2 context.

Section: {section}
The comment is anchored to this rendered text: "{quote}"
Text just before it: "{prefix}"
Text just after it: "{suffix}"
In the rendered text, {{citet:key}} appears as "Name [n]", {{citep:key}} as "[n]" and $...$ as math.

Author's comment:
{text}

Locate the passage in build.py and edit it with the Edit tool. Change only the text inside string
literals, never code. In P("...") strings write LaTeX backslashes as \\\\. Do not ask questions: the author
reviews the diff and can regenerate. Finish with one short sentence that says what you changed."""


def code_tokens(source):
    """Everything except string contents and layout, so edits outside text are rejected."""
    skip = {tokenize.STRING, tokenize.NL, tokenize.NEWLINE, tokenize.COMMENT, tokenize.INDENT, tokenize.DEDENT}
    return [(t.type, t.string) for t in tokenize.generate_tokens(io.StringIO(source).readline) if t.type not in skip]


def run_suggestion(job, data):
    d = os.path.join(SUGGEST, job["id"])
    try:
        os.makedirs(d, exist_ok=True)
        shutil.copy(BUILDER, os.path.join(d, "build.py"))
        prompt = PROMPT.format(guide=os.path.join(GUIDES, "writing_guide.md"), paper2=os.path.join(GUIDES, "paper2.md"),
                               **{k: data.get(k, "") for k in ("section", "quote", "prefix", "suffix", "text")})
        r = subprocess.run(["claude", "-p", "--model", "opus", "--effort", "medium", "--permission-mode", "acceptEdits",
                            "--add-dir", GUIDES, "--tools", "Read,Edit,Grep"],
                           input=prompt, cwd=d, capture_output=True, text=True, encoding="utf-8", timeout=900)
        new = open(os.path.join(d, "build.py"), encoding="utf-8").read()
        if new == job["source"]:
            raise RuntimeError(r.stdout.strip() or r.stderr.strip() or "The agent made no change.")
        if code_tokens(new) != code_tokens(job["source"]):
            raise RuntimeError("The agent changed code, not only text, so the suggestion was rejected.")
        out = os.path.join(d, "article.html")
        p = subprocess.run([sys.executable, "build.py", "--preview", out], cwd=d, capture_output=True, text=True)
        if p.returncode:
            raise RuntimeError(p.stderr.strip()[-500:])
        job.update(status="done", html=open(out, encoding="utf-8").read(), summary=r.stdout.strip()[-400:])
    except Exception as e:  # noqa: BLE001 - every failure goes back to the page as a message
        job.update(status="error", error=str(e)[-500:])


def apply_suggestion(job, data):
    with WRITE_LOCK:
        if open(BUILDER, encoding="utf-8").read() != job["source"]:
            return {"error": "The manuscript changed since this suggestion. Regenerate it."}, 409
        versions, _ = read_versions()
        draft = read_draft(versions)
        if versions[-1].get("author") == "user" or draft["html"] != versions[-1]["html"]:
            return {"error": "The page holds edits that are not merged yet. Ask the agent to port them first."}, 409
        shutil.copy(os.path.join(SUGGEST, job["id"], "build.py"), BUILDER)
        note = "Comment applied: " + " ".join(job["text"].split())[:90]
        p = subprocess.run([sys.executable, BUILDER, note], cwd=HERE, capture_output=True, text=True)
        if p.returncode:
            open(BUILDER, "w", encoding="utf-8").write(job["source"])
            return {"error": p.stderr.strip()[-500:] or p.stdout.strip()}, 500
        shutil.rmtree(os.path.join(SUGGEST, job["id"]), ignore_errors=True)
        versions, _ = read_versions()
        # The other comments of that version stay open on the new version; the applied one is resolved.
        old = os.path.join(COMMENTS, f"v{data.get('version')}.json")
        if os.path.exists(old):
            cs = json.load(open(old, encoding="utf-8"))
            cs.update(version=versions[-1]["v"], comments=[c for c in cs["comments"] if c["id"] != data.get("comment")])
            new = os.path.join(COMMENTS, f"v{versions[-1]['v']}.json")
            if cs["comments"] and not os.path.exists(new):
                atomic_write(new, json.dumps(cs, ensure_ascii=False, indent=2))
        return {"draft": read_draft(versions), "versions": versions}, 200


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
        s = re.match(r"^/api/suggest/(\w+)$", self.path)
        if s:
            job = JOBS.get(s[1])
            return self.send_json({k: v for k, v in job.items() if k != "source"} if job else {"error": "not found"},
                                  200 if job else 404)
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

    def do_POST(self):
        try:
            data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        except (ValueError, TypeError):
            return self.send_json({"error": "Invalid request"}, 400)
        if self.path == "/api/suggest":
            job = {"id": uuid.uuid4().hex[:12], "status": "running", "text": data.get("text", ""),
                   "source": open(BUILDER, encoding="utf-8").read()}
            JOBS[job["id"]] = job
            threading.Thread(target=run_suggestion, args=(job, data), daemon=True).start()
            return self.send_json({"id": job["id"]})
        s = re.match(r"^/api/suggest/(\w+)/apply$", self.path)
        if s and s[1] in JOBS and JOBS[s[1]]["status"] == "done":
            body, status = apply_suggestion(JOBS[s[1]], data)
            if status == 200:
                JOBS.pop(s[1])
            return self.send_json(body, status)
        self.send_json({"error": "not found"}, 404)

    def do_DELETE(self):
        s = re.match(r"^/api/suggest/(\w+)$", self.path)
        if s:
            JOBS.pop(s[1], None)
            shutil.rmtree(os.path.join(SUGGEST, s[1]), ignore_errors=True)
            return self.send_json({"ok": True})
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
