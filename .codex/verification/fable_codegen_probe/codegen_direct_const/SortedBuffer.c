/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * SortedBuffer.c
 *
 * Code generation for function 'SortedBuffer'
 *
 */

/* Include files */
#include "SortedBuffer.h"
#include "eml_int_forloop_overflow_check.h"
#include "fable_osi_data.h"
#include "fable_osi_internal_types.h"
#include "rt_nonfinite.h"
#include "warning.h"
#include "mwmathutil.h"

/* Variable Definitions */
static emlrtRSInfo bd_emlrtRSI = {
    72,                    /* lineNo */
    "SortedBuffer/insert", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\SortedBuffer."
    "m" /* pathName */
};

static emlrtRSInfo gd_emlrtRSI = {
    121,                   /* lineNo */
    "SortedBuffer/remove", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\SortedBuffer."
    "m" /* pathName */
};

/* Function Declarations */
static int32_T b_SortedBuffer_locateElement(const real_T obj_buf[3],
                                            int32_T obj_nbuf, real_T x);

/* Function Definitions */
static int32_T b_SortedBuffer_locateElement(const real_T obj_buf[3],
                                            int32_T obj_nbuf, real_T x)
{
  int32_T i;
  if ((obj_nbuf == 0) || (x < obj_buf[0])) {
    i = 0;
  } else if (x < obj_buf[obj_nbuf - 1]) {
    int32_T ip1;
    int32_T upper;
    i = 1;
    ip1 = 2;
    upper = obj_nbuf;
    while (upper > ip1) {
      int32_T m;
      m = (i + upper) >> 1;
      if (x < obj_buf[m - 1]) {
        upper = m;
      } else {
        i = m;
        ip1 = m + 1;
      }
    }
  } else {
    i = obj_nbuf;
  }
  return i;
}

void SortedBuffer_insert(const emlrtStack *sp, coder_internal_SortedBuffer *obj,
                         real_T x)
{
  emlrtStack st;
  int32_T k;
  st.prev = sp;
  st.tls = sp->tls;
  if (obj->nbuf >= 7) {
    st.site = &bd_emlrtRSI;
    b_warning(&st);
  } else if (!muDoubleScalarIsNaN(x)) {
    if (obj->nbuf == 0) {
      obj->buf[0] = x;
      obj->nbuf = 1;
    } else {
      int32_T i;
      i = SortedBuffer_locateElement(obj->buf, obj->nbuf, x);
      if (i == 0) {
        i = obj->nbuf;
        for (k = i; k >= 1; k--) {
          obj->buf[k] = obj->buf[k - 1];
        }
        obj->buf[0] = x;
        obj->nbuf++;
      } else if (i >= obj->nbuf) {
        obj->nbuf++;
        obj->buf[obj->nbuf - 1] = x;
      } else {
        int32_T b_i;
        int32_T i1;
        b_i = obj->nbuf;
        i1 = i + 1;
        for (k = b_i; k >= i1; k--) {
          obj->buf[k] = obj->buf[k - 1];
        }
        obj->buf[i] = x;
        obj->nbuf++;
      }
    }
  }
}

int32_T SortedBuffer_locateElement(const real_T obj_buf[7], int32_T obj_nbuf,
                                   real_T x)
{
  int32_T i;
  if ((obj_nbuf == 0) || (x < obj_buf[0])) {
    i = 0;
  } else if (x < obj_buf[obj_nbuf - 1]) {
    int32_T ip1;
    int32_T upper;
    i = 1;
    ip1 = 2;
    upper = obj_nbuf;
    while (upper > ip1) {
      int32_T m;
      m = (i + upper) >> 1;
      if (x < obj_buf[m - 1]) {
        upper = m;
      } else {
        i = m;
        ip1 = m + 1;
      }
    }
  } else {
    i = obj_nbuf;
  }
  return i;
}

void SortedBuffer_remove(const emlrtStack *sp, coder_internal_SortedBuffer *obj,
                         real_T x)
{
  emlrtStack b_st;
  emlrtStack st;
  int32_T k;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  if (!muDoubleScalarIsNaN(x)) {
    if (obj->nbuf == 1) {
      if (x == obj->buf[0]) {
        obj->nbuf = 0;
      }
    } else {
      int32_T i;
      i = SortedBuffer_locateElement(obj->buf, obj->nbuf, x);
      if ((i > 0) && (x == obj->buf[i - 1])) {
        int32_T a;
        int32_T b;
        a = i + 1;
        b = obj->nbuf;
        st.site = &gd_emlrtRSI;
        if ((i + 1 <= obj->nbuf) && (obj->nbuf > 2147483646)) {
          b_st.site = &n_emlrtRSI;
          check_forloop_overflow_error(&b_st);
        }
        for (k = a; k <= b; k++) {
          obj->buf[k - 2] = obj->buf[k - 1];
        }
        obj->nbuf--;
      }
    }
  }
}

