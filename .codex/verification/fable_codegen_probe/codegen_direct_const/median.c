/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * median.c
 *
 * Code generation for function 'median'
 *
 */

/* Include files */
#include "median.h"
#include "eml_int_forloop_overflow_check.h"
#include "fable_osi_data.h"
#include "fable_osi_emxutil.h"
#include "fable_osi_types.h"
#include "quickselect.h"
#include "rt_nonfinite.h"
#include "sort3.h"
#include "vmedian.h"
#include "mwmathutil.h"
#include <string.h>

/* Variable Definitions */
static emlrtRSInfo dc_emlrtRSI = {
    167,      /* lineNo */
    "median", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\median.m" /* pathName
                                                                           */
};

static emlrtRSInfo ec_emlrtRSI = {
    72,                    /* lineNo */
    "applyVectorFunction", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
    "internal\\applyVectorFunction.m" /* pathName */
};

static emlrtRSInfo fc_emlrtRSI = {
    159,        /* lineNo */
    "looper1D", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
    "internal\\applyVectorFunction.m" /* pathName */
};

static emlrtRSInfo hc_emlrtRSI = {
    168,                             /* lineNo */
    "@(x)medianFun(x,vlen,NANFLAG)", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\median.m" /* pathName
                                                                           */
};

static emlrtRSInfo jc_emlrtRSI =
    {
        94,            /* lineNo */
        "quickselect", /* fcnName */
        "C:\\Program "
        "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
        "internal\\quickselect.m" /* pathName */
};

static emlrtRSInfo ke_emlrtRSI = {
    154,        /* lineNo */
    "looper1D", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
    "internal\\applyVectorFunction.m" /* pathName */
};

static emlrtRSInfo le_emlrtRSI = {
    170,          /* lineNo */
    "copyVector", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
    "internal\\applyVectorFunction.m" /* pathName */
};

static emlrtRSInfo me_emlrtRSI = {
    172,          /* lineNo */
    "copyVector", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
    "internal\\applyVectorFunction.m" /* pathName */
};

static emlrtRSInfo ne_emlrtRSI = {
    34,       /* lineNo */
    "repmat", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\elmat\\repmat.m" /* pathName
                                                                         */
};

static emlrtRTEInfo o_emlrtRTEI = {
    1,        /* lineNo */
    14,       /* colNo */
    "median", /* fName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\datafun\\median.m" /* pName
                                                                           */
};

static emlrtRTEInfo p_emlrtRTEI = {
    154,                   /* lineNo */
    9,                     /* colNo */
    "applyVectorFunction", /* fName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
    "internal\\applyVectorFunction.m" /* pName */
};

