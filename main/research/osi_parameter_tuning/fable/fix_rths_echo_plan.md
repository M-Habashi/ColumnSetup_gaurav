# fix_rths_echo_plan — applying the echo fix + evidence gate on the Speedgoat

Implementation plan for the two changes validated in this folder
(`rths_echo_report.html`):

1. **Echo fix** — the OSI's command tap gets the FEM's strictly-proper
   output (`u_osi = G_T(dd_fem − D_fm·fm)`), removing the zero-lag force
   echo that biases the FRF estimate when the numerical loop is closed.
2. **Evidence gate** — the authority law only acts on the slow margin
   after the tap has carried real excitation for one full analysis
   window; otherwise it receives `b = NaN` and holds (its designed
   no-evidence path). Fast trips are never gated.

Estimator (`fable_osi`), law (`fable_auth`) and their tuning stay
**unchanged**. The gate is ~25 lines in the runtime's publish phase plus
5 parameters; the echo fix is pure Simulink wiring.

---

## 0. Analysis window: keep `window_s = 5.0` (decision + evidence)

Question asked: can the 5 s slow window shrink so the gate arms sooner
(worry: a major event early in the test)?

Structural limits first — shrinking the window cuts the number of Welch
segments and therefore `k_eff`, which *raises* the null-calibrated
coherence gate (fewer bins accepted, noisier margin):

| window_s | n_segment | k_eff | γ² gate |
|---|---|---|---|
| 5.0 | 17 | 9.11 | 0.433 |
| 4.0 | 13 | 7.03 | 0.534 |
| 3.0 |  9 | 4.96 | 0.688 |
| 2.5 |  7 | 3.92 | 0.793 |
| 2.0 |  5 | 2.89 | 0.912 ← almost nothing passes |
| 1.75 | 4 | 2.38 | 0.964 ← hard floor (n_segment ≥ 4) |

Measured on RTHS_02 (cleaned tap, healthy strong-motion span 60–90 s,
target 0.55) and on the cold-start event record
(`RTHS_instability_during_eq`, event ≈ 3 s after engagement), with the
gate's `arm_s = window_s + 1.5`:

| window_s | margin_filter_n | b median | step-to-step jitter | IQR | **below-target during HEALTHY EQ** | cold-start shed delay |
|---|---|---|---|---|---|---|
| **5.0** | 3 | 0.663 | 0.0025 | 0.017 | **0.0 %** | +10.6 s |
| 4.0 | 3 | 0.662 | 0.0110 | 0.020 | 7.5 % | +9.2 s |
| 3.0 | 3 | 0.655 | 0.0081 | 0.032 | 10.0 % | +8.5 s |
| 2.5 | 3 | 0.654 | 0.0114 | 0.056 | 14.1 % | +7.0 s |
| 3.0 | 5 | 0.657 | 0.0067 | 0.032 | 10.0 % | +8.5 s |

**Decision: keep 5.0 s (arm_s 6.0).** Shrinking to 2.5 s buys only
3.6 s of cold-start response — the law's own confirm/filter dynamics
dominate after arming — while the healthy margin starts crossing the
target 7–14 % of the time. Those are persistent small sheds during good
tests: the exact failure mode this whole effort removes. If a shorter
window is ever wanted, `window_s = 3.0` + `margin_filter_n = 5` is the
least-bad point (one `hs.fable_osi_override` line, nothing else changes),
at the cost of ~10 % healthy below-target time.

What actually protects the first seconds of a test:
* fast burst / FRF guards are **not gated** (runtime processes trips
  before the NaN hold) — they act as soon as their calibration exists;
* the rig's displacement/force interlocks (independent of the OSI);
* operational: start EQ intensity low for the first runs after a change.
A genuine divergence *inside the very first arming window* is
statistically indistinguishable from "healthy loop under new input"
using (u, y) — the ~9–11 s cold-start delay is an information limit, not
a tuning miss.

---

## 1. Simulink: the echo-free OSI tap (`model_ColumnSetup_00`)

### 1.1 What the wiring must produce

