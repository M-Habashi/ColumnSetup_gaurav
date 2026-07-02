/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * mean.c
 *
 * Code generation for function 'mean'
 *
 */

/* Include files */
#include "mean.h"
#include "fable_osi_data.h"
#include "rt_nonfinite.h"
#include "sumMatrixIncludeNaN.h"

/* Variable Definitions */
static emlrtRSInfo mf_emlrtRSI = {
    112,    /* lineNo */
    "mean", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\mean.m" /* pathName
                                                                         */
};

/* Function Definitions */
creal_T mean(const emlrtStack *sp, const creal_T x_data[], int32_T x_size)
{
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack st;
  creal_T y;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  e_st.prev = &d_st;
  e_st.tls = d_st.tls;
  st.site = &mf_emlrtRSI;
  b_st.site = &rd_emlrtRSI;
  if (x_size == 0) {
    y.re = 0.0;
    y.im = 0.0;
  } else {
    c_st.site = &sd_emlrtRSI;
    d_st.site = &td_emlrtRSI;
    e_st.site = &ud_emlrtRSI;
    y = b_sumColumnB(&e_st, x_data, x_size);
  }
  if (y.im == 0.0) {
    y.re /= (real_T)x_size;
    y.im = 0.0;
  } else if (y.re == 0.0) {
    y.re = 0.0;
    y.im /= (real_T)x_size;
  } else {
    y.re /= (real_T)x_size;
    y.im /= (real_T)x_size;
  }
  return y;
}

/* End of code generation (mean.c) */
