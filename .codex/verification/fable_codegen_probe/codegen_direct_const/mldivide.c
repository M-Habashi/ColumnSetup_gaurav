/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * mldivide.c
 *
 * Code generation for function 'mldivide'
 *
 */

/* Include files */
#include "mldivide.h"
#include "fable_osi_data.h"
#include "fable_osi_mexutil.h"
#include "infocheck.h"
#include "rt_nonfinite.h"
#include "warning.h"
#include "lapacke.h"
#include "mwmathutil.h"
#include <stddef.h>
#include <string.h>

/* Variable Definitions */
static emlrtRSInfo g_emlrtRSI = {
    138,            /* lineNo */
    "ceval_xgeqp3", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\+"
    "lapack\\xgeqp3.m" /* pathName */
};

static emlrtRSInfo h_emlrtRSI = {
    20,         /* lineNo */
    "mldivide", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\ops\\mldivide.m" /* pathName
                                                                         */
};

static emlrtRSInfo i_emlrtRSI = {
    44,      /* lineNo */
    "mldiv", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\lib\\matlab\\ops\\mldivide.m" /* pathName
                                                                         */
};

static emlrtRSInfo
    j_emlrtRSI =
        {
            61,        /* lineNo */
            "qrsolve", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo
    k_emlrtRSI =
        {
            72,        /* lineNo */
            "qrsolve", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo
    l_emlrtRSI =
        {
            85,        /* lineNo */
            "qrsolve", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo m_emlrtRSI = {
    63,       /* lineNo */
    "xgeqp3", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\+"
    "lapack\\xgeqp3.m" /* pathName */
};

static emlrtRSInfo
    o_emlrtRSI =
        {
            173,          /* lineNo */
            "rankFromQR", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo
    p_emlrtRSI =
        {
            172,          /* lineNo */
            "rankFromQR", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo
    q_emlrtRSI =
        {
            119,         /* lineNo */
            "LSQFromQR", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo
    r_emlrtRSI =
        {
            128,         /* lineNo */
            "LSQFromQR", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo
    s_emlrtRSI =
        {
            138,         /* lineNo */
            "LSQFromQR", /* fcnName */
            "C:\\Program "
            "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+"
            "internal\\qrsolve.m" /* pathName */
};

static emlrtRSInfo t_emlrtRSI = {
    40,         /* lineNo */
    "xunormqr", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\+"
    "lapack\\xunormqr.m" /* pathName */
};

static emlrtRSInfo u_emlrtRSI = {
    106,              /* lineNo */
    "ceval_xunormqr", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\eml\\eml\\+coder\\+internal\\+"
    "lapack\\xunormqr.m" /* pathName */
};

static emlrtMCInfo emlrtMCI = {
    53,        /* lineNo */
    19,        /* colNo */
    "flt2str", /* fName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\shared\\coder\\coder\\lib\\+coder\\+"
    "internal\\flt2str.m" /* pName */
};

static const char_T cv[14] = {'L', 'A', 'P', 'A', 'C', 'K', 'E',
                              '_', 'd', 'g', 'e', 'q', 'p', '3'};

static emlrtRSInfo kg_emlrtRSI = {
    53,        /* lineNo */
    "flt2str", /* fcnName */
    "C:\\Program "
    "Files\\MATLAB\\R2025b\\toolbox\\shared\\coder\\coder\\lib\\+coder\\+"
    "internal\\flt2str.m" /* pathName */
};

/* Function Declarations */
static void b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               char_T y[14]);

static const mxArray *b_sprintf(const emlrtStack *sp, const mxArray *m,
                                const mxArray *m1, emlrtMCInfo *location);

static void emlrt_marshallIn(const emlrtStack *sp,
                             const mxArray *a__output_of_sprintf_,
                             const char_T *identifier, char_T y[14]);

static void y_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, char_T ret[14]);

/* Function Definitions */
static void b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, char_T y[14])
{
  y_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static const mxArray *b_sprintf(const emlrtStack *sp, const mxArray *m,
                                const mxArray *m1, emlrtMCInfo *location)
{
  const mxArray *pArrays[2];
  const mxArray *m2;
  pArrays[0] = m;
  pArrays[1] = m1;
  return emlrtCallMATLABR2012b((emlrtConstCTX)sp, 1, &m2, 2, &pArrays[0],
                               "sprintf", true, location);
}

static void emlrt_marshallIn(const emlrtStack *sp,
                             const mxArray *a__output_of_sprintf_,
                             const char_T *identifier, char_T y[14])
{
  emlrtMsgIdentifier thisId;
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  b_emlrt_marshallIn(sp, emlrtAlias(a__output_of_sprintf_), &thisId, y);
  emlrtDestroyArray(&a__output_of_sprintf_);
}

static void y_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, char_T ret[14])
{
  static const int32_T dims[2] = {1, 14};
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "char", false, 2U,
                          (const void *)&dims[0]);
  emlrtImportCharArrayR2015b((emlrtConstCTX)sp, src, &ret[0], 14);
  emlrtDestroyArray(&src);
}

void b_mldivide(const emlrtStack *sp, const real_T B[2048], real_T Y[2])
{
  static const int32_T b_iv[2] = {1, 6};
  static const char_T rfmt[6] = {'%', '1', '4', '.', '6', 'e'};
  ptrdiff_t jpvt_t[2];
  ptrdiff_t info_t;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack st;
  const mxArray *m;
  const mxArray *y;
  real_T A[4096];
  real_T b_B[2048];
  real_T tau[2];
  real_T tol;
  int32_T jpvt[2];
  int32_T b_i;
  int32_T i;
  int32_T rankA;
  boolean_T p;
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
  st.site = &h_emlrtRSI;
  b_st.site = &i_emlrtRSI;
  c_st.site = &j_emlrtRSI;
  d_st.site = &m_emlrtRSI;
  memcpy(&A[0], &dv2[0], 4096U * sizeof(real_T));
  jpvt_t[0] = (ptrdiff_t)0;
  jpvt_t[1] = (ptrdiff_t)0;
  info_t = LAPACKE_dgeqp3(102, (ptrdiff_t)2048, (ptrdiff_t)2, &A[0],
                          (ptrdiff_t)2048, &jpvt_t[0], &tau[0]);
  e_st.site = &g_emlrtRSI;
  if ((int32_T)info_t != 0) {
    p = true;
    if ((int32_T)info_t != -4) {
      if ((int32_T)info_t == -1010) {
        emlrtErrorWithMessageIdR2018a(&e_st, &b_emlrtRTEI, "MATLAB:nomem",
                                      "MATLAB:nomem", 0);
      } else {
        emlrtErrorWithMessageIdR2018a(&e_st, &emlrtRTEI,
                                      "Coder:toolbox:LAPACKCallErrorInfo",
                                      "Coder:toolbox:LAPACKCallErrorInfo", 5, 4,
                                      14, &cv[0], 12, (int32_T)info_t);
      }
    }
  } else {
    p = false;
  }
  if (p) {
    for (i = 0; i < 4096; i++) {
      A[i] = rtNaN;
    }
    tau[0] = rtNaN;
    jpvt[0] = 1;
    tau[1] = rtNaN;
    jpvt[1] = 2;
  } else {
    jpvt[0] = (int32_T)jpvt_t[0];
    jpvt[1] = (int32_T)jpvt_t[1];
  }
  c_st.site = &k_emlrtRSI;
  rankA = 0;
  tol = 4.5474735088646412E-12 * muDoubleScalarAbs(A[0]);
  while ((rankA < 2) &&
         (!(muDoubleScalarAbs(A[rankA + (rankA << 11)]) <= tol))) {
    rankA++;
  }
  if ((rankA < 2) && (!emlrtSetWarningFlag(&c_st))) {
    char_T str[14];
    d_st.site = &o_emlrtRSI;
    y = NULL;
    m = emlrtCreateCharArray(2, &b_iv[0]);
    emlrtInitCharArrayR2013a(&d_st, 6, m, &rfmt[0]);
    emlrtAssign(&y, m);
    e_st.site = &kg_emlrtRSI;
    emlrt_marshallIn(&e_st,
                     b_sprintf(&e_st, y, emlrt_marshallOut(tol), &emlrtMCI),
                     "<output of sprintf>", str);
    d_st.site = &p_emlrtRSI;
    warning(&d_st, rankA, str);
  }
  c_st.site = &l_emlrtRSI;
  memcpy(&b_B[0], &B[0], 2048U * sizeof(real_T));
  Y[0] = 0.0;
  Y[1] = 0.0;
  d_st.site = &q_emlrtRSI;
  e_st.site = &t_emlrtRSI;
  info_t = (ptrdiff_t)2048;
  info_t = LAPACKE_dormqr(102, 'L', 'T', info_t, (ptrdiff_t)1, (ptrdiff_t)2,
                          &A[0], (ptrdiff_t)2048, &tau[0], &b_B[0], info_t);
  f_st.site = &u_emlrtRSI;
  if (infocheck(&f_st, (int32_T)info_t)) {
    for (i = 0; i < 2048; i++) {
      b_B[i] = rtNaN;
    }
  }
  d_st.site = &r_emlrtRSI;
  for (i = 0; i < rankA; i++) {
    Y[jpvt[i] - 1] = b_B[i];
  }
  for (i = rankA; i >= 1; i--) {
    int32_T Y_tmp;
    int32_T b_Y_tmp;
    Y_tmp = jpvt[i - 1] - 1;
    b_Y_tmp = (i - 1) << 11;
    Y[Y_tmp] /= A[(i + b_Y_tmp) - 1];
    d_st.site = &s_emlrtRSI;
    for (b_i = 0; b_i <= i - 2; b_i++) {
      Y[jpvt[0] - 1] -= Y[Y_tmp] * A[b_Y_tmp];
    }
  }
}

void mldivide(const emlrtStack *sp, const real_T B[512], real_T Y[2])
{
  static const int32_T b_iv[2] = {1, 6};
  static const char_T rfmt[6] = {'%', '1', '4', '.', '6', 'e'};
  ptrdiff_t jpvt_t[2];
  ptrdiff_t info_t;
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack e_st;
  emlrtStack f_st;
  emlrtStack st;
  const mxArray *m;
  const mxArray *y;
  real_T A[1024];
  real_T b_B[512];
  real_T tau[2];
  real_T tol;
  int32_T jpvt[2];
  int32_T b_i;
  int32_T i;
  int32_T rankA;
  boolean_T p;
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
  st.site = &h_emlrtRSI;
  b_st.site = &i_emlrtRSI;
  c_st.site = &j_emlrtRSI;
  d_st.site = &m_emlrtRSI;
  memcpy(&A[0], &dv1[0], 1024U * sizeof(real_T));
  jpvt_t[0] = (ptrdiff_t)0;
  jpvt_t[1] = (ptrdiff_t)0;
  info_t = LAPACKE_dgeqp3(102, (ptrdiff_t)512, (ptrdiff_t)2, &A[0],
                          (ptrdiff_t)512, &jpvt_t[0], &tau[0]);
  e_st.site = &g_emlrtRSI;
  if ((int32_T)info_t != 0) {
    p = true;
    if ((int32_T)info_t != -4) {
      if ((int32_T)info_t == -1010) {
        emlrtErrorWithMessageIdR2018a(&e_st, &b_emlrtRTEI, "MATLAB:nomem",
                                      "MATLAB:nomem", 0);
      } else {
        emlrtErrorWithMessageIdR2018a(&e_st, &emlrtRTEI,
                                      "Coder:toolbox:LAPACKCallErrorInfo",
                                      "Coder:toolbox:LAPACKCallErrorInfo", 5, 4,
                                      14, &cv[0], 12, (int32_T)info_t);
      }
    }
  } else {
    p = false;
  }
  if (p) {
    for (i = 0; i < 1024; i++) {
      A[i] = rtNaN;
    }
    tau[0] = rtNaN;
    jpvt[0] = 1;
    tau[1] = rtNaN;
    jpvt[1] = 2;
  } else {
    jpvt[0] = (int32_T)jpvt_t[0];
    jpvt[1] = (int32_T)jpvt_t[1];
  }
  c_st.site = &k_emlrtRSI;
  rankA = 0;
  tol = 1.1368683772161603E-12 * muDoubleScalarAbs(A[0]);
  while ((rankA < 2) &&
         (!(muDoubleScalarAbs(A[rankA + (rankA << 9)]) <= tol))) {
    rankA++;
  }
  if ((rankA < 2) && (!emlrtSetWarningFlag(&c_st))) {
    char_T str[14];
    d_st.site = &o_emlrtRSI;
    y = NULL;
    m = emlrtCreateCharArray(2, &b_iv[0]);
    emlrtInitCharArrayR2013a(&d_st, 6, m, &rfmt[0]);
    emlrtAssign(&y, m);
    e_st.site = &kg_emlrtRSI;
    emlrt_marshallIn(&e_st,
                     b_sprintf(&e_st, y, emlrt_marshallOut(tol), &emlrtMCI),
                     "<output of sprintf>", str);
    d_st.site = &p_emlrtRSI;
    warning(&d_st, rankA, str);
  }
  c_st.site = &l_emlrtRSI;
  memcpy(&b_B[0], &B[0], 512U * sizeof(real_T));
  Y[0] = 0.0;
  Y[1] = 0.0;
  d_st.site = &q_emlrtRSI;
  e_st.site = &t_emlrtRSI;
  info_t = (ptrdiff_t)512;
  info_t = LAPACKE_dormqr(102, 'L', 'T', info_t, (ptrdiff_t)1, (ptrdiff_t)2,
                          &A[0], (ptrdiff_t)512, &tau[0], &b_B[0], info_t);
  f_st.site = &u_emlrtRSI;
  if (infocheck(&f_st, (int32_T)info_t)) {
    for (i = 0; i < 512; i++) {
      b_B[i] = rtNaN;
    }
  }
  d_st.site = &r_emlrtRSI;
  for (i = 0; i < rankA; i++) {
    Y[jpvt[i] - 1] = b_B[i];
  }
  for (i = rankA; i >= 1; i--) {
    int32_T Y_tmp;
    int32_T b_Y_tmp;
    Y_tmp = jpvt[i - 1] - 1;
    b_Y_tmp = (i - 1) << 9;
    Y[Y_tmp] /= A[(i + b_Y_tmp) - 1];
    d_st.site = &s_emlrtRSI;
    for (b_i = 0; b_i <= i - 2; b_i++) {
      Y[jpvt[0] - 1] -= Y[Y_tmp] * A[b_Y_tmp];
    }
  }
}

/* End of code generation (mldivide.c) */
