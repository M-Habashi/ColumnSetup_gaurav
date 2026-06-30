/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * adaptive_pid_authority_step.h
 *
 * Code generation for function 'adaptive_pid_authority_step'
 *
 */

#ifndef ADAPTIVE_PID_AUTHORITY_STEP_H
#define ADAPTIVE_PID_AUTHORITY_STEP_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
extern void adaptive_pid_authority_step(
    double m91_margin, double authority, double margin_filtered,
    double margin_guarded, double above_count, double below_count,
    double target_margin, double update_interval_s, double a_min, double a_max,
    double down_deadband, double down_rate, double down_immediate_margin,
    double down_confirm_n, double up_deadband, double power_law,
    double smooth_down, double up_rate, double up_hold_s,
    double margin_guard_up_rate, double margin_guard_down_rate,
    double margin_filter_alpha, double *authority_next,
    double *margin_filtered_next, double *margin_guarded_next,
    double *above_count_next, double *below_count_next, double *down_confirmed);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (adaptive_pid_authority_step.h) */
