# File Log Move Test Results

Changed `model_ColumnSetup_00.slx` by moving the `File Log` block from `IsolatorSetup` into `IsolatorSetup/Measurements`.

Connection audit passed:

```text
Mux_5 -> Measurements/log signals -> File Log
```

Both physical Speedgoat runs used a 60 s stop time.

| Metric | Baseline | After move | Difference |
| --- | ---: | ---: | ---: |
| Duration (s) | 60 | 60 | 0 |
| Sample count | 122881 | 122881 | 0 |
| fs (Hz) | 2048 | 2048 | 0 |
| dt (s) | 0.00048828125 | 0.00048828125 | 0 |
| RMS(dd - dm) (mm) | 7.0711235 | 7.07110872 | -1.47787986e-05 |

Artifacts:

- `baseline_pre_move.mat`
- `baseline_pre_move.png`
- `after_move.mat`
- `after_move.png`
- `comparison_metrics.txt`
- `isolator_setup_after_move.png`
- `measurements_after_move.png`
