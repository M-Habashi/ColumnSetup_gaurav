/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * movmax.c
 *
 * Code generation for function 'movmax'
 *
 */

/* Include files */
#include "movmax.h"
#include "SortedBuffer.h"
#include "fable_osi_data.h"
#include "fable_osi_internal_types.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"

/* Variable Definitions */
static emlrtRSInfo pc_emlrtRSI = {
    14,       /* lineNo */
    "movmax", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\movmax.m" /* pathName
                                                                           */
};

static emlrtRSInfo rc_emlrtRSI = {
    161,        /* lineNo */
    "dispatch", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\private\\movfun"
    "Dispatch.m" /* pathName */
};

/* Function Definitions */
void b_movmax(const emlrtStack *sp, const real_T x[25], real_T y[25])
{
  b_coder_internal_SortedBuffer s;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack h_st;
  emlrtStack i_st;
  emlrtStack st;
  int32_T k;
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
  f_st.prev = &e_st;
  f_st.tls = e_st.tls;
  g_st.prev = &f_st;
  g_st.tls = f_st.tls;
  h_st.prev = &g_st;
  h_st.tls = g_st.tls;
  i_st.prev = &h_st;
  i_st.tls = h_st.tls;
  st.site = &pc_emlrtRSI;
  b_st.site = &qc_emlrtRSI;
  c_st.site = &rc_emlrtRSI;
  d_st.site = &sc_emlrtRSI;
  e_st.site = &tc_emlrtRSI;
  f_st.site = &uc_emlrtRSI;
  g_st.site = &gc_emlrtRSI;
  h_st.site = &vc_emlrtRSI;
  s.buf[0] = 0.0;
  s.buf[1] = 0.0;
  s.buf[2] = 0.0;
  s.nbuf = 0;
  i_st.site = &wc_emlrtRSI;
  b_SortedBuffer_insert(&i_st, &s, x[0]);
  i_st.site = &wc_emlrtRSI;
  b_SortedBuffer_insert(&i_st, &s, x[1]);
  if (s.nbuf == 0) {
    y[0] = rtNaN;
  } else {
    y[0] = s.buf[s.nbuf - 1];
  }
  i_st.site = &xc_emlrtRSI;
  b_SortedBuffer_insert(&i_st, &s, x[2]);
  if (s.nbuf == 0) {
    y[1] = rtNaN;
  } else {
    y[1] = s.buf[s.nbuf - 1];
  }
  for (k = 0; k < 22; k++) {
    i_st.site = &yc_emlrtRSI;
    SortedBuffer_replace(&i_st, &s, x[k], x[k + 3]);
    if (s.nbuf == 0) {
      y[k + 2] = rtNaN;
    } else {
      y[k + 2] = s.buf[s.nbuf - 1];
    }
  }
  i_st.site = &ad_emlrtRSI;
  b_SortedBuffer_remove(&i_st, &s, x[22]);
  if (s.nbuf == 0) {
    y[24] = rtNaN;
  } else {
    y[24] = s.buf[s.nbuf - 1];
  }
}

void movmax(const emlrtStack *sp, const real_T x[99], real_T y[99])
{
  coder_internal_SortedBuffer s;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack h_st;
  emlrtStack i_st;
  emlrtStack j_st;
  emlrtStack st;
  int32_T i;
  int32_T k;
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
  f_st.prev = &e_st;
  f_st.tls = e_st.tls;
  g_st.prev = &f_st;
  g_st.tls = f_st.tls;
  h_st.prev = &g_st;
  h_st.tls = g_st.tls;
  i_st.prev = &h_st;
  i_st.tls = h_st.tls;
  j_st.prev = &i_st;
  j_st.tls = i_st.tls;
  st.site = &pc_emlrtRSI;
  b_st.site = &qc_emlrtRSI;
  c_st.site = &rc_emlrtRSI;
  d_st.site = &sc_emlrtRSI;
  e_st.site = &tc_emlrtRSI;
  f_st.site = &uc_emlrtRSI;
  g_st.site = &gc_emlrtRSI;
  h_st.site = &vc_emlrtRSI;
  for (i = 0; i < 7; i++) {
    s.buf[i] = 0.0;
  }
  s.nbuf = 0;
  i_st.site = &wc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[0]);
  i_st.site = &wc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[1]);
  i_st.site = &wc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[2]);
  i_st.site = &wc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[3]);
  if (s.nbuf == 0) {
    y[0] = rtNaN;
  } else {
    y[0] = s.buf[s.nbuf - 1];
  }
  i_st.site = &xc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[4]);
  if (s.nbuf == 0) {
    y[1] = rtNaN;
  } else {
    y[1] = s.buf[s.nbuf - 1];
  }
  i_st.site = &xc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[5]);
  if (s.nbuf == 0) {
    y[2] = rtNaN;
  } else {
    y[2] = s.buf[s.nbuf - 1];
  }
  i_st.site = &xc_emlrtRSI;
  SortedBuffer_insert(&i_st, &s, x[6]);
  if (s.nbuf == 0) {
    y[3] = rtNaN;
  } else {
    y[3] = s.buf[s.nbuf - 1];
  }
  for (k = 0; k < 92; k++) {
    real_T d;
    i_st.site = &yc_emlrtRSI;
    d = x[k];
    if (muDoubleScalarIsNaN(d)) {
      j_st.site = &fd_emlrtRSI;
      SortedBuffer_insert(&j_st, &s, x[k + 7]);
    } else {
      real_T d1;
      d1 = x[k + 7];
      if (muDoubleScalarIsNaN(d1)) {
        j_st.site = &ed_emlrtRSI;
        SortedBuffer_remove(&j_st, &s, d);
      } else {
        int32_T iold;
        iold = SortedBuffer_locateElement(s.buf, s.nbuf, d);
        if ((iold > 0) && (s.buf[iold - 1] == d)) {
          int32_T inew;
          inew = SortedBuffer_locateElement(s.buf, s.nbuf, d1);
          if (iold <= inew) {
            for (i = iold; i < inew; i++) {
              s.buf[i - 1] = s.buf[i];
            }
            s.buf[inew - 1] = d1;
          } else if (iold == inew + 1) {
            s.buf[iold - 1] = d1;
          } else {
            int32_T b_i;
            b_i = inew + 2;
            for (i = iold; i >= b_i; i--) {
              s.buf[i - 1] = s.buf[i - 2];
            }
            s.buf[inew] = d1;
          }
        } else {
          j_st.site = &cd_emlrtRSI;
          SortedBuffer_insert(&j_st, &s, d1);
        }
      }
    }
    if (s.nbuf == 0) {
      y[k + 4] = rtNaN;
    } else {
      y[k + 4] = s.buf[s.nbuf - 1];
    }
  }
  i_st.site = &ad_emlrtRSI;
  SortedBuffer_remove(&i_st, &s, x[92]);
  if (s.nbuf == 0) {
    y[96] = rtNaN;
  } else {
    y[96] = s.buf[s.nbuf - 1];
  }
  i_st.site = &ad_emlrtRSI;
  SortedBuffer_remove(&i_st, &s, x[93]);
  if (s.nbuf == 0) {
    y[97] = rtNaN;
  } else {
    y[97] = s.buf[s.nbuf - 1];
  }
  i_st.site = &ad_emlrtRSI;
  SortedBuffer_remove(&i_st, &s, x[94]);
  if (s.nbuf == 0) {
    y[98] = rtNaN;
  } else {
    y[98] = s.buf[s.nbuf - 1];
  }
}

/* End of code generation (movmax.c) */