```
u_osi = G_T( dd_fem − D_fm · fm )          % = G_T(C·x): strictly proper
```

* `dd_fem` — the FEM block's output, tapped **before** the phase lead.
* `fm` — the same measured-force signal the FEM consumes (same wire).
* `D_fm` — the discrete FEM's direct feedthrough **as built in the
  model**, i.e. the same constant vHS uses
  (`numericalSubstructureDiscrete`):

  ```matlab
  D_fm = 1000*(hs.interface_from_floor*force_to_displacement ...
               + hs.interface_from_force*hs.force_sign);   % mm/N
  ```

  Use the model's own constant, not bare `1000*interface_from_force` —
  the discretization adds the `interface_from_floor*force_to_displacement`
  term (this is why the offline record fit came out ≈ 0.92 instead of
  1.0; the structural subtraction is exact).
* `G_T` — a **copy** of the existing phase-lead block (same discrete
  realization, same parameters). The actuator path keeps its own lead;
  only the OSI tap gets a second instance.

### 1.2 Blocks to add (inside the hybrid-simulation subsystem)

The subtraction must be **active only when the numerical loop is
actually closed** — i.e. only when the signal generator's Multiport
Switch is set to the RTHS/hybrid port. For every other test-signal port
(time history, BLWN, sine …) there is no echo in the command, and
subtracting a reconstructed one would *inject* an echo into a clean tap
(demonstrated offline: it corrupts open-loop replays). The selection is
manual in Simulink today ("Select the active test signal manually"), so
the tap must follow the **same control signal that drives the Multiport
Switch** — one source of truth, nothing new for the operator to
remember:

| new block | type | settings / wiring |
|---|---|---|
| `OSI tap D-term gain` | Gain | gain = `fbl_dfm` (new workspace scalar from §3), input = the `fm` wire feeding the FEM |
| `OSI tap subtract` | Sum (+−) | `+` = FEM output `dd_fem` (pre-lead), `−` = `OSI tap D-term gain` |
| `OSI tap phase lead` | copy of the existing phase-lead block | input = `OSI tap subtract` |
| `OSI tap is-RTHS` | Compare To Constant | input = the **control input of the signal generator's Multiport Switch** (tap the same wire/constant), constant = the RTHS port index, output = boolean |
| `OSI tap source switch` | Switch | in1 = `OSI tap phase lead` (used when `OSI tap is-RTHS` is true), in3 = the ordinary `dd` wire the OSI uses today, control (in2) = `OSI tap is-RTHS` |

Then **rewire the fable block's `dd` inport** (currently a `From` of the
numerical command) to `OSI tap source switch`. Nothing else moves:

* actuator path `dd_fem → phase lead → PID … → Command to MTS`: untouched;
* `Apply OSI gain` product on `dc`: untouched;
* `dm`, `en` inports: untouched;
* non-RTHS ports behave **bit-identically to today** (the switch routes
  the exact same `dd` wire the block reads now).

> If the Multiport Switch is driven by a hand-edited Constant block, tap
> that Constant — do NOT create a second, independent flag. If it is a
> Manual Switch chain instead of a Multiport Switch, replace the manual
> selection with an indexed Constant + Multiport Switch first, so one
> integer selects both the test signal and the OSI tap. A wrong tap in
> injection mode produces `u_osi = −G_T(D_fm·fm)` — pure garbage that
> the estimator will read as a bad margin.
>
> Mode changes mid-run: flipping the selector changes the OSI's input
> regime; the estimator's own excitation-regime detector rebaselines and
> the evidence gate (§2) re-arms — no extra handling needed, but expect
> ~6 s of held authority after a flip.

### 1.3 Logging

Grow `Mux_5` by one and log `u_osi` (the signal the OSI actually saw) as
a new File-Log column; update the column comment + save section of
`main_ColumnSetup.m`. This makes every future offline replay exact (no
more echo reconstruction with a fitted scale).

---

## 2. Runtime: evidence gate in `control_and_HS/OSI/fable_osi_runtime.m`

