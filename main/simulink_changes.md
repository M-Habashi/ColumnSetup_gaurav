# Simulink Changes

## Change 3 (2026-07-10): GPT-5.6 replaces FABLE on Speedgoat

The `Fable OSI + Auth` MATLAB Function block is now `GPT-5.6 OSI + Auth`
and calls `control_and_HS/OSI/gpt5_6_runtime.m`. Its seven compile-time
parameters come from `prepare_gpt5_6_runtime.m`. The existing scalar signal
inputs, nine diagnostic outputs, authority-gain connection, and File Log
width are unchanged. The logging mux is named `Mux_gpt5_6_runtime`.

GPT-5.6 is time-sliced over 32 base-rate ticks per 0.125 s update. The two
1024-point FFTs run on separate ticks, and each of the 25 quiet-band fit
candidates has its own tick. A two-window circular buffer preserves the
exact update-boundary snapshot while new 2048 Hz samples arrive. Offline
comparison against `gpt_osi` + `gpt_auth` was exact for `b_osi`, `b_st`, and
authority; `b_res` agreed to floating-point roundoff.

The OSI tap feedthrough gain now uses `gpt_dfm`, calculated by the new setup
from the numerical-substructure Newmark effective stiffness. The three
changed Simulink blocks (`GPT-5.6 OSI + Auth`, `Mux_gpt5_6_runtime`, and
`OSI tap D-term gain`) are yellow.

Target verification ran for 125 s with GPT-5.6 enabled. The 2048 Hz budget
was 488.28 us; measured TETMax was 78.50 us and TETAvg was 53.79 us. This
is 83.9% worst-case timing margin, with no overload or early stop.

## Change 2 (2026-07-03): Speedgoat overloading fix

Reproduced and fixed the CPU overload that stopped the target when the
pause switch was flipped to resume (`Overload limit (0) exceeded in
0.000488281s (tid=0)`, TETMax 780 us against the 488 us base-rate budget).
The overload fired ~5 s after resume, when the 5 s slow-spectral ring first
fills and the whole OSI slow pipeline (2048-pt FFTs, ring medians,
prediction grid) landed in a single base-rate tick.

Model + runtime changes:

1. **Time-sliced OSI runtime** (`control_and_HS/OSI/fable_osi_runtime.m`).
   Same arithmetic (bitwise-equal per `test_fable_runtime_equivalence` on
   the synthetic stream and all three saved records); the per-step work is
   now spread over one bounded phase per tick and published at a fixed
   56-tick (27 ms) latency after each 0.125 s step. The heaviest rare
   event, the calibration-finalize pooled-MAD median (nf x cal_windows
   sort), is split into 16 chunk sorts + 4 merge passes. Measured on
   target over the full 145 s verification protocol: TETMax 278 us (57%
   of budget; 275-278 across three runs), worst tick = the single 2048-pt
   slow FFT; the calibration finalize no longer peaks (was 780 us
   overload).
2. **OSI enable wiring**: the `Fable OSI + Auth` block's `en` input now
   comes straight from `osi_gain_enable_switch value`. The old
   `OSI Runtime Mode` Sum (deleted, along with `OSI Pause Code Gain` and
   `dd_pause_enable1`) computed `en = 2*dd_pause_enable -
   osi_gain_enable` (the enable was subtracted - a sign bug), and pausing
   dd also paused the indicator. **The indicator now always runs**; the
   pause switch only pauses the command signal.
3. **Online TSE Estimator** decimated: `update_samples` 64 -> 256 (8 Hz
   stiffness updates) and the first update offset to tick 128 of the
   256-sample OSI step, so the 4x4 SVD + 3x3 pinv never share a tick with
   an OSI pipeline phase. Estimates converge ~4x slower; accuracy per
   update unchanged.
4. **`OSI Margins Scope`** added next to the fable block, showing
   `b_st` (slow), `b_fast` (fast) and `b_osi` (selected). These are also
   logged in File-Log columns 13, 15, 12 as before.

Regression tooling: `OSI_tests/overloadin_test/run_overloading_test.m`
predicts target fit from a host benchmark (calibrated against the measured
780 us overload; pre-fix host measurement 793 us, k = 0.91) - run it before
any target run after changing `fable_osi_runtime.m`. Comparison report:
`OSI_tests/overloadin_test/report.html`.

## Change 1: OSI Authority Immediate-Drop Threshold

The OSI authority gain law now sets the severe/immediate-drop threshold as:

```matlab
down_immediate_margin = 0.25 * target_outer_ncf;
```

For the current target:

```matlab
target_outer_ncf = 0.3;
```

this gives:

```matlab
down_immediate_margin = 0.075;
```

This means normal below-target NCF values, such as `0.28`, are no longer treated as severe. They must persist for the configured confirmation count before the authority factor drops. Only very low NCF values trigger the immediate-drop path.

Clarification on where the authority factor is applied:

If the authority factor `a` is constant, multiplying the PID output by `a` is effectively the same linear loop as using a PID with gains `a*P`, `a*I`, and `a*D`.

They become different mainly when `a` changes while the test is running. Multiplying the PID output immediately scales everything the PID has already built up, including the integrator contribution. Scaling the PID gains changes how strongly the PID reacts from that point onward. So with adaptive authority, they can give different transients even if the steady linear effect is similar.
