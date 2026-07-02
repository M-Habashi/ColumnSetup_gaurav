# Adopting the Fable OSI + authority factor in `model_ColumnSetup_00`

Step-by-step instructions to replace the current M9.1/`auth_stability_gain`
runtime with the fable indicator (`fable_osi.m`) and authority law
(`fable_auth.m`), and the staged test protocol to prove it works before it
ever acts on the hardware.

All block names below are the actual names in `model_ColumnSetup_00.slx`
(verified against the model file). Read `fable_report.html` first for what
the algorithms do and why.

---

## 1. How the CURRENT runtime is wired (baseline you are changing)

**Preparation (MATLAB side).** `main_ColumnSetup.m` line ~92 calls

```matlab
osi_gain_setup = prepare_osi_gain_runtime(projectFolder, dt, hs);
```

which `assignin`s flattened parameter arrays into the base workspace:
`m91s, m91f, m91b, m91seg, m91w, m91keep, m91buf0, m91res0, m91base0,
m91hist0, m91below0, osigs`. The MATLAB Function block reads them as
**Parameter-scoped symbols**.

**Model side** (inside the hybrid-simulation subsystem):

| Block | Role |
|---|---|
| `M9.1 + OSI Gain` (subsystem) | contains the MATLAB Function block whose body is `osi_gain_runtime`. Inports: `dd` (from a `From` of the numerical command), `dm` (`From dm for M9.1`), `en`. Outports: `osi_gain_out`, `ncf_m91`, `ncf_filtered`. |
| `OSI Runtime Mode` (Sum) | builds `en = osi_gain_enable_switch + 2*dd_pause_enable` (`OSI Pause Code Gain` is the ×2). `osi_gain_enable_switch value` is a Constant bound to the runtime-tunable `osi_gain_enable_initial` parameter (`ExportedGlobal`, created in `main_ColumnSetup.m` lines 244–247). |
| `Apply OSI gain` (Product, yellow) | **the authority application point**: input 1 = `dc` (the MATLAB-side PID output command), input 2 = `osi_gain_out`. Output goes to `Saturation limit for the displacement signal that is sent to the MTS` → `Command to MTS`. So authority scales the loop gain (dc), which is exactly what `fable_auth`'s prediction math assumes — **keep this application point**. |
| `Mux_5` → `File Log` | logging. Columns as read back by `main_ColumnSetup.m`: 1 dd, 2 dc (post-product, post-saturation — i.e. the true plant input), 3 dm, 4 fm, 5 am, 6–8 m̂/ĉ/k̂, 9 tse_fallback, 10 dd_pause_enable, 11 ncf_m91, 12 ncf_filtered, 13 osi_gain. |

Key timing fact: the current block is called **every base-rate sample**
(2048 Hz) and internally time-slices one 512-sample segment FFT per OSI
hop. The fable runtime keeps the same per-sample calling convention but
does its work in 256-sample (0.125 s) internal steps.

---

## 2. Runtime files (MATLAB side) — **CREATED and validated 2026-07-02**

### 2.1 `control_and_HS/OSI/prepare_fable_runtime.m` ✔ exists

Mirror of `prepare_osi_gain_runtime`: builds the fable config from the
`hs` struct + exp_tf file and `assignin`s fixed-size parameter arrays
(`fbls, fblw, fblbins, fblfw, fblfbins, fblag, fbla` — index maps are
documented inside the file). Extra `hs` fields: `fable_osi_override`,
`fable_auth_override` (tuning structs, see the TUNING GUIDE headers of
`fable_osi.m` / `fable_auth.m`) and `fable_pred_enable` (set 0 as a TET
reduction).

Knob mapping from the existing `hs` fields:

