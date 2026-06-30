/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * auth_stability_gain.c
 *
 * Code generation for function 'auth_stability_gain'
 *
 */

/* Include files */
#include "auth_stability_gain.h"
#include "mpower.h"
#include "rt_nonfinite.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Function Definitions */
void auth_stability_gain(
    double m91_margin, double authority, double margin_filtered,
    double margin_guarded, double above_count, double below_count,
    double target_margin, double update_interval_s, double a_min, double a_max,
    double down_deadband, double down_rate, double down_immediate_margin,
    double down_confirm_n, double up_deadband, double power_law,
    double smooth_down, double up_rate, double up_hold_s,
    double margin_guard_up_rate, double margin_guard_down_rate,
    double margin_filter_alpha, double *authority_next,
    double *margin_filtered_next, double *margin_guarded_next,
    double *above_count_next, double *below_count_next, double *down_confirmed)
{
  /* AUTH_STABILITY_GAIN Codegen-safe adaptive PID stability-gain update. */
  /*  Use this from a Simulink MATLAB Function block after M9.1 produces one */
  /*  margin sample. Feed the state outputs back through Unit Delay blocks. */
  /*  */
  /*  Inputs and outputs are scalar doubles for Simulink Real-Time/Speedgoat */
  /*  code generation. No structs, variable-size arrays, persistent state, or */
  /*  dynamic MATLAB features are used. */
  /*  */
  /*  State values: */
  /*    margin_filtered initial value: target_margin */
  /*    margin_guarded  initial value: target_margin */
  /*    above_count     initial value: 0 */
  /*    below_count     initial value: 0 */
  /*  */
  /*  The raw M9.1 margin is not modified. The guarded margin is an internal */
  /*  decision signal used to slow recovery and reject one-window moderate dips.
   */
  *authority_next = authority;
  *margin_filtered_next = margin_filtered;
  *margin_guarded_next = margin_guarded;
  *above_count_next = above_count;
  *below_count_next = below_count;
  *down_confirmed = 0.0;
  if ((!rtIsInf(m91_margin)) && (!rtIsNaN(m91_margin))) {
    boolean_T b;
    boolean_T is_low;
    boolean_T severe_low;
    *margin_filtered_next = (1.0 - margin_filter_alpha) * margin_filtered +
                            margin_filter_alpha * m91_margin;
    is_low = (m91_margin < target_margin - down_deadband);
    if (is_low) {
      *below_count_next = below_count + 1.0;
    } else {
      *below_count_next = 0.0;
    }
    if (is_low && (m91_margin <= down_immediate_margin)) {
      severe_low = true;
    } else {
      severe_low = false;
    }
    if (is_low && (severe_low || (*below_count_next >= down_confirm_n))) {
      b = true;
    } else {
      b = false;
    }
    *down_confirmed = b;
    if (severe_low && (m91_margin < margin_guarded)) {
      *margin_guarded_next = m91_margin;
    } else if (m91_margin >= margin_guarded) {
      *margin_guarded_next =
          fmin(m91_margin, margin_guarded + margin_guard_up_rate);
    } else if (b || (m91_margin >= target_margin)) {
      *margin_guarded_next =
          fmax(m91_margin, margin_guarded - margin_guard_down_rate);
    }
    if (b) {
      *authority_next = fmax(
          (1.0 - smooth_down) * authority +
              smooth_down *
                  fmax(a_min,
                       fmin(a_max, authority * mpower(fmax(m91_margin, 0.05) /
                                                          target_margin,
                                                      power_law))),
          authority - down_rate);
      *above_count_next = 0.0;
    } else if (is_low) {
      *above_count_next = 0.0;
    } else if (*margin_guarded_next > target_margin + up_deadband) {
      double x;
      *above_count_next = above_count + 1.0;
      x = up_hold_s / update_interval_s;
      if (fabs(x) < 4.503599627370496E+15) {
        if (x >= 0.5) {
          x = floor(x + 0.5);
        } else if (x > -0.5) {
          x *= 0.0;
        } else {
          x = ceil(x - 0.5);
        }
      }
      if (above_count + 1.0 >= fmax(1.0, x)) {
        *authority_next = fmin(a_max, authority + up_rate);
      }
    } else {
      *above_count_next = 0.0;
    }
    *authority_next = fmax(a_min, fmin(a_max, *authority_next));
  }
}

/* End of code generation (auth_stability_gain.c) */