void SortedBuffer_replace(const emlrtStack *sp,
                          b_coder_internal_SortedBuffer *obj, real_T xold,
                          real_T xnew)
{
  emlrtStack st;
  int32_T k;
  st.prev = sp;
  st.tls = sp->tls;
  if (muDoubleScalarIsNaN(xold)) {
    st.site = &fd_emlrtRSI;
    b_SortedBuffer_insert(&st, obj, xnew);
  } else if (muDoubleScalarIsNaN(xnew)) {
    st.site = &ed_emlrtRSI;
    b_SortedBuffer_remove(&st, obj, xold);
  } else {
    int32_T iold;
    iold = b_SortedBuffer_locateElement(obj->buf, obj->nbuf, xold);
    if ((iold > 0) && (obj->buf[iold - 1] == xold)) {
      int32_T inew;
      inew = b_SortedBuffer_locateElement(obj->buf, obj->nbuf, xnew);
      if (iold <= inew) {
        for (k = iold; k < inew; k++) {
          obj->buf[k - 1] = obj->buf[k];
        }
        obj->buf[inew - 1] = xnew;
      } else if (iold == inew + 1) {
        obj->buf[iold - 1] = xnew;
      } else {
        int32_T i;
        i = inew + 2;
        for (k = iold; k >= i; k--) {
          obj->buf[k - 1] = obj->buf[k - 2];
        }
        obj->buf[inew] = xnew;
      }
    } else {
      st.site = &cd_emlrtRSI;
      b_SortedBuffer_insert(&st, obj, xnew);
    }
  }
}

void b_SortedBuffer_insert(const emlrtStack *sp,
                           b_coder_internal_SortedBuffer *obj, real_T x)
{
  emlrtStack st;
  int32_T k;
  st.prev = sp;
  st.tls = sp->tls;
  if (obj->nbuf >= 3) {
    st.site = &bd_emlrtRSI;
    b_warning(&st);
  } else if (!muDoubleScalarIsNaN(x)) {
    if (obj->nbuf == 0) {
      obj->buf[0] = x;
      obj->nbuf = 1;
    } else {
      int32_T i;
      i = b_SortedBuffer_locateElement(obj->buf, obj->nbuf, x);
      if (i == 0) {
        i = obj->nbuf;
        for (k = i; k >= 1; k--) {
          obj->buf[k] = obj->buf[k - 1];
        }
        obj->buf[0] = x;
        obj->nbuf++;
      } else if (i >= obj->nbuf) {
        obj->nbuf++;
        obj->buf[obj->nbuf - 1] = x;
      } else {
        int32_T b_i;
        int32_T i1;
        b_i = obj->nbuf;
        i1 = i + 1;
        for (k = b_i; k >= i1; k--) {
          obj->buf[k] = obj->buf[k - 1];
        }
        obj->buf[i] = x;
        obj->nbuf++;
      }
    }
  }
}

void b_SortedBuffer_remove(const emlrtStack *sp,
                           b_coder_internal_SortedBuffer *obj, real_T x)
{
  emlrtStack b_st;
  emlrtStack st;
  int32_T k;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  if (!muDoubleScalarIsNaN(x)) {
    if (obj->nbuf == 1) {
      if (x == obj->buf[0]) {
        obj->nbuf = 0;
      }
    } else {
      int32_T i;
      i = b_SortedBuffer_locateElement(obj->buf, obj->nbuf, x);
      if ((i > 0) && (x == obj->buf[i - 1])) {
        int32_T a;
        int32_T b;
        a = i + 1;
        b = obj->nbuf;
        st.site = &gd_emlrtRSI;
        if ((i + 1 <= obj->nbuf) && (obj->nbuf > 2147483646)) {
          b_st.site = &n_emlrtRSI;
          check_forloop_overflow_error(&b_st);
        }
        for (k = a; k <= b; k++) {
          obj->buf[k - 2] = obj->buf[k - 1];
        }
        obj->nbuf--;
      }
    }
  }
}

/* End of code generation (SortedBuffer.c) */
