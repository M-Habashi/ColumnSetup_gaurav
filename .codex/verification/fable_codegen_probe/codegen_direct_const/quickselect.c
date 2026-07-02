/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * quickselect.c
 *
 * Code generation for function 'quickselect'
 *
 */

/* Include files */
#include "quickselect.h"
#include "eml_int_forloop_overflow_check.h"
#include "fable_osi_data.h"
#include "fable_osi_types.h"
#include "rt_nonfinite.h"

/* Variable Definitions */
static emlrtRSInfo lc_emlrtRSI =
    {
        177,     /* lineNo */
        "pivot", /* fcnName */
        "C:\\Program "
        "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
        "internal\\quickselect.m" /* pathName */
};

/* Function Declarations */
static int32_T b_thirdOfFive(const real_T v[94], int32_T ia, int32_T ib);

static int32_T c_thirdOfFive(const emxArray_real_T *v, int32_T ia, int32_T ib);

static int32_T d_thirdOfFive(const real_T v_data[], int32_T ia, int32_T ib);

/* Function Definitions */
static int32_T b_thirdOfFive(const real_T v[94], int32_T ia, int32_T ib)
{
  int32_T im;
  if ((ia == ib) || (ia + 1 == ib)) {
    im = ia;
  } else if ((ia + 2 == ib) || (ia + 3 == ib)) {
    real_T v4;
    v4 = v[ia - 1];
    if (v4 < v[ia]) {
      if (v[ia] < v[ia + 1]) {
        im = ia + 1;
      } else if (v4 < v[ia + 1]) {
        im = ia + 2;
      } else {
        im = ia;
      }
    } else if (v4 < v[ia + 1]) {
      im = ia;
    } else if (v[ia] < v[ia + 1]) {
      im = ia + 2;
    } else {
      im = ia + 1;
    }
  } else {
    real_T v4;
    real_T v5;
    int32_T j2;
    int32_T j3;
    int32_T j4;
    int32_T j5;
    v4 = v[ia - 1];
    if (v4 < v[ia]) {
      if (v[ia] < v[ia + 1]) {
        im = ia;
        j2 = ia;
        j3 = ia + 2;
      } else if (v4 < v[ia + 1]) {
        im = ia;
        j2 = ia + 1;
        j3 = ia + 1;
      } else {
        im = ia + 2;
        j2 = ia - 1;
        j3 = ia + 1;
      }
    } else if (v4 < v[ia + 1]) {
      im = ia + 1;
      j2 = ia - 1;
      j3 = ia + 2;
    } else if (v[ia] < v[ia + 1]) {
      im = ia + 1;
      j2 = ia + 1;
      j3 = ia;
    } else {
      im = ia + 2;
      j2 = ia;
      j3 = ia;
    }
    j4 = ia;
    j5 = ia + 1;
    v4 = v[ia + 2];
    v5 = v[ia + 3];
    if (v5 < v4) {
      j4 = ia + 1;
      j5 = ia;
      v5 = v4;
      v4 = v[ia + 3];
    }
    if (!(v5 < v[im - 1])) {
      if (v5 < v[j2]) {
        im = j5 + 3;
      } else if (v4 < v[j2]) {
        im = j2 + 1;
      } else if (v4 < v[j3 - 1]) {
        im = j4 + 3;
      } else {
        im = j3;
      }
    }
  }
  return im;
}

