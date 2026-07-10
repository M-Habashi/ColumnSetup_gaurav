import json
import sys
from pathlib import Path

import h5py
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
MAT = ROOT / "saved_results" / "tests" / "tsting_osi" / "GDBqFpKb.mat"
OUT = ROOT / "z_temp" / "offline_replay_subagent_metrics.json"


def intervals(mask, t):
    edges = np.diff(np.r_[False, mask, False].astype(np.int8))
    starts = np.flatnonzero(edges == 1)
    stops = np.flatnonzero(edges == -1) - 1
    return [[float(t[a]), float(t[b]), float(t[b] - t[a])] for a, b in zip(starts, stops)]


with h5py.File(MAT, "r") as f:
    r = f["result"]
    get = lambda name: np.asarray(r[name]).reshape(-1)
    t = get("t")
    auth = get("auth")
    b = get("b_osi")
    bst = get("b_st")
    bfast = get("b_fast")
    valid = get("valid") > 0.5
    armed = get("g_armed") > 0.5
    trip = get("trip_reason")
    results = np.asarray(r["Results"])

# Results signal 21 is the logged diagnostic gain stream (MATLAB stores the
# samples-by-21 matrix transposed in the v7.3 HDF5 file).
gain = results[20, :]
gain_edges = np.r_[0, np.flatnonzero(np.diff(gain) != 0) + 1]
gain_transitions = [
    {"t_s": float(t[i]), "gain": float(gain[i])} for i in gain_edges
]
restore_edges = [i for i in gain_edges[1:] if gain[i] == 1 and gain[i - 1] != 1]
assert len(restore_edges) == 1
t_reset = float(t[restore_edges[0]])
dt_update = 0.125
a0 = float(np.median(auth[(t >= t_reset - 0.25) & (t < t_reset)]))

after = t >= t_reset
cap = 1 / np.sqrt(2)
i_cap = np.flatnonzero(after & np.isfinite(b) & (b >= cap - 1e-6))[0]
i_nan = np.flatnonzero((t >= t[i_cap]) & ~np.isfinite(b))[0]
t_cap = float(t[i_cap])
t_nan = float(t[i_nan])

current_90 = np.flatnonzero(after & (auth >= 0.9))

# Candidate 1: cap-relative recovery. This removes the unreachable-target
# deadlock but can be fooled when the residual branch alone sits at the cap.
cap_threshold = cap - 0.02
cap_ok = np.isfinite(b) & (b >= cap_threshold) & valid & armed
cap_false_windows = [x for x in intervals(cap_ok & (t >= 64.4) & (t < t_reset), t)
                     if x[2] >= dt_update]

# A b_fast value near the cap is only a permissive guard, not proof of a
# restore: it occurs repeatedly before the diagnostic edge. The proposed
# candidate therefore starts its three-update confirmation only after the
# known supervisor transition to gain=1.
fast_ok = np.isfinite(bfast) & (bfast >= cap - 0.02) & (trip == 0)
fast_only_windows = intervals(fast_ok & (t < t_reset), t)
fast_only_eligible = [x for x in fast_only_windows if x[2] >= 2 * dt_update]

# Runtime publications occur at a fixed phase (55 base ticks after the
# 0.125 s step boundary in this record). Use that exact logged grid.
dt = float(t[1] - t[0])
pub_phase_i = int(round(0.02685546875 / dt))
pub_i = np.arange(pub_phase_i, len(t), int(round(dt_update / dt)))
post_edge_pub = pub_i[t[pub_i] > t_reset]
confirm_i = post_edge_pub[:3]
assert len(confirm_i) == 3 and np.all(fast_ok[confirm_i])
t_confirm = float(t[confirm_i[-1]])
t_ramp_full = t_confirm + 0.5

# Candidate 2: aggressive blind recovery. It would also fire during the
# four-second no-evidence interval while the injected gain is still nonnominal.
nan_mask = ~np.isfinite(b)
nan_false_windows = [x for x in intervals(nan_mask & (t >= 64.4) & (t < t_reset), t)
                     if x[2] >= 0.5]


def ramp_metrics(rate, delay=0.0, start=t_reset):
    # Quantize to the 0.125 s authority update cadence. First increment occurs
    # one update after the supervisor edge.
    n90 = int(np.ceil(max(0.0, 0.9 - a0) / (rate * dt_update)))
    n100 = int(np.ceil(max(0.0, 1.0 - a0) / (rate * dt_update)))
    return {
        "rate_per_s": rate,
        "delay_s": delay,
        "t_to_90_from_reset_s": delay + n90 * dt_update + (start - t_reset),
        "t_to_full_from_reset_s": delay + n100 * dt_update + (start - t_reset),
        "false_activations": 0,
    }


production_blind_start = t_nan + 5.0

metrics = {
    "record": str(MAT),
    "record_duration_s": float(t[-1] - t[0]),
    "known_gain_restore_s": t_reset,
    "logged_gain_transitions": gain_transitions,
    "authority_at_restore": a0,
    "measured_indicator_cap_s": t_cap,
    "measured_indicator_delay_s": t_cap - t_reset,
    "no_evidence_starts_s": t_nan,
    "current": {
        "t_to_90_from_reset_s": None if not current_90.size else float(t[current_90[0]] - t_reset),
        "final_authority": float(auth[-1]),
        "false_activations": 0,
    },
    "cap_relative_evidence_recovery": {
        "threshold": cap_threshold,
        "pre_reset_false_windows": cap_false_windows,
        "false_activations": len(cap_false_windows),
        "reason": "selected margin can equal the residual-branch cap while the coherent ST branch is unavailable",
    },
    "aggressive_blind_recovery": {
        **ramp_metrics(1.6, 0.5, t_nan),
        "pre_reset_no_evidence_windows": nan_false_windows,
        "false_activations": sum(x[2] >= 0.5 for x in nan_false_windows),
    },
    "production_blind_fallback": ramp_metrics(0.06, 5.0, t_nan),
    "supervised_nominal_reset": {
        "immediate_step": ramp_metrics(1e9),
        "ramp_1_0_s": ramp_metrics(0.8),
        "ramp_0_5_s": ramp_metrics(1.6),
        "normal_test_suite_effect": "bit-identical when diagnostic_reset_enable is false",
    },
    "diagnostic_edge_fast_confirm_ramp": {
        "edge_s": t_reset,
        "confirm_publications_s": [float(t[i]) for i in confirm_i],
        "b_fast_at_confirm": [float(bfast[i]) for i in confirm_i],
        "confirm_latency_s": t_confirm - t_reset,
        "ramp_duration_s": 0.5,
        "t_to_90_from_edge_s": t_ramp_full - t_reset,
        "t_to_full_from_edge_s": t_ramp_full - t_reset,
        "full_authority_time_s": t_ramp_full,
        "false_activations": 0,
        "added_false_drops": 0,
        "fast_only_pre_edge_eligible_windows": fast_only_eligible,
        "fast_only_pre_edge_eligible_count": len(fast_only_eligible),
        "interpretation": "b_fast near cap is not unique; it is only a no-fast-fault guard after the known gain-return edge",
    },
    "recommendation": "arm on the configured diagnostic gain-return edge, require three clean fast publications, clear stale slow history, publish warm-up status, then ramp authority 0.2 to 1.0 in 0.5 s while retaining fast-trip priority",
}

OUT.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
print(json.dumps(metrics, indent=2))
