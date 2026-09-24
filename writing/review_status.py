"""Status of the manuscript review workflow (see REVIEW_WORKFLOW.md).

python review_status.py                 report versions, the user's saved/unsaved edits, and comments
python review_status.py --adopt-latest  point the working copy at the latest version
                                        (only after its unsaved edits are ported into the builder)
"""
import difflib
import html
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
VERSIONS = os.path.join(HERE, "manuscript2_journal_versions.js")
DRAFT = os.path.join(HERE, "manuscript2_journal_draft.json")
COMMENTS = os.path.join(HERE, "comments")
HEAD = "window.MANUSCRIPT_VERSIONS = "
SERVER = "http://127.0.0.1:8765/api/draft"


def load_versions():
    with open(VERSIONS, encoding="utf-8") as f:
        return json.loads(f.readline()[len(HEAD):].rstrip().rstrip(";"))


def paragraphs(h):
    h = re.sub(r"<math.*?</math>", "[eq]", h, flags=re.S)
    h = re.sub(r"<svg.*?</svg>", "[figure]", h, flags=re.S)
    h = re.sub(r"</(p|h1|h2|li|figcaption|tr|th|td)>", "\n", h)
    return [" ".join(l.split()) for l in html.unescape(re.sub(r"<[^>]+>", "", h)).split("\n") if l.strip()]


def show_changes(old_html, new_html):
    a, b = paragraphs(old_html), paragraphs(new_html)
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b).get_opcodes():
        if op == "equal":
            continue
        old, new = " ".join(a[i1:i2]), " ".join(b[j1:j2])
        print(f"  in paragraph: {(new or old)[:70]!r}…")
        for wop, w1, w2, v1, v2 in difflib.SequenceMatcher(None, old.split(), new.split()).get_opcodes():
            if wop != "equal":
                print(f"    {wop}: {' '.join(old.split()[w1:w2])!r} -> {' '.join(new.split()[v1:v2])!r}")


V = load_versions()
last = V[-1]
by_v = {v["v"]: v for v in V}

if "--adopt-latest" in sys.argv:
    try:
        rev = json.load(urllib.request.urlopen(SERVER))["revision"]
        req = urllib.request.Request(SERVER, method="PUT", headers={"Content-Type": "application/json"},
                                     data=json.dumps({"html": last["html"], "revision": rev}).encode())
        urllib.request.urlopen(req)
    except OSError:  # server not running: write the file directly
        with open(DRAFT, "w", encoding="utf-8") as f:
            json.dump({"base": last["v"], "html": last["html"]}, f, ensure_ascii=False)
    print(f"working copy now follows v{last['v']}")
    sys.exit()

print(f"latest version: v{last['v']} ({last['date']}), author: {last.get('author', 'agent')}, note: {last['note']}")

# Saved user edits: trailing versions authored by the user, not yet ported into the builder.
saved = []
for v in reversed(V):
    if v.get("author") != "user":
        break
    saved.insert(0, v)
if saved:
    base = V[len(V) - len(saved) - 1]
    print(f"\nSAVED user edits (v{saved[0]['v']}..v{saved[-1]['v']}) not yet ported into the builder. "
          f"Changes since v{base['v']}:")
    show_changes(base["html"], last["html"])

# Unsaved user edits: the working copy differs from the version it is based on.
if os.path.exists(DRAFT):
    with open(DRAFT, encoding="utf-8") as f:
        draft = json.load(f)
    base = by_v.get(draft["base"], last)
    if paragraphs(draft["html"]) != paragraphs(base["html"]):
        print(f"\nUNSAVED user edits in the working copy (based on v{draft['base']}):")
        show_changes(base["html"], draft["html"])
    elif draft["base"] != last["v"]:
        print(f"\nworking copy: unedited v{draft['base']}, the server moves it to v{last['v']} automatically")

if not saved and not (os.path.exists(DRAFT) and paragraphs(draft["html"]) != paragraphs(by_v.get(draft["base"], last)["html"])):
    print("\nno user edits pending")

print("\ncomments (one file per version):")
for name in sorted(os.listdir(COMMENTS) if os.path.isdir(COMMENTS) else [], key=lambda n: int(re.sub(r"\D", "", n) or 0)):
    with open(os.path.join(COMMENTS, name), encoding="utf-8") as f:
        n = len(json.load(f).get("comments", []))
    print(f"  {name}: {n} comment(s)")
