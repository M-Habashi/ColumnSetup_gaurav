# Simulink SI Unit Migration

Status: **not applied to `model_ColumnSetup_00.slx`**. The model remains unchanged pending access to MATLAB R2020b with Simulink Real-Time and the Speedgoat IO112/IO113 libraries.

## Required unit contract

| Signal | Model input/storage/visualization | Physical estimator calculation |
|---|---:|---:|
| `dd`, `dc`, `dm` | mm | m after an estimator-only Gain block |
| `fm` | N | N |
| `am` | g | not used by the online TSE estimator |
| `m_hat` | kg | kg |
| `c_hat` | N·s/m | N·s/m |
| `k_hat` | N/m | N/m |
| `tse_fallback` | dimensionless | dimensionless |

The model must not convert stored displacement to metres globally. Branch `dm` immediately before the online estimator and convert only that branch with an explicit Gain block. Acceleration enters the model in g because `main_ColumnSetup.m` now uses `v2a_gain = -1000/510` g/V.

## 1. Online TSE Estimator

Block:

`model_ColumnSetup_00/columnSetup/Online TSE Estimator`

The block currently receives and differentiates millimetres, producing damping and stiffness in N·s/mm and N/mm. Its input must instead be metres supplied by a dedicated upstream Gain block.

### Estimator-only conversion block

Create a branch from the raw measured-displacement signal without changing the existing mm path:

```text
dm (mm) ──┬── scopes, logging, control, and saved results
          └── Gain = 1e-3 ── dm_m (m) ── Online TSE Estimator
```

Configure the new block as follows:

| Property | Value |
|---|---|
| Block type | Gain |
| Block name | `mm to m - estimator only` |
| Gain | `1e-3` |
| Multiplication | element-wise |
| Input | raw `dm` in mm |
| Output signal label | `dm_m (m)` |

The Gain output must connect only to the Online TSE Estimator displacement input. The existing `dm` branches feeding scopes, control logic, Goto blocks, and the File Log Mux remain unchanged in mm.

If formal Simulink signal-unit propagation is enabled, explicitly mark or specify the Gain output as metres. The numeric conversion remains the `1e-3` Gain.

Use this unit header:

```matlab
function [m_hat, c_hat, k_hat, tse_fallback] = online_tse_estimator(dm_m, fm)
%#codegen
% Units: dm_m input is m and fm input is N. m_hat is kg, c_hat is
% N*s/m, k_hat is N/m, and tse_fallback is dimensionless.
```

Change the initial physical parameters:

```matlab
theta0 = [2.04; 12; 7028000];
theta_min = 0.02 * theta0;
```

Initialize the previous displacement directly from the metre input:

```matlab
dm_prev = dm_m;
v_prev = 0;
```

Replace the differentiation and regression-vector section with:

```matlab
v = (dm_m - dm_prev) / dt;
a = (v - v_prev) / dt;
dm_prev = dm_m;
v_prev = v;

z = [a, v, dm_m, fm];
```

The estimator then solves:

```text
fm = m_hat*a + c_hat*v + k_hat*dm_m
```

with `[a, v, dm_m, fm]` in `[m/s², m/s, m, N]`. The MATLAB Function contains no `/1000` conversion; its input contract is already metres. No conversion is allowed after `c_hat` or `k_hat` leaves the block.

Keep these values unchanged because they are already dimensionally compatible:

- `dt = 1/2048` s
- `window_samples = 2048`
- `update_samples = 64`
- `f_min = 120` N
- `route_ratio_max = 3`, dimensionless
- `tse_fallback`, dimensionless

Update the output comments to:

```matlab
% m_hat: online specimen mass estimate [kg].
% c_hat: online specimen damping estimate [N*s/m].
% k_hat: online specimen stiffness estimate [N/m].
```

## 2. Other embedded MATLAB Functions

Add a unit comment immediately below `%#codegen` in every embedded function.

| Block | Required comment |
|---|---|
| `Signal Generation/Pausable Time` | `pause_enable` dimensionless; `dt` and `tau` s |
| `Signal Generation/Pausable Time1` | `pause_enable` dimensionless; `dt` and `tau` s |
| `Signal Generation/Signal Change Blend` | `dd_raw`, internal displacement state, and `dd` mm; selector dimensionless; times s |
| `Signal Generation/Smooth Sine` | amplitude, setpoint, state, and output mm; frequency Hz; pause flag dimensionless; `dt` s |
| `Signal Generation/Smooth Square` | amplitude, setpoint, state, and output mm; frequency Hz; pause flag dimensionless; `dt` s |
| `Signal Generation/Smooth Stop Command` | input/output displacement mm; enable dimensionless; times s |
| `columnSetup/Online TSE Estimator` | `dm_m` m; `fm` N; outputs kg, N·s/m, N/m, and dimensionless fallback |