static int32_T c_thirdOfFive(const emxArray_real_T *v, int32_T ia, int32_T ib)
{
  const real_T *v_data;
  int32_T im;
  v_data = v->data;
  if ((ia == ib) || (ia + 1 == ib)) {
    im = ia;
  } else if ((ia + 2 == ib) || (ia + 3 == ib)) {
    real_T v4;
    v4 = v_data[ia - 1];
    if (v4 < v_data[ia]) {
      if (v_data[ia] < v_data[ia + 1]) {
        im = ia + 1;
      } else if (v4 < v_data[ia + 1]) {
        im = ia + 2;
      } else {
        im = ia;
      }
    } else if (v4 < v_data[ia + 1]) {
      im = ia;
    } else if (v_data[ia] < v_data[ia + 1]) {
      im = ia + 2;
    } else {
      im = ia + 1;
    }
  } else {
    real_T v4;
    real_T v5;
    int32_T j2;
    int32_T j3;
    int32_T j4;
    int32_T j5;
    v4 = v_data[ia - 1];
    if (v4 < v_data[ia]) {
      if (v_data[ia] < v_data[ia + 1]) {
        im = ia;
        j2 = ia;
        j3 = ia + 2;
      } else if (v4 < v_data[ia + 1]) {
        im = ia;
        j2 = ia + 1;
        j3 = ia + 1;
      } else {
        im = ia + 2;
        j2 = ia - 1;
        j3 = ia + 1;
      }
    } else if (v4 < v_data[ia + 1]) {
      im = ia + 1;
      j2 = ia - 1;
      j3 = ia + 2;
    } else if (v_data[ia] < v_data[ia + 1]) {
      im = ia + 1;
      j2 = ia + 1;
      j3 = ia;
    } else {
      im = ia + 2;
      j2 = ia;
      j3 = ia;
    }
    j4 = ia;
    j5 = ia + 1;
    v4 = v_data[ia + 2];
    v5 = v_data[ia + 3];
    if (v5 < v4) {
      j4 = ia + 1;
      j5 = ia;
      v5 = v4;
      v4 = v_data[ia + 3];
    }
    if (!(v5 < v_data[im - 1])) {
      if (v5 < v_data[j2]) {
        im = j5 + 3;
      } else if (v4 < v_data[j2]) {
        im = j2 + 1;
      } else if (v4 < v_data[j3 - 1]) {
        im = j4 + 3;
      } else {
        im = j3;
      }
    }
  }
  return im;
}

static int32_T d_thirdOfFive(const real_T v_data[], int32_T ia, int32_T ib)
{
  int32_T im;
  if ((ia == ib) || (ia + 1 == ib)) {
    im = ia;
  } else if ((ia + 2 == ib) || (ia + 3 == ib)) {
    real_T v4;
    v4 = v_data[ia - 1];
    if (v4 < v_data[ia]) {
      if (v_data[ia] < v_data[ia + 1]) {
        im = ia + 1;
      } else if (v4 < v_data[ia + 1]) {
        im = ia + 2;
      } else {
        im = ia;
      }
    } else if (v4 < v_data[ia + 1]) {
      im = ia;
    } else if (v_data[ia] < v_data[ia + 1]) {
      im = ia + 2;
    } else {
      im = ia + 1;
    }
  } else {
    real_T v4;
    real_T v5;
    int32_T j2;
    int32_T j3;
    int32_T j4;
    int32_T j5;
    v4 = v_data[ia - 1];
    if (v4 < v_data[ia]) {
      if (v_data[ia] < v_data[ia + 1]) {
        im = ia;
        j2 = ia;
        j3 = ia + 2;
      } else if (v4 < v_data[ia + 1]) {
        im = ia;
        j2 = ia + 1;
        j3 = ia + 1;
      } else {
        im = ia + 2;
        j2 = ia - 1;
        j3 = ia + 1;
      }
    } else if (v4 < v_data[ia + 1]) {
      im = ia + 1;
      j2 = ia - 1;
      j3 = ia + 2;
    } else if (v_data[ia] < v_data[ia + 1]) {
      im = ia + 1;
      j2 = ia + 1;
      j3 = ia;
    } else {
      im = ia + 2;
      j2 = ia;
      j3 = ia;
    }
    j4 = ia;
    j5 = ia + 1;
    v4 = v_data[ia + 2];
    v5 = v_data[ia + 3];
    if (v5 < v4) {
      j4 = ia + 1;
      j5 = ia;
      v5 = v4;
      v4 = v_data[ia + 3];
    }
    if (!(v5 < v_data[im - 1])) {
      if (v5 < v_data[j2]) {
        im = j5 + 3;
      } else if (v4 < v_data[j2]) {
        im = j2 + 1;
      } else if (v4 < v_data[j3 - 1]) {
        im = j4 + 3;
      } else {
        im = j3;
      }
    }
  }
  return im;
}

