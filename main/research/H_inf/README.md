# H-infinity research workspace

This folder is the clean H∞ branch of the ColumnSetup control study. It is intentionally separate from `research/LQG`.

## Contents

- `LITERATURE_REVIEW.md` — dated evidence map, novelty audit, proposed equations, and validation gates.
- `H_inf_web/` — browser report using the same article-drawer and sticky-section architecture as the LQG report, with a green accent.

## Current status

This phase is a literature and research-design study. It does **not** claim that a new H∞ controller has already beaten the PID. The page separates established methods, blocked novelty claims, project-specific hypotheses, and the experiments required before a publishable claim can be made.

Serve the page from `H_inf_web` with any static HTTP server; for example:

```powershell
python -m http.server 8010
```