No numerical conversion is needed in the six signal-generation functions because the command path remains in mm.

## 3. Signal names and logged-channel metadata

Rename displayed signal labels without changing file-log order:

```text
dd (mm)
dc (mm)
dm (mm)
fm (N)
am (g)
m_hat (kg)
c_hat (N*s/m)
k_hat (N/m)
tse_fallback
```

Also label the estimator-only internal branch:

```text
dm_m (m)
```

Do not add `dm_m` to the File Log Mux; it is an internal physical-calculation signal only.

The File Log Mux must retain this exact column order:

| Column | Signal | Unit |
|---:|---|---|
| 1 | `dd` | mm |
| 2 | `dc` | mm |
| 3 | `dm` | mm |
| 4 | `fm` | N |
| 5 | `am` | g |
| 6 | `m_hat` | kg |
| 7 | `c_hat` | N·s/m |
| 8 | `k_hat` | N/m |
| 9 | `tse_fallback` | dimensionless |

Do not rename Goto tags or change Mux order. `main_ColumnSetup.m` extracts saved columns by position.

## 4. Scope configuration

Update scope channel names and limits so the displayed values match their numeric units.

### Displacement scope

Block: `model_ColumnSetup_00/columnSetup/Scope1`

Channel names:

```text
dd (mm), dc (mm), dm (mm)
```

Keep displacement limits numerically unchanged because the scope continues plotting mm.

### Force scope

Block: `model_ColumnSetup_00/columnSetup/Scope2`

Channel name:

```text
fm (N)
```

Keep force limits numerically unchanged.

### Stiffness scope

Block: `model_ColumnSetup_00/columnSetup/Scope3`

Channel name:

```text
k_hat (N/m)
```

Scale all cached stiffness limits by 1000:

| Property | Old | New |
|---|---:|---:|
| minimum real limit | 0 | 0 |
| maximum real limit | 8028 | 8,028,000 |
| minimum magnitude limit | 6028 | 6,028,000 |
| maximum magnitude limit | 8028 | 8,028,000 |

In R2020b, verify these values after closing and reopening the model. If `save_system` drops the Scope style/cache, update the persisted `ScopeSpecificationString` in the `.slx` XML only after the model and Scope windows are closed.

## 5. Model-version requirements

Edit and save this model in MATLAB/Simulink R2020b. Do not save it directly from R2025b: that upgrades the `.slx`, and exporting back can externalize model-workspace data into a generated `_saveas.m` file.

Required libraries before editing or compiling:

- Simulink Real-Time (`slrealtime`, `slrealtimeloglib`)
- Speedgoat IO112 library
- Speedgoat IO113 library

Pre-check:

```matlab
assert(exist('slrealtime', 'file') ~= 0)
load_system('slrealtimeloglib')
load_system('speedgoatlib_IO112')
load_system('speedgoatlib_IO113')
```

## 6. Verification procedure

1. Open `main_ColumnSetup.m`, set the current folder to `main`, and run to its target-run pause so the base workspace is initialized.
2. Confirm the `dm (mm)` signal branches before the new `1e-3` Gain and that only `dm_m (m)` enters the Online TSE Estimator.
3. Confirm the MATLAB Function contains no displacement `/1000` conversion and compiles without undefined `dm_m` or `a` variables.
4. Confirm all nine File Log columns retain their specified order and labels and that `dm_m` is not logged.
5. Run the target for 60 seconds.
6. Continue `main_ColumnSetup.m` so the exact run is imported and saved.
7. Run `results_analysis/visualize_saved_results.m` on that saved MAT file.
8. Confirm typical numerical scales:
   - displacement channels remain mm;
   - acceleration is g, not mm/s²;
   - force is N;
   - `m_hat` is kg;
   - `c_hat` is approximately 1000 times the former N·s/mm numeric value;
   - `k_hat` is approximately 1000 times the former N/mm numeric value.
9. Confirm `units.am == 'g'`, `units.c_hat == 'N*s/m'`, and `units.k_hat == 'N/m'` in the saved MAT file.
10. Store the saved MAT file, plots, and metrics under `.codex/verification/si_unit_migration`.

The current desktop cannot perform these steps because its R2025b installation does not include the required Simulink Real-Time or Speedgoat libraries.
