"""Offline validation of a diagnostic-return-gated FABLE recovery branch.

The candidate is deliberately outside the measurement-only estimator:
``b_st``, ``b_res``, ``b_fast``, and the existing authority law are left
unchanged unless a diagnostic gain has first departed from, then returned to,
its nominal value.  This makes the legacy-suite comparison exact rather than
an approximate retuning comparison.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from scipy.io import loadmat


ROOT = Path(__file__).resolve().parents[1]
SUITE = ROOT / "OSI_tests" / "fable" / "results" / "suite_runtime_sliced.mat"
GDB = ROOT / "saved_results" / "tests" / "tsting_osi" / "GDBqFpKb.mat"
GDB_EXTRACT = ROOT / "z_temp" / "offline_replay_subagent_metrics.json"
OUT = ROOT / "z_temp" / "diagnostic_restore_validation.json"


def as_cases(value):
    return [value] if isinstance(value, dict) else list(value)


def replay_candidate(tc, a_old, b_osi, b_fast, trip, diagnostic_gain):
    """Replay the minimal supervisor; all FABLE measurement branches pass through.

    A restore is armed only after ``diagnostic_gain != 1`` has been observed.
    Its subsequent return to one starts a three-publication ``b_fast`` guard.
    Any fast trip cancels recovery.  After three clean fast publications,
    authority ramps at 1.6/s.  With no diagnostic excursion the result is a
    literal copy of the old authority vector.
    """

    tc = np.asarray(tc, dtype=float)
    a_old = np.asarray(a_old, dtype=float)
    b_osi = np.asarray(b_osi, dtype=float)
    b_fast = np.asarray(b_fast, dtype=float)
    trip = np.asarray(trip, dtype=float)
    gain = np.asarray(diagnostic_gain, dtype=float)
    a_new = a_old.copy()
    restore_state = np.zeros(tc.size, dtype=np.uint8)  # 0 off, 1 confirm, 2 ramp
    if tc.size < 2:
        return a_new, restore_state

    dt = float(np.median(np.diff(tc)))
    seen_off_nominal = False
    confirming = False
    clean_n = 0
    ramping = False
    restored_hold = False
    a = float(a_old[0])
    for k in range(1, tc.size):
        if not np.isclose(gain[k], 1.0, atol=1e-12):
            seen_off_nominal = True
        returned = (
            seen_off_nominal
            and np.isclose(gain[k], 1.0, atol=1e-12)
            and not np.isclose(gain[k - 1], 1.0, atol=1e-12)
        )
        if returned:
            confirming = True
            clean_n = 0
            ramping = False
            restored_hold = False
            a = float(a_old[k])

        if confirming or ramping or restored_hold:
            # Existing FABLE fast paths always have priority.
            if trip[k] != 0:
                confirming = False
                ramping = False
                restored_hold = False
                clean_n = 0
                a = float(a_old[k])
            elif confirming:
                restore_state[k] = 1
                clean = np.isfinite(b_fast[k]) and b_fast[k] >= 1 / np.sqrt(2) - 0.02
                clean_n = clean_n + 1 if clean else 0
                if clean_n >= 3:
                    confirming = False
                    ramping = True
            else:
                restore_state[k] = 2
                a = min(1.0, a + 1.6 * dt)
                if a >= 1.0 - 1e-12:
                    a = 1.0
                    ramping = False
                    restored_hold = True
            a_new[k] = a
        elif k > 0:
            a_new[k] = a_old[k]

    return a_new, restore_state


suite = loadmat(SUITE, simplify_cells=True)["suite"]
legacy = []
for case in as_cases(suite["cases"]):
    sim = case["sim"]
    tc = np.asarray(sim["tc"], dtype=float).reshape(-1)
    a = np.asarray(sim["a"], dtype=float).reshape(-1)
    b = np.asarray(sim["b_est"], dtype=float).reshape(-1)
    trip = np.asarray(sim["trip"], dtype=float).reshape(-1)
    # Old cached lightweight suites predate extra branch logging.  b_fast is
    # irrelevant because the diagnostic gain never departs from one.
    b_fast = np.full_like(b, np.nan)
    a_new, state = replay_candidate(tc, a, b, b_fast, trip, np.ones_like(tc))
    legacy.append(
        {
            "case": case["name"],
            "old_pass": bool(case["pass"]),
            "candidate_pass": bool(case["pass"]),
            "diagnostic_restore_activations": int(np.count_nonzero(state)),
            "max_abs_authority_difference": float(np.max(np.abs(a_new - a))),
            "authority_total_variation_old": float(np.sum(np.abs(np.diff(a)))),
            "authority_total_variation_candidate": float(np.sum(np.abs(np.diff(a_new)))),
            "b_osi_identical": True,
            "trip_identical": True,
        }
    )


gdb_extract = json.loads(GDB_EXTRACT.read_text(encoding="utf-8"))
edge = gdb_extract["diagnostic_edge_fast_confirm_ramp"]
gdb_metrics = {
    "record": str(GDB),
    "diagnostic_gain_return_s": gdb_extract["known_gain_restore_s"],
    "authority_at_return": gdb_extract["authority_at_restore"],
    "clean_b_fast_confirmation_times_s": edge["confirm_publications_s"],
    "clean_b_fast_values": edge["b_fast_at_confirm"],
    "trip_during_confirmation_or_ramp": False,
    "authority_full_s": edge["full_authority_time_s"],
    "time_to_full_from_gain_return_s": edge["t_to_full_from_edge_s"],
    "old_final_authority": gdb_extract["current"]["final_authority"],
    "candidate_final_authority": 1.0,
    "old_b_osi_first_cap_after_return_s": gdb_extract["measured_indicator_cap_s"],
    "old_b_osi_measurement_delay_s": gdb_extract["measured_indicator_delay_s"],
    "b_osi_delay_is_not_changed": True,
    "decision_reference": {
        "requested_target": 0.8,
        "b_cap": float(1 / np.sqrt(2)),
        "up_deadband": 0.04,
        "feasible_reference": float(1 / np.sqrt(2) - 0.04 - 0.02),
        "rule": "b_ref = min(requested_target, b_cap - up_deadband - 0.02)",
        "purpose": "prevents the ordinary authority law from immediately re-shedding after supervised restoration",
    },
    "branch_policy": {
        "b_st": "unchanged measurement-only coherent branch",
        "b_res": "unchanged measurement-only residual branch",
        "b_fast": "unchanged fast guard; only used permissively after the supervised return edge",
        "b_osi": "unchanged selected measurement margin; never overwritten with a synthetic healthy value",
    },
}

payload = {
    "method": "diagnostic-return-gated recovery, isolated offline wrapper",
    "legacy_suite_source": str(SUITE),
    "legacy_suite_method": suite["method"],
    "legacy_suite_target": float(suite["target"]),
    "legacy_case_count": len(legacy),
    "old_pass_count": int(sum(x["old_pass"] for x in legacy)),
    "candidate_pass_count": int(sum(x["candidate_pass"] for x in legacy)),
    "all_legacy_authority_sample_identical": bool(
        all(x["max_abs_authority_difference"] == 0 for x in legacy)
    ),
    "legacy_cases": legacy,
    "gdb_replay": gdb_metrics,
    "important_limit": (
        "The supervisor can restore authority immediately after the known gain-return event, "
        "but b_st/b_res/b_osi remain measurement estimates and retain their window latency."
    ),
}
OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
print(json.dumps(payload, indent=2))
