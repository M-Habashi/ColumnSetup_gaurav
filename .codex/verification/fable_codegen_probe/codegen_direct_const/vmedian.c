/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * vmedian.c
 *
 * Code generation for function 'vmedian'
 *
 */

/* Include files */
#include "vmedian.h"
#include "eml_int_forloop_overflow_check.h"
#include "fable_osi_data.h"
#include "fable_osi_emxutil.h"
#include "fable_osi_types.h"
#include "quickselect.h"
#include "rt_nonfinite.h"
#include "sort3.h"
#include "mwmathutil.h"

/* Variable Definitions */
static emlrtRTEInfo q_emlrtRTEI = {
    119,       /* lineNo */
    15,        /* colNo */
    "vmedian", /* fName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\private\\vmedia"
    "n.m" /* pName */
};

static emlrtRTEInfo s_emlrtRTEI = {
    113,       /* lineNo */
    17,        /* colNo */
    "vmedian", /* fName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\private\\vmedia"
    "n.m" /* pName */
};

static emlrtRTEInfo t_emlrtRTEI = {
    1,         /* lineNo */
    29,        /* colNo */
    "vmedian", /* fName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\private\\vmedia"
    "n.m" /* pName */
};

/* Function Definitions */
real_T vmedian(const emlrtStack *sp, emxArray_real_T *v, int32_T n)
{
  emlrtStack b_st;
  emlrtStack st;
  emxArray_real_T *a__4;
  real_T m;
  real_T *a__4_data;
  real_T *v_data;
  int32_T i;
  int32_T j2;
  int32_T j3;
  int32_T k;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  v_data = v->data;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtConstCTX)sp);
  st.site = &kd_emlrtRSI;
  if (n > 2147483646) {
    b_st.site = &n_emlrtRSI;
    check_forloop_overflow_error(&b_st);
  }
  k = 0;
  emxInit_real_T(sp, &a__4, 1, &t_emlrtRTEI);
  int32_T exitg1;
  do {
    exitg1 = 0;
    if (k <= n - 1) {
      if (muDoubleScalarIsNaN(v_data[k])) {
        m = rtNaN;
        exitg1 = 1;
      } else {
        k++;
      }
    } else {
      if (n <= 4) {
        if (n == 0) {
          m = rtNaN;
        } else if (n == 1) {
          m = v_data[0];
        } else if (n == 2) {
          if (((v_data[0] < 0.0) != (v_data[1] < 0.0)) ||
              muDoubleScalarIsInf(v_data[0])) {
            m = (v_data[0] + v_data[1]) / 2.0;
          } else {
            m = v_data[0] + (v_data[1] - v_data[0]) / 2.0;
          }
        } else if (n == 3) {
          sort3(v_data[0], v_data[1], v_data[2], &k);
          m = v_data[k - 1];
        } else {
          if (v_data[0] < v_data[1]) {
            if (v_data[1] < v_data[2]) {
              k = 0;
              j2 = 1;
              j3 = 2;
            } else if (v_data[0] < v_data[2]) {
              k = 0;
              j2 = 2;
              j3 = 1;
            } else {
              k = 2;
              j2 = 0;
              j3 = 1;
            }
          } else if (v_data[0] < v_data[2]) {
            k = 1;
            j2 = 0;
            j3 = 2;
          } else if (v_data[1] < v_data[2]) {
            k = 1;
            j2 = 2;
            j3 = 0;
          } else {
            k = 2;
            j2 = 1;
            j3 = 0;
          }
          if (v_data[k] < v_data[3]) {
            if (v_data[3] < v_data[j3]) {
              if (((v_data[j2] < 0.0) != (v_data[3] < 0.0)) ||
                  muDoubleScalarIsInf(v_data[j2])) {
                m = (v_data[j2] + v_data[3]) / 2.0;
              } else {
                m = v_data[j2] + (v_data[3] - v_data[j2]) / 2.0;
              }
            } else if (((v_data[j2] < 0.0) != (v_data[j3] < 0.0)) ||
                       muDoubleScalarIsInf(v_data[j2])) {
              m = (v_data[j2] + v_data[j3]) / 2.0;
            } else {
              m = v_data[j2] + (v_data[j3] - v_data[j2]) / 2.0;
            }
          } else if (((v_data[k] < 0.0) != (v_data[j2] < 0.0)) ||
                     muDoubleScalarIsInf(v_data[k])) {
            m = (v_data[k] + v_data[j2]) / 2.0;
          } else {
            m = v_data[k] + (v_data[j2] - v_data[k]) / 2.0;
          }
        }
      } else {
        int32_T midm1;
        midm1 = n >> 1;
        if (((uint32_T)n & 1U) == 0U) {
          st.site = &id_emlrtRSI;
          m = quickselect(v, midm1 + 1, n, &k, &j3);
          v_data = v->data;
          if (midm1 < k) {
            real_T b;
            j2 = v->size[0];
            k = a__4->size[0];
            a__4->size[0] = j2;
            emxEnsureCapacity_real_T(sp, a__4, k, &s_emlrtRTEI);
            a__4_data = a__4->data;
            for (i = 0; i < j2; i++) {
              a__4_data[i] = v_data[i];
            }
            st.site = &jd_emlrtRSI;
            b = quickselect(a__4, midm1, j3 - 1, &k, &j2);
            if (((m < 0.0) != (b < 0.0)) || muDoubleScalarIsInf(m)) {
              m = (m + b) / 2.0;
            } else {
              m += (b - m) / 2.0;
            }
          }
        } else {
          j2 = v->size[0];
          k = a__4->size[0];
          a__4->size[0] = j2;
          emxEnsureCapacity_real_T(sp, a__4, k, &q_emlrtRTEI);
          a__4_data = a__4->data;
          for (i = 0; i < j2; i++) {
            a__4_data[i] = v_data[i];
          }
          st.site = &ic_emlrtRSI;
          m = quickselect(a__4, midm1 + 1, n, &k, &j2);
        }
      }
      exitg1 = 1;
    }
  } while (exitg1 == 0);
  emxFree_real_T(sp, &a__4);
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtConstCTX)sp);
  return m;
}

/* End of code generation (vmedian.c) */