/* Function Definitions */
real_T b_median(const emlrtStack *sp, const real_T x[94])
{
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack st;
  real_T v[94];
  real_T y;
  int32_T ifirst;
  int32_T ipiv;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  st.site = &hd_emlrtRSI;
  ifirst = 0;
  int32_T exitg1;
  do {
    exitg1 = 0;
    if (ifirst < 94) {
      if (muDoubleScalarIsNaN(x[ifirst])) {
        y = rtNaN;
        exitg1 = 1;
      } else {
        ifirst++;
      }
    } else {
      real_T m;
      int32_T ia;
      int32_T ib;
      int32_T ilast;
      int32_T oldnv;
      boolean_T checkspeed;
      boolean_T exitg2;
      boolean_T guard1;
      boolean_T isslow;
      b_st.site = &id_emlrtRSI;
      memcpy(&v[0], &x[0], 94U * sizeof(real_T));
      ipiv = 48;
      ia = 1;
      ib = 94;
      ifirst = 1;
      ilast = 93;
      oldnv = 94;
      checkspeed = false;
      isslow = false;
      exitg2 = false;
      while ((!exitg2) && (ia < ib)) {
        c_st.site = &jc_emlrtRSI;
        ifirst = pivot(&c_st, v, &ipiv, ia, ib);
        ilast = ipiv - 1;
        guard1 = false;
        if (ipiv >= 48) {
          ifirst = ipiv - ifirst;
          if (ifirst <= 48) {
            exitg2 = true;
          } else {
            ib = ipiv - 1;
            guard1 = true;
          }
        } else {
          ia = ipiv + 1;
          guard1 = true;
        }
        if (guard1) {
          ifirst = (ib - ia) + 1;
          if (checkspeed) {
            isslow = (ifirst > oldnv / 2);
            oldnv = ifirst;
          }
          checkspeed = !checkspeed;
          if (isslow) {
            medmed(v, ifirst, ia);
          } else {
            med3(v, ifirst, ia, ib);
          }
          ipiv = ia;
          ifirst = ia;
          ilast = ib - 1;
        }
      }
      m = v[ilast];
      y = v[ilast];
      if (ifirst > 47) {
        b_st.site = &jd_emlrtRSI;
        if (ilast < 47) {
          y = rtNaN;
        } else {
          ifirst = 47;
          ib = 1;
          ipiv = ilast;
          oldnv = ilast;
          checkspeed = false;
          isslow = false;
          exitg2 = false;
          while ((!exitg2) && (ib < ilast)) {
            c_st.site = &jc_emlrtRSI;
            ia = pivot(&c_st, v, &ifirst, ib, ilast);
            ipiv = ifirst;
            guard1 = false;
            if (ifirst >= 47) {
              if (ifirst - ia <= 47) {
                exitg2 = true;
              } else {
                ilast = ifirst - 1;
                guard1 = true;
              }
            } else {
              ib = ifirst + 1;
              guard1 = true;
            }
            if (guard1) {
              ifirst = (ilast - ib) + 1;
              if (checkspeed) {
                isslow = (ifirst > oldnv / 2);
                oldnv = ifirst;
              }
              checkspeed = !checkspeed;
              if (isslow) {
                medmed(v, ifirst, ib);
              } else {
                med3(v, ifirst, ib, ilast);
              }
              ifirst = ib;
              ipiv = ilast;
            }
          }
          y = v[ipiv - 1];
        }
        if (((m < 0.0) != (y < 0.0)) || muDoubleScalarIsInf(m)) {
          y = (m + y) / 2.0;
        } else {
          y = m + (y - m) / 2.0;
        }
      }
      exitg1 = 1;
    }
  } while (exitg1 == 0);
  return y;
}

real_T c_median(const emlrtStack *sp, const real_T x_data[], int32_T x_size)
{
  emlrtStack st;
  emxArray_real_T *xPacked;
  real_T y;
  real_T *xPacked_data;
  int32_T i1;
  st.prev = sp;
  st.tls = sp->tls;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtConstCTX)sp);
  if (x_size == 0) {
    y = rtNaN;
  } else {
    int32_T i;
    emxInit_real_T(sp, &xPacked, 1, &o_emlrtRTEI);
    i = xPacked->size[0];
    xPacked->size[0] = x_size;
    emxEnsureCapacity_real_T(sp, xPacked, i, &n_emlrtRTEI);
    xPacked_data = xPacked->data;
    for (i1 = 0; i1 < x_size; i1++) {
      xPacked_data[i1] = x_data[i1];
    }
    st.site = &hd_emlrtRSI;
    y = vmedian(&st, xPacked, x_size);
    emxFree_real_T(sp, &xPacked);
  }
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtConstCTX)sp);
  return y;
}