real_T b_quickselect(real_T v_data[], int32_T n, int32_T vlen, int32_T *nfirst,
                     int32_T *nlast)
{
  real_T vn;
  int32_T k;
  if (n > vlen) {
    vn = rtNaN;
    *nfirst = 0;
    *nlast = 0;
  } else {
    int32_T ia;
    int32_T ib;
    int32_T ifirst;
    int32_T ilast;
    int32_T ipiv;
    int32_T oldnv;
    boolean_T checkspeed;
    boolean_T exitg1;
    boolean_T isslow;
    ipiv = n;
    ia = 0;
    ib = vlen - 1;
    ifirst = 1;
    ilast = vlen - 1;
    oldnv = vlen;
    checkspeed = false;
    isslow = false;
    exitg1 = false;
    while ((!exitg1) && (ia + 1 < ib + 1)) {
      boolean_T guard1;
      vn = v_data[ipiv - 1];
      v_data[ipiv - 1] = v_data[ib];
      v_data[ib] = vn;
      ilast = ia;
      ipiv = -1;
      for (k = ia + 1; k <= ib; k++) {
        real_T vk;
        vk = v_data[k - 1];
        if (vk == vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ipiv++;
          ilast++;
        } else if (vk < vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ilast++;
        }
      }
      v_data[ib] = v_data[ilast];
      v_data[ilast] = vn;
      guard1 = false;
      if (n <= ilast + 1) {
        ifirst = ilast - ipiv;
        if (n >= ifirst) {
          exitg1 = true;
        } else {
          ib = ilast - 1;
          guard1 = true;
        }
      } else {
        ia = ilast + 1;
        guard1 = true;
      }
      if (guard1) {
        ilast = (ib - ia) + 1;
        if (checkspeed) {
          isslow = (ilast > oldnv / 2);
          oldnv = ilast;
        }
        checkspeed = !checkspeed;
        if (isslow) {
          while (ilast > 1) {
            int32_T b_nlast;
            int32_T i;
            int32_T ngroupsof5;
            ngroupsof5 = (int32_T)((uint32_T)ilast / 5U);
            b_nlast = ilast - ngroupsof5 * 5;
            ilast = ngroupsof5;
            i = (uint8_T)ngroupsof5;
            for (k = 0; k < i; k++) {
              ipiv = (ia + k * 5) + 1;
              ipiv = d_thirdOfFive(v_data, ipiv, ipiv + 4) - 1;
              ifirst = ia + k;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
            }
            if (b_nlast > 0) {
              ipiv = (ia + ngroupsof5 * 5) + 1;
              ipiv = d_thirdOfFive(v_data, ipiv, (ipiv + b_nlast) - 1) - 1;
              ifirst = ia + ngroupsof5;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
              ilast = ngroupsof5 + 1;
            }
          }
        } else if (ilast >= 3) {
          ipiv = ia + (int32_T)((uint32_T)(ilast - 1) >> 1);
          if (v_data[ia] < v_data[ipiv]) {
            if (!(v_data[ipiv] < v_data[ib])) {
              if (v_data[ia] < v_data[ib]) {
                ipiv = ib;
              } else {
                ipiv = ia;
              }
            }
          } else if (v_data[ia] < v_data[ib]) {
            ipiv = ia;
          } else if (v_data[ipiv] < v_data[ib]) {
            ipiv = ib;
          }
          if (ipiv + 1 > ia + 1) {
            vn = v_data[ia];
            v_data[ia] = v_data[ipiv];
            v_data[ipiv] = vn;
          }
        }
        ipiv = ia + 1;
        ifirst = ia + 1;
        ilast = ib;
      }
    }
    vn = v_data[ilast];
    *nfirst = ifirst;
    *nlast = ilast + 1;
  }
  return vn;
}

void med3(real_T v[94], int32_T nv, int32_T ia, int32_T ib)
{
  if (nv >= 3) {
    real_T d;
    real_T d1;
    int32_T ic;
    ic = ia + (int32_T)((uint32_T)(nv - 1) >> 1);
    d = v[ia - 1];
    d1 = v[ic - 1];
    if (d < d1) {
      if (!(d1 < v[ib - 1])) {
        if (d < v[ib - 1]) {
          ic = ib;
        } else {
          ic = ia;
        }
      }
    } else if (d < v[ib - 1]) {
      ic = ia;
    } else if (d1 < v[ib - 1]) {
      ic = ib;
    }
    if (ic > ia) {
      v[ia - 1] = v[ic - 1];
      v[ic - 1] = d;
    }
  }
}

