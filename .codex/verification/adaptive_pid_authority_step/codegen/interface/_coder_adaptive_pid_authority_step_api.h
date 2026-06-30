/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_adaptive_pid_authority_step_api.h
 *
 * Code generation for function 'adaptive_pid_authority_step'
 *
 */

#ifndef _CODER_ADAPTIVE_PID_AUTHORITY_STEP_API_H
#define _CODER_ADAPTIVE_PID_AUTHORITY_STEP_API_H

/* Include files */
#include "emlrt.h"
#include "mex.h"
#include "tmwtypes.h"
#include <string.h>

/* Variable Declarations */
extern emlrtCTX emlrtRootTLSGlobal;
extern emlrtContext emlrtContextGlobal;

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void adaptive_pid_authority_step(
    real_T m91_margin, real_T authority, real_T margin_filtered,
    real_T margin_guarded, real_T above_count, real_T below_count,
    real_T target_margin, real_T update_interval_s, real_T a_min, real_T a_max,
    real_T down_deadband, real_T down_rate, real_T down_immediate_margin,
    real_T down_confirm_n, real_T up_deadband, real_T power_law,
    real_T smooth_down, real_T up_rate, real_T up_hold_s,
    real_T margin_guard_up_rate, real_T margin_guard_down_rate,
    real_T margin_filter_alpha, real_T *authority_next,
    real_T *margin_filtered_next, real_T *margin_guarded_next,
    real_T *above_count_next, real_T *below_count_next, real_T *down_confirmed);

void adaptive_pid_authority_step_api(const mxArray *const prhs[22],
                                     int32_T nlhs, const mxArray *plhs[6]);

void adaptive_pid_authority_step_atexit(void);

void adaptive_pid_authority_step_initialize(void);

void adaptive_pid_authority_step_terminate(void);

void adaptive_pid_authority_step_xil_shutdown(void);

void adaptive_pid_authority_step_xil_terminate(void);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (_coder_adaptive_pid_authority_step_api.h) */