void d_median(const emlrtStack *sp, const emxArray_real_T *x, real_T y[99])
{
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack g_st;
  emlrtStack st;
  emxArray_real_T *xv;
  const real_T *x_data;
  real_T *xv_data;
  int32_T i;
  int32_T j;
  int32_T j2;
  int32_T j3;
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
  x_data = x->data;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtConstCTX)sp);
  if (x->size[1] == 0) {
    for (i = 0; i < 99; i++) {
      y[i] = rtNaN;
    }
  } else {
    int32_T nx;
    boolean_T b_overflow;
    boolean_T overflow;
    st.site = &dc_emlrtRSI;
    b_st.site = &ec_emlrtRSI;
    memset(&y[0], 0, 99U * sizeof(real_T));
    nx = x->size[1];
    overflow = (x->size[1] > 2147483646);
    b_overflow = (x->size[1] > 2147483646);
    emxInit_real_T(&b_st, &xv, 1, &p_emlrtRTEI);
    for (j = 0; j < 99; j++) {
      c_st.site = &ke_emlrtRSI;
      d_st.site = &le_emlrtRSI;
      e_st.site = &ne_emlrtRSI;
      k = xv->size[0];
      xv->size[0] = nx;
      emxEnsureCapacity_real_T(&d_st, xv, k, &p_emlrtRTEI);
      xv_data = xv->data;
      for (i = 0; i < nx; i++) {
        xv_data[i] = 0.0;
      }
      d_st.site = &me_emlrtRSI;
      if (overflow) {
        e_st.site = &n_emlrtRSI;
        check_forloop_overflow_error(&e_st);
      }
      for (i = 0; i < nx; i++) {
        xv_data[i] = x_data[j + i * 99];
      }
      c_st.site = &fc_emlrtRSI;
      d_st.site = &gc_emlrtRSI;
      e_st.site = &hc_emlrtRSI;
      f_st.site = &kd_emlrtRSI;
      if (b_overflow) {
        g_st.site = &n_emlrtRSI;
        check_forloop_overflow_error(&g_st);
      }
      k = 0;
      int32_T exitg1;
      do {
        exitg1 = 0;
        if (k <= nx - 1) {
          if (muDoubleScalarIsNaN(xv_data[k])) {
            y[j] = rtNaN;
            exitg1 = 1;
          } else {
            k++;
          }
        } else {
          if (nx <= 4) {
            if (nx == 1) {
              y[j] = xv_data[0];
            } else if (nx == 2) {
              if (((xv_data[0] < 0.0) != (xv_data[1] < 0.0)) ||
                  muDoubleScalarIsInf(xv_data[0])) {
                y[j] = (xv_data[0] + xv_data[1]) / 2.0;
              } else {
                y[j] = xv_data[0] + (xv_data[1] - xv_data[0]) / 2.0;
              }
            } else if (nx == 3) {
              sort3(xv_data[0], xv_data[1], xv_data[2], &k);
              y[j] = xv_data[k - 1];
            } else {
              if (xv_data[0] < xv_data[1]) {
                if (xv_data[1] < xv_data[2]) {
                  k = 0;
                  j2 = 1;
                  j3 = 2;
                } else if (xv_data[0] < xv_data[2]) {
                  k = 0;
                  j2 = 2;
                  j3 = 1;
                } else {
                  k = 2;
                  j2 = 0;
                  j3 = 1;
                }
              } else if (xv_data[0] < xv_data[2]) {
                k = 1;
                j2 = 0;
                j3 = 2;
              } else if (xv_data[1] < xv_data[2]) {
                k = 1;
                j2 = 2;
                j3 = 0;
              } else {
                k = 2;
                j2 = 1;
                j3 = 0;
              }
              if (xv_data[k] < xv_data[3]) {
                if (xv_data[3] < xv_data[j3]) {
                  if (((xv_data[j2] < 0.0) != (xv_data[3] < 0.0)) ||
                      muDoubleScalarIsInf(xv_data[j2])) {
                    y[j] = (xv_data[j2] + xv_data[3]) / 2.0;
                  } else {
                    y[j] = xv_data[j2] + (xv_data[3] - xv_data[j2]) / 2.0;
                  }
                } else if (((xv_data[j2] < 0.0) != (xv_data[j3] < 0.0)) ||
                           muDoubleScalarIsInf(xv_data[j2])) {
                  y[j] = (xv_data[j2] + xv_data[j3]) / 2.0;
                } else {
                  y[j] = xv_data[j2] + (xv_data[j3] - xv_data[j2]) / 2.0;
                }
              } else if (((xv_data[k] < 0.0) != (xv_data[j2] < 0.0)) ||
                         muDoubleScalarIsInf(xv_data[k])) {
                y[j] = (xv_data[k] + xv_data[j2]) / 2.0;
              } else {
                y[j] = xv_data[k] + (xv_data[j2] - xv_data[k]) / 2.0;
              }
            }
          } else {
            int32_T midm1;
            midm1 = nx >> 1;
            if (((uint32_T)nx & 1U) == 0U) {
              real_T m;
              f_st.site = &id_emlrtRSI;
              m = quickselect(xv, midm1 + 1, nx, &k, &j3);
              y[j] = m;
              if (midm1 < k) {
                real_T b;
                f_st.site = &jd_emlrtRSI;
                b = quickselect(xv, midm1, j3 - 1, &k, &j2);
                if (((m < 0.0) != (b < 0.0)) || muDoubleScalarIsInf(m)) {
                  y[j] = (m + b) / 2.0;
                } else {
                  y[j] = m + (b - m) / 2.0;
                }
              }
            } else {
              f_st.site = &ic_emlrtRSI;
              y[j] = quickselect(xv, midm1 + 1, nx, &k, &j2);
            }
          }
          exitg1 = 1;
        }
      } while (exitg1 == 0);
    }
    emxFree_real_T(&b_st, &xv);
  }
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtConstCTX)sp);
}