| `hs` field (today) | fable destination |
|---|---|
| `target_outer_ncf` | `cfg.threshold` AND `prm.target` (default **0.55**: the law regulates the margin onto this level) |
| `osi_gain_min` | `prm.a_min` |
| `osi_gain_initial` | `prm.a_init` (recommend 1.0 for fable — the law defends the margin; starting detuned is no longer needed) |
| `osi_st_branch_hz`, `osi_residual_branch_hz`, `osi_branch_split_hz` | **delete** — replaced by `cfg.residual_band_hz` (default [28 100]) and the automatic excited/quiet classification |

Flattening (everything the block needs, all fixed-size):

| workspace name | contents |
|---|---|
| `fbls` | scalar config vector (dt, fs, band, segment/hop/step sizes, nfft, n_segment, k_eff, gamma gates, thresholds, CUSUM ν/h for both fast paths, calibration sizes, regime/residual constants, cap, alpha-grid size…). Document each index in the file, like `m91s`. |
| `fblf`, `fblb`, `fblkeep`, `fblresk`, `fblcurve` | slow freq grid, FFT bin indices, keep mask, residual-band mask, nominal chordal curve |
| `fblw` | 2048-pt Hann window |
| `fblff`, `fblfb`, `fblfkeep`, `fblfw`, `fblcell` | fast grid, fast bins, fast keep, 512-pt Hann, fast-cell lo/hi projection indices |
| `fblbands` | fast burst sub-band id per fast bin |
| `fblag` | 25-pt alpha grid |
| `fauth` | authority-law parameter vector (target, up_db, sev_frac, confirm, a_min/max/init, rates, hold, power law, pred guard/floor, latch constants, trip constants, filt alpha) |

### 2.2 `control_and_HS/OSI/fable_osi_runtime.m` ✔ exists

The Simulink MATLAB Function body (`%#codegen`). Same calling convention
as `osi_gain_runtime` — **called once per base-rate sample**:

```matlab
function [auth, b_osi, b_st, b_res, b_fast, trip_reason, valid, decision] = ...
    fable_osi_runtime(dd, dm, en, fbls, fblw, fblbins, fblfw, fblfbins, ...
    fblag, fbla)
```

Per call: one sample into circular raw rings (no per-tick buffer copy,
unlike the m91 runtime); every **256th** sample one fable step (fast
segment FFT + fast statistics + every 2nd step the slow segment FFT +
slow branches) and one authority-law step; outputs held between steps.
All estimator state is fixed-size persistents; the authority state is a
set of scalar persistents. The header contains the **TET/overload
playbook** (what to change if the target overruns, in order of
preference).

Implementation notes (already handled — kept here for future edits):

- `movmedian`/`median` even-count averaging is replicated exactly
  (`medianWindowRt`/`medianFirstN` — the two builtins use DIFFERENT
  rounding rules; established by fuzzing, do not "simplify").
- Masked medians use fixed-size scratch buffers + `sort` (no
  variable-size arrays); `movmax` is a hand-coded shrink-endpoint loop.
