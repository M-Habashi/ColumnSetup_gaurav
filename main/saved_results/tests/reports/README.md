# RTHS Hysteresis Explorer

Refresh the browser data after adding or changing saved tests:

```matlab
export_hysteresis_report_data
```

Then serve this folder over HTTP:

```powershell
python -m http.server 8010 --directory .
```

Open `http://localhost:8010`. The report scans data exported from
`saved_results/tests/**/*.mat`; it never modifies the source MAT files.
