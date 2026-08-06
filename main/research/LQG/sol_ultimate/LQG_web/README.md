# LQG web report

This directory contains the component-based interactive report.

- `index.html` provides the page shell.
- `components/` contains article text and semantic markup.
- `styles/` contains focused presentation modules.
- `scripts/` contains the application shell and plot controllers.
- `data/` contains generated browser data.

Serve this directory over HTTP because the page loads its HTML components with `fetch`:

```powershell
python -m http.server 8000
```

Then open `http://127.0.0.1:8000/`.