void medmed(real_T v[94], int32_T nv, int32_T ia)
{
  int32_T k;
  while (nv > 1) {
    real_T tmp;
    int32_T destidx;
    int32_T i;
    int32_T i1;
    int32_T ngroupsof5;
    int32_T nlast;
    ngroupsof5 = (int32_T)((uint32_T)nv / 5U);
    nlast = nv - ngroupsof5 * 5;
    nv = ngroupsof5;
    i = (uint8_T)ngroupsof5;
    for (k = 0; k < i; k++) {
      i1 = ia + k * 5;
      i1 = b_thirdOfFive(v, i1, i1 + 4) - 1;
      destidx = (ia + k) - 1;
      tmp = v[destidx];
      v[destidx] = v[i1];
      v[i1] = tmp;
    }
    if (nlast > 0) {
      i1 = ia + ngroupsof5 * 5;
      i1 = b_thirdOfFive(v, i1, (i1 + nlast) - 1) - 1;
      destidx = (ia + ngroupsof5) - 1;
      tmp = v[destidx];
      v[destidx] = v[i1];
      v[i1] = tmp;
      nv = ngroupsof5 + 1;
    }
  }
}

int32_T pivot(const emlrtStack *sp, real_T v[94], int32_T *ip, int32_T ia,
              int32_T ib)
{
  emlrtStack b_st;
  emlrtStack st;
  real_T vref;
  int32_T k;
  int32_T reps;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  vref = v[*ip - 1];
  v[*ip - 1] = v[ib - 1];
  v[ib - 1] = vref;
  *ip = ia;
  reps = 0;
  st.site = &lc_emlrtRSI;
  if ((ia <= ib - 1) && (ib - 1 > 2147483646)) {
    b_st.site = &n_emlrtRSI;
    check_forloop_overflow_error(&b_st);
  }
  for (k = ia; k < ib; k++) {
    real_T vk;
    vk = v[k - 1];
    if (vk == vref) {
      v[k - 1] = v[*ip - 1];
      v[*ip - 1] = vk;
      reps++;
      (*ip)++;
    } else if (vk < vref) {
      v[k - 1] = v[*ip - 1];
      v[*ip - 1] = vk;
      (*ip)++;
    }
  }
  v[ib - 1] = v[*ip - 1];
  v[*ip - 1] = vref;
  return reps;
}

real_T quickselect(emxArray_real_T *v, int32_T n, int32_T vlen, int32_T *nfirst,
                   int32_T *nlast)
{
  real_T vn;
  real_T *v_data;
  int32_T k;
  v_data = v->data;
  if (n > vlen) {
    vn = rtNaN;
    *nfirst = 0;
    *nlast = 0;
  } else {
    int32_T ia;
    int32_T ib;
    int32_T ifirst;
    int32_T ilast;
    int32_T ipiv;
    int32_T oldnv;
    boolean_T checkspeed;
    boolean_T exitg1;
    boolean_T isslow;
    ipiv = n;
    ia = 0;
    ib = vlen - 1;
    ifirst = 1;
    ilast = vlen - 1;
    oldnv = vlen;
    checkspeed = false;
    isslow = false;
    exitg1 = false;
    while ((!exitg1) && (ia + 1 < ib + 1)) {
      boolean_T guard1;
      vn = v_data[ipiv - 1];
      v_data[ipiv - 1] = v_data[ib];
      v_data[ib] = vn;
      ilast = ia;
      ipiv = -1;
      for (k = ia + 1; k <= ib; k++) {
        real_T vk;
        vk = v_data[k - 1];
        if (vk == vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ipiv++;
          ilast++;
        } else if (vk < vn) {
          v_data[k - 1] = v_data[ilast];
          v_data[ilast] = vk;
          ilast++;
        }
      }
      v_data[ib] = v_data[ilast];
      v_data[ilast] = vn;
      guard1 = false;
      if (n <= ilast + 1) {
        ifirst = ilast - ipiv;
        if (n >= ifirst) {
          exitg1 = true;
        } else {
          ib = ilast - 1;
          guard1 = true;
        }
      } else {
        ia = ilast + 1;
        guard1 = true;
      }
      if (guard1) {
        ilast = (ib - ia) + 1;
        if (checkspeed) {
          isslow = (ilast > oldnv / 2);
          oldnv = ilast;
        }
        checkspeed = !checkspeed;
        if (isslow) {
          while (ilast > 1) {
            int32_T b_nlast;
            int32_T ngroupsof5;
            ngroupsof5 = (int32_T)((uint32_T)ilast / 5U);
            b_nlast = ilast - ngroupsof5 * 5;
            ilast = ngroupsof5;
            for (k = 0; k < ngroupsof5; k++) {
              ipiv = (ia + k * 5) + 1;
              ipiv = c_thirdOfFive(v, ipiv, ipiv + 4) - 1;
              ifirst = ia + k;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
            }
            if (b_nlast > 0) {
              ipiv = (ia + ngroupsof5 * 5) + 1;
              ipiv = c_thirdOfFive(v, ipiv, (ipiv + b_nlast) - 1) - 1;
              ifirst = ia + ngroupsof5;
              vn = v_data[ifirst];
              v_data[ifirst] = v_data[ipiv];
              v_data[ipiv] = vn;
              ilast = ngroupsof5 + 1;
            }
          }
        } else if (ilast >= 3) {
          ipiv = ia + (int32_T)((uint32_T)(ilast - 1) >> 1);
          if (v_data[ia] < v_data[ipiv]) {
            if (!(v_data[ipiv] < v_data[ib])) {
              if (v_data[ia] < v_data[ib]) {
                ipiv = ib;
              } else {
                ipiv = ia;
              }
            }
          } else if (v_data[ia] < v_data[ib]) {
            ipiv = ia;
          } else if (v_data[ipiv] < v_data[ib]) {
            ipiv = ib;
          }
          if (ipiv + 1 > ia + 1) {
            vn = v_data[ia];
            v_data[ia] = v_data[ipiv];
            v_data[ipiv] = vn;
          }
        }
        ipiv = ia + 1;
        ifirst = ia + 1;
        ilast = ib;
      }
    }
    vn = v_data[ilast];
    *nfirst = ifirst;
    *nlast = ilast + 1;
  }
  return vn;
}