Desktop reference implementation: `fable_evidence_gate.m` (this folder)
— copy it to `OSI_tests/fable/` when applying, so the equivalence test
can call it. Defaults (validated in `run_evidence_gate_validation.m`):
`theta_mm 0.05, exc_win_s 2.0, arm_s 6.0, drop_s 0.75, fade_short_s 1.0,
fade_long_s 6.0, fade_frac 0.5, fade_hold_s 4.0`.

### 2.1 New persistents (with the other authority scalars, ~line 110)

```matlab
persistent g_ms g_pos g_n g_acc g_cnt g_arm g_drop g_blank
% g_ms: 48x1 per-step mean squares (fade_long_s / step_s); rest scalars
```

Initialize with the other persistents: `g_ms = zeros(48,1); g_pos = 0;
g_n = 0; g_acc = 0; g_cnt = 0; g_arm = 0; g_drop = 0; g_blank = 0;`
(and in the `en >= 2` pause-reset branch, reset all eight).

### 2.2 Per-tick accumulation (top of the per-sample section)

```matlab
g_acc = g_acc + dd*dd;          % dd inport == the cleaned tap after §1
g_cnt = g_cnt + 1;
```

### 2.3 Gate update + margin blank (publish phase, `ph == P_PUB`)

Insert **after** `b` is combined (after the `recal_k` block, ~line 692)
and **before** `valid_k` / `fableAuthStep`:

```matlab
% ---- evidence gate: hold authority while the tap carries no evidence --
g_pos = mod(g_pos, 48) + 1;
g_ms(g_pos) = g_acc/max(g_cnt, 1);
g_acc = 0; g_cnt = 0;
g_n = min(g_n + 1, 48);
s_pres = 0; s_short = 0;                    % newest 16 / 8 entries
for gi = 0:15
    gj = mod(g_pos - gi - 1, 48) + 1;
    s_pres = s_pres + g_ms(gj);
    if gi < 8, s_short = s_short + g_ms(gj); end
end
exc_pres  = sqrt(s_pres/min(16, g_n));
exc_short = sqrt(s_short/min(8, g_n));
exc_long  = sqrt(sum(g_ms)/g_n);
gate_th   = fbla(32);                       % theta_mm
if g_n >= 48 && exc_short < fbla(35)*exc_long && exc_long > gate_th
    g_blank = fbla(36);                     % fade: blank, don't disarm
else
    g_blank = max(0, g_blank - c.step_s);
end
if g_n >= 16 && exc_pres > gate_th
    g_arm = g_arm + c.step_s;  g_drop = 0;
else
    g_drop = g_drop + c.step_s;
    if g_drop >= fbla(34), g_arm = 0; g_blank = 0; end
end
g_armed = g_arm >= fbla(33) && g_blank <= 0;
if ~g_armed
    b = NaN;                                % law's no-evidence path: HOLD
end
% (W.trip_k passes through untouched - fast guards stay live)
```

and change the two law inputs that must not report evidence while
unarmed:

```matlab
-        [... ] = fableAuthStep( ...
-            b, S.sb_stvalid, W.trip_k, W.bf_k, S.sb_pred, ...
-            S.sb_predvalid && c.pred_enable ~= 0, c.alpha_grid, ...
+        [... ] = fableAuthStep( ...
+            b, S.sb_stvalid && g_armed, W.trip_k, W.bf_k, S.sb_pred, ...
+            S.sb_predvalid && c.pred_enable ~= 0 && g_armed, c.alpha_grid, ...
```

Optionally publish `g_armed` (add to the `decision` output encoding or a
9th outport + Mux column) — recommended for the shadow-mode acceptance
checks.

Ring/counter sizes above assume the defaults (48 = 6 s/0.125 s,
16 = 2 s, 8 = 1 s). If the gate windows are to stay tunable, derive the
three counts from `fbla` entries in `unpackConfig` instead of literals.

### 2.4 Parameters: `control_and_HS/OSI/prepare_fable_runtime.m`

`fbla` currently ends at index 31. Append:

