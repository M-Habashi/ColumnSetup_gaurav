# RTHS Hysteresis Explorer

Refresh the browser data after adding or changing saved tests:

```matlab
export_hysteresis_report_data
```

Then run the report-local server so aliases, archived files, selections, colors,
alpha, time cutoff, and zoom persist in `data/report-metadata.json`:

```powershell
python serve_report.py
```

Open `http://localhost:8010`. The report scans data exported from
`saved_results/tests/**/*.mat`; it never modifies the source MAT files.
Renaming and archiving are report-only metadata operations; original MAT names
and paths remain unchanged and are retained in the metadata file.
