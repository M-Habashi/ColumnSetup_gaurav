# numerical_ncf_plan — fixing the outer-loop (numerical closed loop) NCF
# in vHS, and publishing it online by wrapping the estimator's T̂

Companion to `fix_rths_echo_plan.md`. Two work packages:

* **WP-A: vHS** — make the design-time `num_exp` margin honest
  (dynamic interface impedance instead of a static spring; propagate the
  authority factor into the outer loop).
* **WP-B: online** — publish a live outer-loop NCF margin by wrapping
  the per-bin T̂ the fable OSI already estimates with the exactly-known
  numerical-side dynamics. No new identification.

## 0. Baseline facts (measured in this study)

* vHS's outer-loop factorization is structurally correct:
  `L_out = −(FEM fm→dd incl. D_fm)·k_mm·G_T·PID_H_dc_dm`, NCF = min
  chordal distance over 0.1–80 Hz (`custom_stability_margins`) + an
  exact coupled-pole check. The FEM feedthrough IS in there — the model
  always knew about the term that corrupted the OSI tap.
* With the C·H₇₀₀₀ plant model: **outer margin 0.399 @ 38 Hz** vs inner
  0.588 @ 35 Hz → the numerical closed loop is the **binding** loop, in
  exactly the 30–45 Hz band where the real RTHS instabilities appeared —
  and it is unmonitored online today.
* The wrap evaluated on the *measured* T̂ (RTHS_02, cleaned tap, t = 95 s
  window) agrees with the model wrap at every excited bin
  (2–20 Hz: 0.75–0.98 measured vs 0.73–0.97 model; one noisy bin 0.47 vs
  0.62). The mechanics work on real data.
* Weaknesses to fix: (1) `fm = k·dm` static spring — the measured force
  path has ~28 % broadband non-stiffness content (damping + moving-mass
  inertia, growing as ω²), so the high-frequency outer gain is
  misestimated where it binds; (2) `recommendAuthStabilityFactor`
  re-evaluates only the INNER margin under authority scaling although
  the authority multiplies the outer loop too; (3) design-time only.

---

## WP-A — vHS fixes (`control_and_HS/d_HS/vHS.m`)

### A.1 Dynamic interface impedance Z(ω) instead of k_mm

Replace the static spring with the specimen impedance

```
Z(ω) = k + c·(jω) + m·(jω)²        [N/m],   Z_mm = Z/1000  [N/mm]
```

Parameter sources, in order of preference:
1. identified k̂/ĉ/m̂ — medians of the record estimates (`k_hat`,
   `c_hat`, `m_hat` are already saved in every test record; the fable
   stiffness estimator gives the same triple), or
2. specimen file `k` + assumed c, m (m = moving mass incl. fixture +
   load-cell side; even a rough m matters at 40 Hz), with `c = 0, m = 0`
   reducing exactly to today's behavior.

Because `m·s²` is improper, do this in frequency response (that is all
the margin needs), not as a `tf`. In `buildVhsStabilityTable`:

```matlab
% ---- OLD -----------------------------------------------------------
num_exp_metrics = stabilityMetrics( ...
    -minreal(num_tf*k_mm*PID_H_dc_dm), ...
    num_exp_stability.coupled_max_abs_pole, freq_range_hz);
num_phase_lead_exp_metrics = stabilityMetrics( ...
    -minreal(num_tf*k_mm*phase_lead_tf_discrete*PID_H_dc_dm), ...
    num_phase_lead_exp_stability.coupled_max_abs_pole, freq_range_hz);

% ---- NEW: impedance-weighted outer loop as an frd -------------------
fgrid_hz = logspace(log10(freq_range_hz(1)), ...
    log10(freq_range_hz(2)), 4000).';
w = 2*pi*fgrid_hz;
Zw_mm = (specimen_imp.k + specimen_imp.c*(1i*w) ...
    + specimen_imp.m*(1i*w).^2)/1000;               % N/mm
Fw = squeeze(freqresp(num_tf, w));                  % FEM fm->dd (mm/N)
Tw = squeeze(freqresp(PID_H_dc_dm, w));
Gw = squeeze(freqresp(phase_lead_tf_discrete, w));
Lout_frd      = frd(-Fw.*Zw_mm.*Tw,     w);         % no lead
Lout_lead_frd = frd(-Fw.*Zw_mm.*Gw.*Tw, w);
num_exp_metrics = stabilityMetrics(Lout_frd, ...
    num_exp_stability.coupled_max_abs_pole, freq_range_hz);
num_phase_lead_exp_metrics = stabilityMetrics(Lout_lead_frd, ...
    num_phase_lead_exp_stability.coupled_max_abs_pole, freq_range_hz);
```