int32_T thirdOfFive(const real_T v[17], int32_T ia, int32_T ib)
{
  int32_T im;
  if ((ia == ib) || (ia + 1 == ib)) {
    im = ia;
  } else if ((ia + 2 == ib) || (ia + 3 == ib)) {
    real_T v4;
    v4 = v[ia - 1];
    if (v4 < v[ia]) {
      if (v[ia] < v[ia + 1]) {
        im = ia + 1;
      } else if (v4 < v[ia + 1]) {
        im = ia + 2;
      } else {
        im = ia;
      }
    } else if (v4 < v[ia + 1]) {
      im = ia;
    } else if (v[ia] < v[ia + 1]) {
      im = ia + 2;
    } else {
      im = ia + 1;
    }
  } else {
    real_T v4;
    real_T v5;
    int32_T j2;
    int32_T j3;
    int32_T j4;
    int32_T j5;
    v4 = v[ia - 1];
    if (v4 < v[ia]) {
      if (v[ia] < v[ia + 1]) {
        im = ia;
        j2 = ia;
        j3 = ia + 2;
      } else if (v4 < v[ia + 1]) {
        im = ia;
        j2 = ia + 1;
        j3 = ia + 1;
      } else {
        im = ia + 2;
        j2 = ia - 1;
        j3 = ia + 1;
      }
    } else if (v4 < v[ia + 1]) {
      im = ia + 1;
      j2 = ia - 1;
      j3 = ia + 2;
    } else if (v[ia] < v[ia + 1]) {
      im = ia + 1;
      j2 = ia + 1;
      j3 = ia;
    } else {
      im = ia + 2;
      j2 = ia;
      j3 = ia;
    }
    j4 = ia;
    j5 = ia + 1;
    v4 = v[ia + 2];
    v5 = v[ia + 3];
    if (v5 < v4) {
      j4 = ia + 1;
      j5 = ia;
      v5 = v4;
      v4 = v[ia + 3];
    }
    if (!(v5 < v[im - 1])) {
      if (v5 < v[j2]) {
        im = j5 + 3;
      } else if (v4 < v[j2]) {
        im = j2 + 1;
      } else if (v4 < v[j3 - 1]) {
        im = j4 + 3;
      } else {
        im = j3;
      }
    }
  }
  return im;
}

/* End of code generation (quickselect.c) */
