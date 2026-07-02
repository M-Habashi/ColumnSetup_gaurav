/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * fable_osi_types.h
 *
 * Code generation for function 'fable_osi'
 *
 */

#pragma once

/* Include files */
#include "rtwtypes.h"
#include "emlrt.h"

/* Type Definitions */
#ifndef typedef_struct2_T
#define typedef_struct2_T
typedef struct {
  real_T margin;
  boolean_T valid;
  real_T ncf_st;
  boolean_T st_valid;
  real_T f_st_hz;
  real_T n_excited;
  real_T ncf_res;
  real_T f_res_hz;
  real_T z_max;
  boolean_T res_on;
  real_T b_fast;
  boolean_T fast_trip;
  real_T trip_reason;
  boolean_T baseline_ready;
  real_T pred_margin[25];
  boolean_T pred_valid;
  real_T alpha_grid[25];
  real_T nominal;
  real_T nominal_hz;
  boolean_T detected;
  real_T detect_step;
  boolean_T st_binding;
  real_T z_fast;
  boolean_T regime_recal;
} struct2_T;
#endif /* typedef_struct2_T */

#ifndef typedef_struct1_T
#define typedef_struct1_T
typedef struct {
  real_T xdd[2048];
  real_T xdm[2048];
  real_T samples_in;
  real_T step_count;
  real_T hop_count;
  real_T Suu_seg[1683];
  real_T Syy_seg[1683];
  creal_T Suy_seg[1683];
  real_T seg_count;
  real_T ring_pos;
  real_T update_count;
  real_T cal_res[7920];
  real_T cal_med[80];
  real_T cal_pf[400];
  real_T cal_d[320];
  real_T cal_d_count;
  real_T cal_count;
  real_T cal_tries;
  real_T cal_rejects;
  boolean_T ready;
  real_T baseline[99];
  real_T baseline0[99];
  real_T mu0[99];
  real_T sigma0;
  real_T mu_pf[5];
  real_T mu_pf0[5];
  real_T sig_pf[5];
  real_T mu_d;
  real_T mu_d0;
  real_T sig_d;
  boolean_T res_on;
  real_T res_count;
  real_T res_age;
  real_T res_freq;
  boolean_T regime_mask[99];
  real_T regime_count;
  real_T sb_ndiff;
  boolean_T recal_pending;
  real_T slow_hist[3];
  boolean_T detected;
  real_T detect_step;
  real_T sb_b;
  real_T sb_st;
  real_T sb_res;
  real_T sb_fst;
  real_T sb_fres;
  real_T sb_zmax;
  boolean_T sb_stvalid;
  real_T sb_nexc;
  boolean_T sb_predvalid;
  real_T sb_pred[25];
  boolean_T sb_excited[99];
  boolean_T sb_quiet[99];
  boolean_T sb_qpmask[99];
  creal_T sb_Tsf[25];
  boolean_T sb_Tsf_valid[25];
  real_T b_slow_filt;
  real_T fSuu[75];
  real_T fSyy[75];
  creal_T fSuy[75];
  real_T fseg_count;
  real_T fring_pos;
  real_T p_in_ema;
  real_T cus_st;
  real_T cus_burst[5];
} struct1_T;
#endif /* typedef_struct1_T */

#ifndef struct_emxArray_real_T
#define struct_emxArray_real_T
struct emxArray_real_T {
  real_T *data;
  int32_T *size;
  int32_T allocatedSize;
  int32_T numDimensions;
  boolean_T canFreeData;
};
#endif /* struct_emxArray_real_T */
#ifndef typedef_emxArray_real_T
#define typedef_emxArray_real_T
typedef struct emxArray_real_T emxArray_real_T;
#endif /* typedef_emxArray_real_T */

#ifndef typedef_b_fable_osi_api
#define typedef_b_fable_osi_api
typedef struct {
  struct1_T varargin_4;
  struct1_T state;
} b_fable_osi_api;
#endif /* typedef_b_fable_osi_api */

#ifndef typedef_fable_osiStackData
#define typedef_fable_osiStackData
typedef struct {
  b_fable_osi_api f0;
} fable_osiStackData;
#endif /* typedef_fable_osiStackData */

/* End of code generation (fable_osi_types.h) */