(`custom_stability_margins` only calls `freqresp` on its argument, so an
`frd` passes through unchanged; keep the grid ≥ the 10 000 points it
resamples to, or pass the frd's own grid band.)

`specimen_imp` enters vHS next to the specimen load
(`specimen_params_si`); print k/c/m and the source in the banner.

Notes:
* The **coupled-pole rows** (`analyzeActuatorLoop`) still use static k;
  upgrading them means realizing Z discretely (k + c·backward-difference
  + m·second-difference) inside the coupled state-space. Do it as a
  second step — the margin rows are the actionable output; keep the pole
  rows labeled "static-k" until then.
* Optional, separate flag: `hybridResponseWithPidHdcDm` also simulates
  `fm = k·dm`; switching the simulated force to Z(dm) changes vHS
  time-domain results and should be its own validated change, not
  bundled here.

### A.2 Propagate the authority factor into the outer loop

`recommendAuthStabilityFactor` currently scans factors and checks the
INNER NCF only. Extend it to require both loops:

```matlab
function [factor, ncf_in, ncf_out] = recommendAuthStabilityFactor( ...
        open_loop, current_factor, target_in, target_out, ...
        freq_range_hz, outer_wrap)
% outer_wrap: struct with Fw, Zw_mm, Gw and the shared w grid (A.1)
factors = linspace(0.02, 1, 80).';
ncf_i = NaN(size(factors)); ncf_o = NaN(size(factors));
for i = 1:numel(factors)
    Lf = (factors(i)/current_factor)*open_loop;
    [~, ~, ncf_i(i)] = custom_stability_margins(Lf, freq_range_hz);
    Tf = squeeze(freqresp(feedback(Lf, 1), outer_wrap.w));
    Lo = frd(-outer_wrap.Fw.*outer_wrap.Zw_mm.*outer_wrap.Gw.*Tf, ...
        outer_wrap.w);
    [~, ~, ncf_o(i)] = custom_stability_margins(Lo, freq_range_hz);
end
ok = ncf_i >= target_in & ncf_o >= target_out;
...   % pick last ok, else max(min(margins)); report both
```

and print both margins at the recommended factor. Suggested
`target_out`: 0.30 to start (the outer loop never had an explicit
target; pick after looking at the A.1 numbers across specimens).

### A.3 Acceptance for WP-A

* With `c = m = 0` the new code reproduces today's table to numerical
  noise (regression guard).
* With identified c, m: outer margin at 30–80 Hz shifts; document the
  new `num_phase_lead_exp` row per specimen (5k and 7k).
* The phase-lead optimizer (`optimize_vHS_phase_lead*`) uses the same
  static-k outer loop in its constraint path — port A.1 there once the
  vHS numbers are reviewed, or future leads keep being designed against
  the optimistic outer loop.

---

## WP-B — online outer-loop margin: wrap the estimator's T̂

### B.1 Principle

Everything numerical-side is known software: `F_fm(ω)` (FEM fm→dd,
D-term included), `G_T(ω)` (phase lead), k̂ (specimen). The only unknown
in the outer loop is the physical T — which the fable OSI already
estimates per bin (as `M`) on the echo-cleaned tap. So per slow hop:

```
L_out(ω) = W(ω)·M(ω),    W(ω) = −F_fm(ω)·k̂_mm·G_T(ω)   (precomputed)
b_out(ω) = |1 + L_out|/sqrt(2·(1 + |L_out|²)),  min over excited bins
```

A complex multiply and the existing chordal formula per excited bin —
no new spectra, no new identification.

### B.2 `prepare_fable_runtime.m`: precompute the wrap curve

```matlab
% ---- outer-loop wrap W on the slow grid (indices as fblbins) ---------
num_model = numericalSubstructureDiscrete(hs, dt);   % same math as vHS
num_tf = ss(num_model.A, num_model.B_fm, num_model.C, num_model.D_fm, dt);
Gd = c2d(phase_lead_tf, dt, 'tustin');               % the model's lead
w = 2*pi*cfg.freq_hz;
k_mm = hs.k_online/1000;             % [N/m] -> [N/mm]; dm is in mm
Wc = -squeeze(freqresp(num_tf, w)).*k_mm.*squeeze(freqresp(Gd, w));
% units close: num_tf is mm/N (its D_fm already carries the x1000),
% k_mm is N/mm, G_T dimensionless -> W and L_out = W*T dimensionless.
% Same convention as vHS's buildVhsStabilityTable (num_tf*k_mm*...).
fblow = [real(Wc) imag(Wc)];         % nf x 2 parameter array
assignin('base', 'fblow', fblow);
```

`hs.k_online` = specimen k̂ (same source as WP-A). When the hybrid loop
is not in use (`fblow` zeros), the branch reports NaN and costs nothing.
(`numericalSubstructureDiscrete` is a local function of vHS today —
lift it to `helpers/` so vHS, the optimizer and prepare share one copy.)

### B.3 `fable_osi.m` (desktop): ~12 lines in `slowHop`

Config: two new fields in `makeConfig` — `outer_w` (complex nf×1,
default `[]` = branch off), no other knobs.

```matlab
% after the ST branch (b_st/f_st computed), same masks:
b_outv = NaN; f_outv = NaN;
if ~isempty(cfg.outer_w) && st_valid
    Lo = cfg.outer_w.*M;
    bo = abs(1 + Lo)./sqrt(2*(1 + abs(Lo).^2));
    bo = maskedMovMedian(bo, excited, cfg.freq_medfilt_n);
    bo(~excited) = NaN;
    [b_outv, i_o] = min(bo);
    f_outv = cfg.freq_hz(i_o);
end
state.sb_bout = b_outv;   % + init in makeState, + info fields
state.sb_fout = f_outv;
```

Report `info.ncf_out`, `info.f_out_hz`. **Publish-only**: `b_out` does
NOT enter the margin selection or the authority law in this WP (see
B.6).

### B.4 `fable_osi_runtime.m` + model

* mirror B.3 in the slow-hop phase (the `Wc` columns arrive via the new
  `fblow` parameter, marked Parameter-scope like `fblbins`);
* one new outport `b_out`; grow `Mux_5` by one and log it; update the
  save section of `main_ColumnSetup.m`;
* rerun `test_fable_runtime_equivalence` (desktop gains the same branch)
  — acceptance stays bitwise; then the TET check
  (`run_overloading_test`) — the branch is ~4 flops/bin per 0.25 s,
  negligible, but measure.

### B.5 Validation (offline first, in this folder)

1. Replay RTHS_02 (cleaned tap) with `outer_w`: healthy strong motion
   should read `b_out` ≈ 0.75–0.98 at the excited low bins (matches the
   numbers already measured in this study), NaN/model-blind at the
   unexcited 36–39 Hz binding band — document that limit.
2. Replay `RTHS_instability_at_the_end` (strong broadband excitation at
   the event): `b_out` must fall at/before the dm growth at ~87–93 s —
   the outer margin should move EARLIER than the inner one there, since
   the outer loop is the one going unstable.
3. Healthy open-loop records with `outer_w` set: `b_out` is
   meaningless there by construction (no numerical loop) — confirm the
   plan's operating rule: `fblow` is prepared **only for RTHS runs**
   (same selector logic as the echo tap; zero it otherwise).

### B.6 Usage policy (deliberate, staged)

* **Stage 1 (this WP): publish + alarm.** Log `b_out`; operator alarm
  threshold 0.30. No authority action. Collect shadow statistics on a
  few RTHS runs.
* **Stage 2 (future, after review):** the outer margin can join the
  authority law cleanly because the SAME α-grid machinery extends:
  `T_α = α·L̂/(1 + α·L̂)` with `L̂ = M/(1−M)` per bin (already computed
  for the inner prediction curve), so
  `L_out(α) = W·T_α` gives the predicted outer margin vs authority — the
  law could then regulate `min(b, b_out)` onto per-loop targets. Do not
  do this until Stage-1 data shows `b_out` is as quiet as the inner
  margin on healthy runs.
* **Stage 3 (optional accuracy upgrade):** replace the static k̂ in `W`
  with the measured interface impedance
  `K̂(ω) = S_{u,fm}/S_{u,dm}` (IV estimate — unbiased with the exogenous
  cleaned tap `u`): needs an `fm` inport on the OSI block, one more raw
  ring and one more 2048-pt FFT per slow hop (TET playbook applies).
  This removes the same static-spring idealization online that WP-A
  removes in vHS, and its low-frequency value doubles as a live
  stiffness-degradation readout alongside [[fable-stiffness]].

---

## Order of work

1. WP-A.1 (vHS impedance margins) — small, self-contained, immediately
   re-ranks the design margins; regression: `c=m=0` reproduces today.
2. WP-B.2–B.5 offline replay validation in this folder (can start now —
   desktop `fable_osi` + records; no target time needed).
3. WP-A.2 (authority propagation) once A.1 numbers are reviewed.
4. WP-B runtime + model wiring together with the echo-tap work of
   `fix_rths_echo_plan.md` (same Mux/save-section edit session, one
   equivalence + TET campaign for both).
5. Stage-2/3 decisions after shadow data.
