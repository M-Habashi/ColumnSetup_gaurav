# M7_defense — Method 7 and its programmatic proof

A **self-contained** package that (a) holds the Method 7 implementation and its
write-up, and (b) **proves the theory behind it with runnable scripts** on the
real data. Every claim I made about Method 7 is checked with an assertion that
prints `PASS`/`FAIL` and saves an evidence figure.

> Method 7 = output-only **closed-loop resonance / sensitivity-peak** NCF margin.
> It catches the 35 Hz instability from the response `dm` **alone**, so it works
> even under a low-frequency input where the open-loop FRF `dm/dc` is blind.
> Full rationale and implementation guide: **`M7.md`**.

## How to run

From MATLAB (R2025b; needs Signal Processing + Control System toolboxes):

```matlab
cd main/research/OSI/claude_trial/M7_defense
run run_all_proofs.m        % runs all 5 proofs, prints a PASS/FAIL summary
```

Each proof can also be run on its own (e.g. `run proof1_lock_tautology.m`).
Figures are written to `./figs`. The scripts locate the repo, the `exp_tf`
model, and the two test records by themselves — no other setup needed.

## Files

| File | What it is |
|---|---|
| `M7.md` | The method: conclusions, why it is proposed, and a full implementation guide. |
| `m7_resonance.m` | **Standalone** Method 7 — input is `dm` only; self-contained (defaults inside). |
| `osi_method7_resonance.m` | The same method as integrated in the main pipeline (uses `ctx`/`cfg`). For reference. |
| `m7d_setup.m` | Loads a test record (`'A'`=1731 broadband, `'B'`=1749 low-freq) + the nominal model. |
| `proof1_lock_tautology.m` | Proves the closed-loop **lock**: `dc=−C·dm`, coherence≈1, `|dm/dc|` pinned at `1/|C|`. |
| `proof2_resonance_grows.m` | Proves the 35 Hz resonance **grows in `dm`** toward instability (both files). |
| `proof3_spk_tracks_margin.m` | Proves `Spk ≈ ‖S‖∞` and that the resonance margin **tracks the FRF margin** (1731). |
| `proof4_frf_is_blind.m` | Proves the **FRF margin is blind** on 1749 while Method 7 separates stable vs event. |
| `proof5_method7_detects.m` | Proves Method 7 **detects on both files** with no healthy-phase false alarm. |
| `run_all_proofs.m` | Runs all proofs (isolated) and prints the overall PASS/FAIL. |
| `figs/` | Evidence figures (one per proof). |

## What the proofs establish (last run: **ALL PASS**)

1. **The lock / tautology (`proof1`).** On 1749, `coherence(dc,dm)@35Hz = 1.000`,
   `−dc/dm = C` to **0.3 %**, and `|dm/dc| = 3.103 = 1/|C|` — pinned, *not* the
   true plant `|H0(35)| = 0.505`. On 1731 (broadband) the lock is broken
   (coherence 0.84, `|dm/dc|` varies). → `dc` and `dm` ring together when the
   input has no 35 Hz; the ratio carries no margin information.
2. **The resonance is observable (`proof2`).** The `dm` amplitude at 35 Hz grows
   ×15 (1731) and ×60 (1749) from the healthy phase to the event.
3. **`Spk` is the margin (`proof3`).** On 1731, `log Spk` correlates with
   `log‖S‖∞` (from the valid FRF), and the resonance margin and the FRF margin
   detect within ~12 s of each other.
4. **FRF is blind, Method 7 is not (`proof4`).** On 1749 the FRF loop-only NCF
   over 25–45 Hz stays at ~0.001 (cannot tell healthy from unstable); Method 7
   goes 0.55 → 0.05.
5. **Detection (`proof5`).** Method 7 detects on 1749 (219 s) and 1731 (717 s,
   matching the FRF methods’ 728 s), with no false alarm in the healthy phase.

## The one-paragraph argument

When `dd` has no energy at the binding frequency, the controller law
`dc = C·(dd − dm)` collapses to `dc ≈ −C·dm` there, so `dc` and `dm` are *locked*
(coherence = 1) and their ratio `dm/dc` is pinned at `1/|C|` no matter how close
to instability the loop is — the open-loop FRF, and any margin built from it, is
**uninformative** at that frequency. But the closed-loop **resonance amplitude**
in `dm` grows as the margin shrinks (it equals the peak sensitivity
`‖S‖∞ = 1/min|1+L|`). Method 7 reads exactly that — `Spk = √(peak/floor PSD of
dm)` — and maps it to the loop-only NCF, calibrated to the model’s nominal margin
at the start: `b(t) = b_nom · Spk_ref / Spk(t)`. The proofs above confirm each
link in this chain on the actual data.
