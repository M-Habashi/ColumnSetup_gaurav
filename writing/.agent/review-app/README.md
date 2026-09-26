# Manuscript review app

Review page for the Paper 2 draft: comments, version history, and Word-style change tracking.

Double-click a paragraph, heading, caption, or table cell in the working copy to edit it in place. The isolated editor temporarily occupies that block's position, with Update and Cancel underneath; the side panel remains for comments and history. Typing and undo/redo run in a fixed-size browser document containing only the selected block, with no React runtime or full-manuscript stylesheet. Surrounding manuscript content stays unchanged while typing. Temporary editor controls never enter saved content. Equations remain protected and original paragraph/cell wrappers are retained. Comment autosave is separate.

- **Update paragraph** writes the working copy directly to `../manuscript2_journal_draft.json`. Reloading restores it. It does not create or overwrite a numbered version.
- **Cancel** discards only the open paragraph's unsubmitted changes.
- **Save** creates a new numbered version, including any open paragraph. It works after Update, even with no pending changes.
- **Version history > Revert** restores any saved edition into the working copy. All numbered editions remain intact. If the working copy has changes beyond the latest saved edition, a recovery version preserves them first.
- Disk failures keep the paragraph editor open for retry. Revision checks prevent a stale window from overwriting newer changes. No manuscript writes or word comparisons occur while typing.

- Content: `python ../build_manuscript2_journal.py "note"` writes `../manuscript2_journal_versions.js` and saves a new version when the article changes.
- Page: `pnpm build` writes the self-contained `../manuscript2_journal.html`. Rebuild only when this app changes.

The active paragraph draft is green. Update/Save marks added or changed words with persistent user-color spans while preserving inline formatting and equations. This comparison runs only on those explicit actions, never while typing.