- The fast FRF-change statistic is armed only while the applied
  authority has been steady for one full analysis window (the runtime
  feeds its own committed `auth` into the estimator's `a_cmd` contract),
  so the law cannot trip on its own moves.

**Enable/pause contract (keep identical to today):**

- `en >= 2` (pause): reset the raw rings, spectra rings, CUSUMs and margin
  history; **keep** the calibrated baseline/µ/σ and the auth state (this is
  what `osi_gain_runtime` does). On resume the regime detector re-checks
  the input support anyway.
- `en == 0`: keep estimating (publish `b` etc.) but output
  `auth = a_init` — shadow mode.
- `en == 1`: publish the law's authority.

### 2.3 Equivalence test `OSI_tests/fable/test_fable_runtime_equivalence.m` ✔ exists, PASSING

Feeds the same dd/dm stream through `fable_osi_runtime` sample-by-sample
and through the `fable_osi` + `fable_auth` desktop loop, asserts the
margin, branch, trip and authority traces match. **Status: bitwise
(`max|diff| = 0`) on all three records + a synthetic path-coverage
stream (2026-07-02).** Stage A of §5 is therefore complete; rerun the
test after ANY change to the three runtime/desktop files.

---

## 3. Model changes, click by click

1. **Branch the model** (`git`) and save a copy of `model_ColumnSetup_00.slx`.
2. Open the subsystem containing `M9.1 + OSI Gain` (Ctrl+F → search
   "M9.1").
3. **Wrap for rollback**: select the `M9.1 + OSI Gain` subsystem →
   right-click → *Subsystems & Model Reference → Convert to Variant
   Subsystem*. Add a second variant choice `Fable OSI + Auth`. Control
   variable `OSI_IMPL` (0 = legacy, 1 = fable) defined in
   `main_ColumnSetup.m`.
4. Inside the fable variant, add a **MATLAB Function block**; set its body
   to call `fable_osi_runtime`. In the *Symbols* pane mark
   `fbls, fblf, …, fauth` as **Parameter** data (they resolve from the
   base workspace exactly like `m91s`… do today).
5. Reconnect the three inports exactly as the legacy block:
   `dd` (same `From`), `dm` (`From dm for M9.1`), `en` (`OSI Runtime
   Mode`). **Do not change `OSI Runtime Mode`, `dd_pause_enable`, or the
   `osi_gain_enable_initial` mechanism.**
6. Outputs (block emits `auth, b_osi, b_st, b_res, b_fast, trip_reason,
   valid, decision`):
   - `auth` → the same wire `osi_gain_out` used: to `Apply OSI gain`
     input 2, to `OSI Gain Scope`, and to the `Mux_5` input that becomes
     File-Log column 13.
   - `b_osi` (selected margin) → the `ncf_m91` mux input (column 11).
   - `b_fast` → the `ncf_filtered` mux input (column 12) — repurposed;
     update the column comment in `main_ColumnSetup.m`.
   - **Grow `Mux_5` by five** and log `b_st`, `b_res`, `trip_reason`,
     `valid`, `decision` as columns 14–18 (update the Mux size, the File
     Log signal, and the save section of `main_ColumnSetup.m`, lines
     288–301, to read them). Terminate any output you choose not to log.
7. **Verify the authority application point is untouched**: `dc` →
   `Apply OSI gain` → saturation → `Command to MTS`. Column 2 of the log
   stays the post-product dc (true plant input) — the offline analyses
   rely on that.
8. Set the block sample time to inherited (base rate, 1/2048 s), same as
   the legacy block.
9. Update `main_ColumnSetup.m`:
   ```matlab
   OSI_IMPL = 1;                                    % 0 = legacy runtime
   fable_setup = prepare_fable_runtime(projectFolder, dt, hs);
   ```
   keep the legacy `prepare_osi_gain_runtime` call while the variant
   exists (both parameter sets can coexist — different names).

---

## 4. Real-time budget

Per 0.125 s step: one 512-pt FFT ×2 signals every step, one 2048-pt FFT
×2 signals every second step, plus medians over 99×17 and 25×3 arrays and
the 25-point×25-bin prediction grid every second step. This lands in ONE
base-rate tick every 256 ticks (bursty). On the Speedgoat:

- Measure **TET** with the block in shadow mode. Acceptance: worst-case
  TET < 50% of the 488 µs tick.
- If the burst tick exceeds budget: move the block into a **triggered
  subsystem at 16 Hz** fed by a 256-sample Buffer (rate transition), or
  split the slow-hop work across two consecutive steps (compute slow FFT
  on odd steps, slow aggregation on even). The algorithm is unchanged
  either way; only scheduling moves.

---

## 5. Staged verification — make sure it works before it can act

Every stage has an explicit acceptance criterion. Do not skip stages.

**Stage 0 — algorithm baseline (already passing).**
`run_fable_synthetic_checks` → 5/5 PASS (incl. authority moving ≤0.5 s
after excited-band damage), `run_fable_osi_tests` → 0 false-low, 0
healthy fast trips on all three records.

**Stage A — wrapper equivalence (desktop).**
`test_fable_runtime_equivalence` on all three records. Acceptance:
`max|Δb| = 0`, `max|Δauth| = 0` (bitwise; it is the same arithmetic).

**Stage B — model-in-the-loop (Normal mode).**
Small test harness model: `From Workspace` feeds a recorded dd/dm pair
into the new block (en = 1). Acceptance: traces identical to Stage A.
Then run the full `model_ColumnSetup_00` in Normal mode against the vHS
plant surrogate if available; sanity: calibration completes ~30 s, margin
plausible, no trips on a healthy run.

**Stage C — build & bench (Speedgoat, no hydraulics).**
Build the real-time application. Acceptance: clean codegen, TET criterion
of §4, and a dry loopback run (analog out looped to dm in, or zero
inputs) shows: margin NaN→cap behavior, no trips, `auth = a_init`
constant with `en = 0`.

**Stage D — hardware shadow mode (`osi_gain_enable_initial = 0`).**
Run a standard healthy EQ test (the 1930 protocol). The indicator
computes and logs; the authority output is forced to `a_init` and, being
1.0, does not alter the loop.
Acceptance:
- live-logged `b` matches `fable_osi('run', dd, dm, …)` recomputed
  offline from the same record (same code ⇒ near-identical);
- calibration `ready` before excitation starts; a regime recalibration
  fires at excitation start (visible as a short margin-NaN gap) and none
  after within a steady phase;
- **zero fast trips** during the healthy test;
- margin tracks the offline reference (compute with
  `run_fable_osi_tests`-style reference on the new record).
Repeat shadow mode for at least: one EQ test, one low-band test, one
step/hold test — the three excitation classes the record replays cover.

**Stage E — first active test (`osi_gain_enable_initial = 1`).**
Conservative parameters for the first run: `a_min = 0.3`,
`target_outer_ncf = 0.3`, healthy specimen, low intensity.
1. Healthy run: acceptance — `a` stays at 1.0 throughout (no adaptation).
2. Controlled marginality (the Pvar protocol): ramp the MATLAB-side P
   mid-test exactly like the 20260617 records. Acceptance —
   * a fast trip or margin crossing within 0.5 s of the collapse onset
     (broadband command present);
   * authority sheds, oscillation is arrested (compare dm against the
     769 s excursion of record 1731);
   * recovery is slow and latched (no sprint back to 1.0);
   * the operator kill (enable → 0 forces `a_init`; pause resets rings)
     works at every point — test it once mid-shed.
3. Only after E passes, restore `a_min = 0.08` and production targets.

**Stage F — regression lock-in.**
Save the Stage D/E records into `saved_results/tests/important` and add
them to `run_fable_osi_tests`'s record list so future changes replay
against real closed-loop data.

---

## 6. Behavior differences the operators must know

| Situation | legacy runtime | fable |
|---|---|---|
| healthy test | margin reads ≈0.3 (biased), gain collapses to 0.08 and stays | margin ≈ reference, `a = 1.0`, zero false trips (validated on all 3 records) |
| command off / pause | margin still "computed" (fiction) | margin = cap with `valid` semantics; authority holds |
| test phase change | residual branch false-alarms | automatic regime rebaseline (~20 s of residual-branch downtime, ST branch keeps running); a trip inside the transition window is auto-undone |
| genuine instability | detects late (14.7 s on the 1749 event) via its bias | trip + shed ≤0.5 s with coherent excitation; 1.5 s on the 1749 event replay; quiet-band-only mild deficits regulate to within 0.08 of target (information limit) |
| after an event | gain sprints back to 1.0 in seconds | slow, latched recovery (deliberate); full recovery takes minutes unless a regime recal explains the trip away |

## 7. Rollback

Set `OSI_IMPL = 0` (variant switch) and rebuild — the legacy block, its
parameters, and `prepare_osi_gain_runtime` are untouched. Keep both until
Stage F has accumulated at least a few production tests.