```matlab
% ---- evidence gate (indices 32-36) --------------------------------------
gate = struct('theta_mm', 0.05, 'arm_s', 6.0, 'drop_s', 0.75, ...
    'fade_frac', 0.5, 'fade_hold_s', 4.0);
if isfield(hs, 'fable_gate_override') && ~isempty(hs.fable_gate_override)
    fn = fieldnames(hs.fable_gate_override);
    for i = 1:numel(fn), gate.(fn{i}) = hs.fable_gate_override.(fn{i}); end
end
fbla(32) = gate.theta_mm;
fbla(33) = gate.arm_s;
fbla(34) = gate.drop_s;
fbla(35) = gate.fade_frac;
fbla(36) = gate.fade_hold_s;
```

Also export the §1 constant for the Gain block:

```matlab
assignin('base', 'fbl_dfm', D_fm);   % computed exactly as vHS does
```

Document indices 32–36 in the file's `fbla` index map comment.

### 2.5 `main_ColumnSetup.m`

```matlab
hs.fable_gate_override = struct();   % defaults; override to tune
```

plus the Mux/save-section updates from §1.3 (and §2.3 if `armed` is
logged).

---

## 3. Desktop-side equivalence

`OSI_tests/fable/test_fable_runtime_equivalence.m` gains the gate on the
desktop side of the comparison: run `fable_osi` step + copied
`fable_evidence_gate` step + `fable_auth` (b→NaN while unarmed, same
pass-through of trips), mirroring §2.3 exactly. Acceptance stays
**bitwise** (`max|Δ| = 0` on margins AND authority) on:

* the three historical records,
* the synthetic path-coverage stream,
* RTHS_02's **cleaned** tap (new: exercises the gate's arm/fade paths —
  use the logged `u_osi` column once §1.3 exists; until then the
  reconstruction from `rths_echo_diagnosis.m`).

---

## 4. Staged verification (same discipline as fable_simulink.md §5)

| stage | what | acceptance |
|---|---|---|
| A | `test_fable_runtime_equivalence` (with gate) | bitwise, all streams |
| A2 | `OSI_tests/overloadin_test/run_overloading_test.m` | TETMax within the 488 µs budget (gate adds ~70 flops per 0.125 s — negligible, but measure) |
| B | MIL: harness model replays RTHS_02's dd_fem/fm/dm through the new wiring | u_osi matches the offline cleaned tap sample-for-sample (now exact, no 0.92 fit); margin trace matches `rths_echo_diagnosis` fixed replay |
| C | build + bench, no hydraulics | clean codegen, TET, en=0 shadow behavior |
| D | **hardware shadow** (`osi_gain_enable_initial = 0`), one healthy RTHS at el-centro 0.06 | logged b ≈ 0.6–0.7 during strong motion (not 0.2–0.35); armed goes true ~6 s after engagement and false after the EQ dies; **zero fast trips**; authority output pinned |
| E | first active RTHS (`= 1`), low intensity | a = 1.0 throughout a healthy run — the start-of-test collapse is gone; operator kill switch tested once mid-run |
| F | re-run the two tests ruined by the live collapse (`rising_emergency`, `no_inst` protocols); save records to tests/important and add to the replay suites | margins healthy / correct sheds |

Rollback: the §1 rewire is one wire (OSI `dd` inport back to the old
`From`) plus `OSI_IMPL`/variant mechanics already in place; the gate is
disabled by `hs.fable_gate_override = struct('theta_mm', 0)` (always
armed) without rebuilding anything else.

---

## 5. Out of scope here, tracked separately

* **5k specimen target**: healthy inner margin ≈ 0.345 < target 0.55 —
  the law will detune 5k tests by design; decide a per-specimen target.
* **Outer-loop (numerical closed loop) margin monitor**: the wrap
  `L_out = −F_fm·k̂·G_T·T̂` evaluated on the OSI's existing per-bin T̂
  (see the discussion in the session notes / report): model-side outer
  margin is 0.399 @ 38 Hz vs inner 0.588 — worth adding as a second
  published margin later; not required for this fix.
