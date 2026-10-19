# Manuscript review workflow (for agents)

The workflow is active when `manuscript2_journal.html` contains `<meta name="review-workflow" content="enabled">`.

## Files in writing/.agent/
| File | Role | Who edits it |
|---|---|---|
| `build_manuscript2_journal.py` | The article text. Edit the text here only. | agent |
| `manuscript2_journal_versions.js` | All versions: v, date, note, html, author ("user" = saved from the page). | generated |
| `manuscript2_journal_draft.json` | The user's working copy, including unsaved edits. | the page |
| `comments/v<N>.json` | The user's comments on version N (quote, prefix, suffix, text). | the page |
| `../manuscript2_journal.html` | The review page, kept in `writing/`. Built from `review-app/` (`pnpm build`) only for UI changes. | never by hand |
| `review_server.py`, `open_review.cmd` | Local server at http://127.0.0.1:8765/manuscript2_journal.html. It saves comments and edits. | — |

## Every task starts with
`python writing/.agent/review_status.py`

It reports the latest version, **saved** user edits (trailing versions with author "user"), **unsaved** user edits (the working copy differs from its version), and the comment files.

## User edits come first
1. Port every saved and unsaved user edit into `build_manuscript2_journal.py`, word for word, before any other change.
2. Words the user added appear as `<span data-user-edit>` in the version html.
3. The builder refuses to run over a user version until you pass `--merged`.

## Make a new version
1. Edit the text in `build_manuscript2_journal.py`.
2. Run `python writing/.agent/build_manuscript2_journal.py "short note" [--merged]`. A version is added only if the article changed.
3. If you ported unsaved edits, run `python writing/.agent/review_status.py --adopt-latest`. Otherwise an unedited working copy follows the latest version automatically.
4. The open page shows the new version within a few seconds.

## Rules
- Comments belong to the version they were made on. Answer them in the next version. Never delete comment files or versions unless asked.
- Never edit the versions file, the working copy or the comment files by hand.
- If a comment asks to discuss first, propose options and wait.
- Write the text by `../md/writing_guide.md` and `../md/paper2.md`. Never edit the guides in `../md/` (`paper2.md`, `paper1.md`, `writing_guide.md`) without the user's permission.

## Apply a comment from the page (optional)
The sparkle button on a comment card asks an agent (`claude -p`, Opus, medium effort) to apply that one comment.
- `review_server.py` copies the builder to `suggest/<id>/build.py`, the agent edits only that copy by `writing_guide.md`, and the server rejects any change outside string literals before it renders the preview with `--preview`.
- The page shows the result as a diff in place. The card offers Apply, Cancel, and Regenerate with an editable prompt.
- Apply copies the reviewed builder back and runs the builder, so the result is an ordinary agent version with the note "Comment applied: …". It is refused if the builder changed meanwhile or if unmerged page edits exist.
- The applied comment stays in its own version file. The other comments of that version are copied to the new version so they stay open.
- Nothing else changes: comments, page edits and agent versions follow the rules above.