real_T e_median(const real_T x_data[], const int32_T x_size[2])
{
  real_T a__4_data[80];
  real_T y;
  int32_T j2;
  int32_T j3;
  int32_T k;
  int32_T vlen;
  vlen = x_size[1];
  if (x_size[1] == 0) {
    y = rtNaN;
  } else {
    k = 0;
    int32_T exitg1;
    do {
      exitg1 = 0;
      if (k <= vlen - 1) {
        if (muDoubleScalarIsNaN(x_data[k])) {
          y = rtNaN;
          exitg1 = 1;
        } else {
          k++;
        }
      } else {
        if (vlen <= 4) {
          if (vlen == 0) {
            y = rtNaN;
          } else if (vlen == 1) {
            y = x_data[0];
          } else if (vlen == 2) {
            if (((x_data[0] < 0.0) != (x_data[1] < 0.0)) ||
                muDoubleScalarIsInf(x_data[0])) {
              y = (x_data[0] + x_data[1]) / 2.0;
            } else {
              y = x_data[0] + (x_data[1] - x_data[0]) / 2.0;
            }
          } else if (vlen == 3) {
            sort3(x_data[0], x_data[1], x_data[2], &k);
            y = x_data[k - 1];
          } else {
            if (x_data[0] < x_data[1]) {
              if (x_data[1] < x_data[2]) {
                k = 0;
                j2 = 1;
                j3 = 2;
              } else if (x_data[0] < x_data[2]) {
                k = 0;
                j2 = 2;
                j3 = 1;
              } else {
                k = 2;
                j2 = 0;
                j3 = 1;
              }
            } else if (x_data[0] < x_data[2]) {
              k = 1;
              j2 = 0;
              j3 = 2;
            } else if (x_data[1] < x_data[2]) {
              k = 1;
              j2 = 2;
              j3 = 0;
            } else {
              k = 2;
              j2 = 1;
              j3 = 0;
            }
            if (x_data[k] < x_data[3]) {
              if (x_data[3] < x_data[j3]) {
                if (((x_data[j2] < 0.0) != (x_data[3] < 0.0)) ||
                    muDoubleScalarIsInf(x_data[j2])) {
                  y = (x_data[j2] + x_data[3]) / 2.0;
                } else {
                  y = x_data[j2] + (x_data[3] - x_data[j2]) / 2.0;
                }
              } else if (((x_data[j2] < 0.0) != (x_data[j3] < 0.0)) ||
                         muDoubleScalarIsInf(x_data[j2])) {
                y = (x_data[j2] + x_data[j3]) / 2.0;
              } else {
                y = x_data[j2] + (x_data[j3] - x_data[j2]) / 2.0;
              }
            } else if (((x_data[k] < 0.0) != (x_data[j2] < 0.0)) ||
                       muDoubleScalarIsInf(x_data[k])) {
              y = (x_data[k] + x_data[j2]) / 2.0;
            } else {
              y = x_data[k] + (x_data[j2] - x_data[k]) / 2.0;
            }
          }
        } else {
          int32_T midm1;
          midm1 = vlen >> 1;
          if (((uint32_T)vlen & 1U) == 0U) {
            memcpy(&a__4_data[0], &x_data[0], (uint32_T)vlen * sizeof(real_T));
            y = b_quickselect(a__4_data, midm1 + 1, vlen, &k, &j3);
            if (midm1 < k) {
              real_T b;
              b = b_quickselect(a__4_data, midm1, j3 - 1, &k, &j2);
              if (((y < 0.0) != (b < 0.0)) || muDoubleScalarIsInf(y)) {
                y = (y + b) / 2.0;
              } else {
                y += (b - y) / 2.0;
              }
            }
          } else {
            memcpy(&a__4_data[0], &x_data[0], (uint32_T)vlen * sizeof(real_T));
            y = b_quickselect(a__4_data, midm1 + 1, vlen, &k, &j2);
          }
        }
        exitg1 = 1;
      }
    } while (exitg1 == 0);
  }
  return y;
}

void f_median(const real_T x[75], real_T y[25])
{
  int32_T j;
  int32_T k;
  for (j = 0; j < 25; j++) {
    real_T xv[3];
    xv[0] = x[j];
    xv[1] = x[j + 25];
    xv[2] = x[j + 50];
    k = 0;
    int32_T exitg1;
    do {
      exitg1 = 0;
      if (k < 3) {
        if (muDoubleScalarIsNaN(xv[k])) {
          y[j] = rtNaN;
          exitg1 = 1;
        } else {
          k++;
        }
      } else {
        sort3(xv[0], xv[1], xv[2], &k);
        y[j] = xv[k - 1];
        exitg1 = 1;
      }
    } while (exitg1 == 0);
  }
}

void median(const real_T x[1683], real_T y[99])
{
  int32_T j;
  int32_T k;
  for (j = 0; j < 99; j++) {
    real_T xv[17];
    int32_T ipiv;
    for (k = 0; k < 17; k++) {
      xv[k] = x[j + k * 99];
    }
    ipiv = 0;
    int32_T exitg1;
    do {
      exitg1 = 0;
      if (ipiv < 17) {
        if (muDoubleScalarIsNaN(xv[ipiv])) {
          y[j] = rtNaN;
          exitg1 = 1;
        } else {
          ipiv++;
        }
      } else {
        int32_T ia;
        int32_T ib;
        int32_T ilast;
        int32_T oldnv;
        boolean_T checkspeed;
        boolean_T exitg2;
        boolean_T isslow;
        ipiv = 8;
        ia = 0;
        ib = 16;
        ilast = 16;
        oldnv = 17;
        checkspeed = false;
        isslow = false;
        exitg2 = false;
        while ((!exitg2) && (ia + 1 < ib + 1)) {
          real_T vref;
          boolean_T guard1;
          vref = xv[ipiv];
          xv[ipiv] = xv[ib];
          xv[ib] = vref;
          ilast = ia;
          ipiv = -1;
          for (k = ia + 1; k <= ib; k++) {
            real_T vk;
            vk = xv[k - 1];
            if (vk == vref) {
              xv[k - 1] = xv[ilast];
              xv[ilast] = vk;
              ipiv++;
              ilast++;
            } else if (vk < vref) {
              xv[k - 1] = xv[ilast];
              xv[ilast] = vk;
              ilast++;
            }
          }
          xv[ib] = xv[ilast];
          xv[ilast] = vref;
          guard1 = false;
          if (ilast + 1 >= 9) {
            if (ilast - ipiv <= 9) {
              exitg2 = true;
            } else {
              ib = ilast - 1;
              guard1 = true;
            }
          } else {
            ia = ilast + 1;
            guard1 = true;
          }
          if (guard1) {
            int32_T c;
            c = (ib - ia) + 1;
            if (checkspeed) {
              isslow = (c > oldnv / 2);
              oldnv = c;
            }
            checkspeed = !checkspeed;
            if (isslow) {
              while (c > 1) {
                int32_T i;
                int32_T ngroupsof5;
                int32_T nlast;
                ngroupsof5 = (int32_T)((uint32_T)c / 5U);
                nlast = c - ngroupsof5 * 5;
                c = ngroupsof5;
                i = (uint8_T)ngroupsof5;
                for (k = 0; k < i; k++) {
                  ipiv = (ia + k * 5) + 1;
                  ipiv = thirdOfFive(xv, ipiv, ipiv + 4) - 1;
                  ilast = ia + k;
                  vref = xv[ilast];
                  xv[ilast] = xv[ipiv];
                  xv[ipiv] = vref;
                }
                if (nlast > 0) {
                  ipiv = (ia + ngroupsof5 * 5) + 1;
                  ipiv = thirdOfFive(xv, ipiv, (ipiv + nlast) - 1) - 1;
                  ilast = ia + ngroupsof5;
                  vref = xv[ilast];
                  xv[ilast] = xv[ipiv];
                  xv[ipiv] = vref;
                  c = ngroupsof5 + 1;
                }
              }
            } else if (c >= 3) {
              ipiv = ia + (int32_T)((uint32_T)(c - 1) >> 1);
              if (xv[ia] < xv[ipiv]) {
                if (!(xv[ipiv] < xv[ib])) {
                  if (xv[ia] < xv[ib]) {
                    ipiv = ib;
                  } else {
                    ipiv = ia;
                  }
                }
              } else if (xv[ia] < xv[ib]) {
                ipiv = ia;
              } else if (xv[ipiv] < xv[ib]) {
                ipiv = ib;
              }
              if (ipiv + 1 > ia + 1) {
                vref = xv[ia];
                xv[ia] = xv[ipiv];
                xv[ipiv] = vref;
              }
            }
            ipiv = ia;
            ilast = ib;
          }
        }
        y[j] = xv[ilast];
        exitg1 = 1;
      }
    } while (exitg1 == 0);
  }
}

/* End of code generation (median.c) */
