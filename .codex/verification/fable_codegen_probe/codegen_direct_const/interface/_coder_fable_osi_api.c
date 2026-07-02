/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_fable_osi_api.c
 *
 * Code generation for function '_coder_fable_osi_api'
 *
 */

/* Include files */
#include "_coder_fable_osi_api.h"
#include "fable_osi.h"
#include "fable_osi_data.h"
#include "fable_osi_mexutil.h"
#include "fable_osi_types.h"
#include "rt_nonfinite.h"

/* Function Declarations */
static real_T (*ab_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                    const emlrtMsgIdentifier *msgId))[256];

static const mxArray *b_emlrt_marshallOut(const emlrtStack *sp,
                                          const struct1_T *u);

static void bb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[2048]);

static real_T (*c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[256];

static const mxArray *c_emlrt_marshallOut(const real_T u[1683]);

static real_T cb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                  const emlrtMsgIdentifier *msgId);

static real_T (*d_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[256];

static const mxArray *d_emlrt_marshallOut(const real_T u[400]);

static void db_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[1683]);

static void e_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                               const char_T *identifier, struct1_T *y);

static const mxArray *e_emlrt_marshallOut(const real_T u[5]);

static void eb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                creal_T ret[1683]);

static void f_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               struct1_T *y);

static const mxArray *f_emlrt_marshallOut(const real_T u[75]);

static void fb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[7920]);

static void g_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[2048]);

static const mxArray *g_emlrt_marshallOut(const struct2_T *u);

static void gb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[80]);

static real_T h_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId);

static void hb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[400]);

static void i_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[1683]);

static void ib_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[320]);

static void j_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               creal_T y[1683]);

static boolean_T jb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId);

static void k_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[7920]);

static void kb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[99]);

static void l_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[80]);

static void lb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[5]);

static void m_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[400]);

static void mb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                boolean_T ret[99]);

static void n_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[320]);

static void nb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[3]);

static boolean_T o_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                    const emlrtMsgIdentifier *parentId);

static void ob_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[25]);

static void p_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[99]);

static void pb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                creal_T ret[25]);

static void q_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[5]);

static void qb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                boolean_T ret[25]);

static void r_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               boolean_T y[99]);

static void rb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[75]);

static void s_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[3]);

static void sb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                creal_T ret[75]);

static void t_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[25]);

static void u_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               creal_T y[25]);

static void v_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               boolean_T y[25]);

static void w_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[75]);

static void x_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               creal_T y[75]);

/* Function Definitions */
static real_T (*ab_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                    const emlrtMsgIdentifier *msgId))[256]
{
  static const int32_T dims = 256;
  real_T(*ret)[256];
  int32_T i;
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real_T(*)[256])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static const mxArray *b_emlrt_marshallOut(const emlrtStack *sp,
                                          const struct1_T *u)
{
  static const int32_T b_iv[2] = {99, 17};
  static const int32_T b_iv1[2] = {99, 80};
  static const int32_T iv2[2] = {25, 3};
  static const int32_T i = 2048;
  static const int32_T i1 = 2048;
  static const int32_T i10 = 25;
  static const int32_T i11 = 99;
  static const int32_T i12 = 99;
  static const int32_T i13 = 99;
  static const int32_T i14 = 25;
  static const int32_T i15 = 25;
  static const int32_T i3 = 80;
  static const int32_T i4 = 320;
  static const int32_T i5 = 99;
  static const int32_T i6 = 99;
  static const int32_T i7 = 99;
  static const int32_T i8 = 99;
  static const int32_T i9 = 3;
  static const char_T *sv[65] = {
      "xdd",         "xdm",           "samples_in",   "step_count",
      "hop_count",   "Suu_seg",       "Syy_seg",      "Suy_seg",
      "seg_count",   "ring_pos",      "update_count", "cal_res",
      "cal_med",     "cal_pf",        "cal_d",        "cal_d_count",
      "cal_count",   "cal_tries",     "cal_rejects",  "ready",
      "baseline",    "baseline0",     "mu0",          "sigma0",
      "mu_pf",       "mu_pf0",        "sig_pf",       "mu_d",
      "mu_d0",       "sig_d",         "res_on",       "res_count",
      "res_age",     "res_freq",      "regime_mask",  "regime_count",
      "sb_ndiff",    "recal_pending", "slow_hist",    "detected",
      "detect_step", "sb_b",          "sb_st",        "sb_res",
      "sb_fst",      "sb_fres",       "sb_zmax",      "sb_stvalid",
      "sb_nexc",     "sb_predvalid",  "sb_pred",      "sb_excited",
      "sb_quiet",    "sb_qpmask",     "sb_Tsf",       "sb_Tsf_valid",
      "b_slow_filt", "fSuu",          "fSyy",         "fSuy",
      "fseg_count",  "fring_pos",     "p_in_ema",     "cus_st",
      "cus_burst"};
  const mxArray *b_y;
  const mxArray *c_y;
  const mxArray *d_y;
  const mxArray *e_y;
  const mxArray *f_y;
  const mxArray *g_y;
  const mxArray *h_y;
  const mxArray *i_y;
  const mxArray *j_y;
  const mxArray *k_y;
  const mxArray *l_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *n_y;
  const mxArray *o_y;
  const mxArray *p_y;
  const mxArray *q_y;
  const mxArray *r_y;
  const mxArray *s_y;
  const mxArray *t_y;
  const mxArray *u_y;
  const mxArray *v_y;
  const mxArray *w_y;
  const mxArray *x_y;
  const mxArray *y;
  const mxArray *y_y;
  real_T *pData;
  int32_T b_i;
  int32_T c_i;
  int32_T i2;
  y = NULL;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 65, (const char_T **)&sv[0]));
  b_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 2048; b_i++) {
    pData[b_i] = u->xdd[b_i];
  }
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "xdd", b_y, 0);
  c_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i1, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 2048; b_i++) {
    pData[b_i] = u->xdm[b_i];
  }
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "xdm", c_y, 1);
  emlrtSetFieldR2017b(y, 0, "samples_in", emlrt_marshallOut(u->samples_in), 2);
  emlrtSetFieldR2017b(y, 0, "step_count", emlrt_marshallOut(u->step_count), 3);
  emlrtSetFieldR2017b(y, 0, "hop_count", emlrt_marshallOut(u->hop_count), 4);
  emlrtSetFieldR2017b(y, 0, "Suu_seg", c_emlrt_marshallOut(u->Suu_seg), 5);
  emlrtSetFieldR2017b(y, 0, "Syy_seg", c_emlrt_marshallOut(u->Syy_seg), 6);
  d_y = NULL;
  m = emlrtCreateNumericArray(2, (const void *)&b_iv[0], mxDOUBLE_CLASS,
                              mxCOMPLEX);
  emlrtExportNumericArrayR2013b((emlrtConstCTX)sp, m, &u->Suy_seg[0], 8);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "Suy_seg", d_y, 7);
  emlrtSetFieldR2017b(y, 0, "seg_count", emlrt_marshallOut(u->seg_count), 8);
  emlrtSetFieldR2017b(y, 0, "ring_pos", emlrt_marshallOut(u->ring_pos), 9);
  emlrtSetFieldR2017b(y, 0, "update_count", emlrt_marshallOut(u->update_count),
                      10);
  e_y = NULL;
  m = emlrtCreateNumericArray(2, (const void *)&b_iv1[0], mxDOUBLE_CLASS,
                              mxREAL);
  pData = emlrtMxGetPr(m);
  i2 = 0;
  for (b_i = 0; b_i < 80; b_i++) {
    for (c_i = 0; c_i < 99; c_i++) {
      pData[i2 + c_i] = u->cal_res[c_i + 99 * b_i];
    }
    i2 += 99;
  }
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "cal_res", e_y, 11);
  f_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i3, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 80; b_i++) {
    pData[b_i] = u->cal_med[b_i];
  }
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "cal_med", f_y, 12);
  emlrtSetFieldR2017b(y, 0, "cal_pf", d_emlrt_marshallOut(u->cal_pf), 13);
  g_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i4, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 320; b_i++) {
    pData[b_i] = u->cal_d[b_i];
  }
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "cal_d", g_y, 14);
  emlrtSetFieldR2017b(y, 0, "cal_d_count", emlrt_marshallOut(u->cal_d_count),
                      15);
  emlrtSetFieldR2017b(y, 0, "cal_count", emlrt_marshallOut(u->cal_count), 16);
  emlrtSetFieldR2017b(y, 0, "cal_tries", emlrt_marshallOut(u->cal_tries), 17);
  emlrtSetFieldR2017b(y, 0, "cal_rejects", emlrt_marshallOut(u->cal_rejects),
                      18);
  h_y = NULL;
  m = emlrtCreateLogicalScalar(u->ready);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "ready", h_y, 19);
  i_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i5, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 99; b_i++) {
    pData[b_i] = u->baseline[b_i];
  }
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "baseline", i_y, 20);
  j_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i6, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 99; b_i++) {
    pData[b_i] = u->baseline0[b_i];
  }
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "baseline0", j_y, 21);
  k_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i7, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 99; b_i++) {
    pData[b_i] = u->mu0[b_i];
  }
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "mu0", k_y, 22);
  emlrtSetFieldR2017b(y, 0, "sigma0", emlrt_marshallOut(u->sigma0), 23);
  emlrtSetFieldR2017b(y, 0, "mu_pf", e_emlrt_marshallOut(u->mu_pf), 24);
  emlrtSetFieldR2017b(y, 0, "mu_pf0", e_emlrt_marshallOut(u->mu_pf0), 25);
  emlrtSetFieldR2017b(y, 0, "sig_pf", e_emlrt_marshallOut(u->sig_pf), 26);
  emlrtSetFieldR2017b(y, 0, "mu_d", emlrt_marshallOut(u->mu_d), 27);
  emlrtSetFieldR2017b(y, 0, "mu_d0", emlrt_marshallOut(u->mu_d0), 28);
  emlrtSetFieldR2017b(y, 0, "sig_d", emlrt_marshallOut(u->sig_d), 29);
  l_y = NULL;
  m = emlrtCreateLogicalScalar(u->res_on);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "res_on", l_y, 30);
  emlrtSetFieldR2017b(y, 0, "res_count", emlrt_marshallOut(u->res_count), 31);
  emlrtSetFieldR2017b(y, 0, "res_age", emlrt_marshallOut(u->res_age), 32);
  emlrtSetFieldR2017b(y, 0, "res_freq", emlrt_marshallOut(u->res_freq), 33);
  m_y = NULL;
  m = emlrtCreateLogicalArray(1, &i8);
  emlrtInitLogicalArray(99, m, &u->regime_mask[0]);
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(y, 0, "regime_mask", m_y, 34);
  emlrtSetFieldR2017b(y, 0, "regime_count", emlrt_marshallOut(u->regime_count),
                      35);
  emlrtSetFieldR2017b(y, 0, "sb_ndiff", emlrt_marshallOut(u->sb_ndiff), 36);
  n_y = NULL;
  m = emlrtCreateLogicalScalar(u->recal_pending);
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(y, 0, "recal_pending", n_y, 37);
  o_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i9, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u->slow_hist[0];
  pData[1] = u->slow_hist[1];
  pData[2] = u->slow_hist[2];
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(y, 0, "slow_hist", o_y, 38);
  p_y = NULL;
  m = emlrtCreateLogicalScalar(u->detected);
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(y, 0, "detected", p_y, 39);
  emlrtSetFieldR2017b(y, 0, "detect_step", emlrt_marshallOut(u->detect_step),
                      40);
  emlrtSetFieldR2017b(y, 0, "sb_b", emlrt_marshallOut(u->sb_b), 41);
  emlrtSetFieldR2017b(y, 0, "sb_st", emlrt_marshallOut(u->sb_st), 42);
  emlrtSetFieldR2017b(y, 0, "sb_res", emlrt_marshallOut(u->sb_res), 43);
  emlrtSetFieldR2017b(y, 0, "sb_fst", emlrt_marshallOut(u->sb_fst), 44);
  emlrtSetFieldR2017b(y, 0, "sb_fres", emlrt_marshallOut(u->sb_fres), 45);
  emlrtSetFieldR2017b(y, 0, "sb_zmax", emlrt_marshallOut(u->sb_zmax), 46);
  q_y = NULL;
  m = emlrtCreateLogicalScalar(u->sb_stvalid);
  emlrtAssign(&q_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_stvalid", q_y, 47);
  emlrtSetFieldR2017b(y, 0, "sb_nexc", emlrt_marshallOut(u->sb_nexc), 48);
  r_y = NULL;
  m = emlrtCreateLogicalScalar(u->sb_predvalid);
  emlrtAssign(&r_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_predvalid", r_y, 49);
  s_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i10, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 25; b_i++) {
    pData[b_i] = u->sb_pred[b_i];
  }
  emlrtAssign(&s_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_pred", s_y, 50);
  t_y = NULL;
  m = emlrtCreateLogicalArray(1, &i11);
  emlrtInitLogicalArray(99, m, &u->sb_excited[0]);
  emlrtAssign(&t_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_excited", t_y, 51);
  u_y = NULL;
  m = emlrtCreateLogicalArray(1, &i12);
  emlrtInitLogicalArray(99, m, &u->sb_quiet[0]);
  emlrtAssign(&u_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_quiet", u_y, 52);
  v_y = NULL;
  m = emlrtCreateLogicalArray(1, &i13);
  emlrtInitLogicalArray(99, m, &u->sb_qpmask[0]);
  emlrtAssign(&v_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_qpmask", v_y, 53);
  w_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i14, mxDOUBLE_CLASS, mxCOMPLEX);
  emlrtExportNumericArrayR2013b((emlrtConstCTX)sp, m, &u->sb_Tsf[0], 8);
  emlrtAssign(&w_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_Tsf", w_y, 54);
  x_y = NULL;
  m = emlrtCreateLogicalArray(1, &i15);
  emlrtInitLogicalArray(25, m, &u->sb_Tsf_valid[0]);
  emlrtAssign(&x_y, m);
  emlrtSetFieldR2017b(y, 0, "sb_Tsf_valid", x_y, 55);
  emlrtSetFieldR2017b(y, 0, "b_slow_filt", emlrt_marshallOut(u->b_slow_filt),
                      56);
  emlrtSetFieldR2017b(y, 0, "fSuu", f_emlrt_marshallOut(u->fSuu), 57);
  emlrtSetFieldR2017b(y, 0, "fSyy", f_emlrt_marshallOut(u->fSyy), 58);
  y_y = NULL;
  m = emlrtCreateNumericArray(2, (const void *)&iv2[0], mxDOUBLE_CLASS,
                              mxCOMPLEX);
  emlrtExportNumericArrayR2013b((emlrtConstCTX)sp, m, &u->fSuy[0], 8);
  emlrtAssign(&y_y, m);
  emlrtSetFieldR2017b(y, 0, "fSuy", y_y, 59);
  emlrtSetFieldR2017b(y, 0, "fseg_count", emlrt_marshallOut(u->fseg_count), 60);
  emlrtSetFieldR2017b(y, 0, "fring_pos", emlrt_marshallOut(u->fring_pos), 61);
  emlrtSetFieldR2017b(y, 0, "p_in_ema", emlrt_marshallOut(u->p_in_ema), 62);
  emlrtSetFieldR2017b(y, 0, "cus_st", emlrt_marshallOut(u->cus_st), 63);
  emlrtSetFieldR2017b(y, 0, "cus_burst", e_emlrt_marshallOut(u->cus_burst), 64);
  return y;
}

static void bb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[2048])
{
  static const int32_T dims = 2048;
  real_T(*r)[2048];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[2048])emlrtMxGetData(src);
  for (i = 0; i < 2048; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static real_T (*c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[256]
{
  emlrtMsgIdentifier thisId;
  real_T(*y)[256];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = d_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static const mxArray *c_emlrt_marshallOut(const real_T u[1683])
{
  static const int32_T b_iv[2] = {99, 17};
  const mxArray *m;
  const mxArray *y;
  real_T *pData;
  int32_T b_i;
  int32_T c_i;
  int32_T i;
  y = NULL;
  m = emlrtCreateNumericArray(2, (const void *)&b_iv[0], mxDOUBLE_CLASS,
                              mxREAL);
  pData = emlrtMxGetPr(m);
  i = 0;
  for (b_i = 0; b_i < 17; b_i++) {
    for (c_i = 0; c_i < 99; c_i++) {
      pData[i + c_i] = u[c_i + 99 * b_i];
    }
    i += 99;
  }
  emlrtAssign(&y, m);
  return y;
}

static real_T cb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                  const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims = 0;
  real_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 0U,
                          (const void *)&dims);
  ret = *(real_T *)emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real_T (*d_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[256]
{
  real_T(*y)[256];
  y = ab_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static const mxArray *d_emlrt_marshallOut(const real_T u[400])
{
  static const int32_T b_iv[2] = {5, 80};
  const mxArray *m;
  const mxArray *y;
  real_T *pData;
  int32_T b_i;
  int32_T c_i;
  int32_T i;
  y = NULL;
  m = emlrtCreateNumericArray(2, (const void *)&b_iv[0], mxDOUBLE_CLASS,
                              mxREAL);
  pData = emlrtMxGetPr(m);
  i = 0;
  for (b_i = 0; b_i < 80; b_i++) {
    for (c_i = 0; c_i < 5; c_i++) {
      pData[i + c_i] = u[c_i + 5 * b_i];
    }
    i += 5;
  }
  emlrtAssign(&y, m);
  return y;
}

static void db_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[1683])
{
  static const int32_T dims[2] = {99, 17};
  real_T(*r)[1683];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 2U,
                          (const void *)&dims[0]);
  r = (real_T(*)[1683])emlrtMxGetData(src);
  for (i = 0; i < 1683; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void e_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                               const char_T *identifier, struct1_T *y)
{
  emlrtMsgIdentifier thisId;
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  f_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId, y);
  emlrtDestroyArray(&nullptr);
}

static const mxArray *e_emlrt_marshallOut(const real_T u[5])
{
  static const int32_T i = 5;
  const mxArray *m;
  const mxArray *y;
  real_T *pData;
  int32_T b_i;
  y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 5; b_i++) {
    pData[b_i] = u[b_i];
  }
  emlrtAssign(&y, m);
  return y;
}

static void eb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                creal_T ret[1683])
{
  static const int32_T dims[2] = {99, 17};
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", true, 2U,
                          (const void *)&dims[0]);
  emlrtImportArrayR2015b((emlrtConstCTX)sp, src, &ret[0], 8, true);
  emlrtDestroyArray(&src);
}

static void f_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, struct1_T *y)
{
  static const int32_T dims = 0;
  static const char_T *fieldNames[65] = {
      "xdd",         "xdm",           "samples_in",   "step_count",
      "hop_count",   "Suu_seg",       "Syy_seg",      "Suy_seg",
      "seg_count",   "ring_pos",      "update_count", "cal_res",
      "cal_med",     "cal_pf",        "cal_d",        "cal_d_count",
      "cal_count",   "cal_tries",     "cal_rejects",  "ready",
      "baseline",    "baseline0",     "mu0",          "sigma0",
      "mu_pf",       "mu_pf0",        "sig_pf",       "mu_d",
      "mu_d0",       "sig_d",         "res_on",       "res_count",
      "res_age",     "res_freq",      "regime_mask",  "regime_count",
      "sb_ndiff",    "recal_pending", "slow_hist",    "detected",
      "detect_step", "sb_b",          "sb_st",        "sb_res",
      "sb_fst",      "sb_fres",       "sb_zmax",      "sb_stvalid",
      "sb_nexc",     "sb_predvalid",  "sb_pred",      "sb_excited",
      "sb_quiet",    "sb_qpmask",     "sb_Tsf",       "sb_Tsf_valid",
      "b_slow_filt", "fSuu",          "fSyy",         "fSuy",
      "fseg_count",  "fring_pos",     "p_in_ema",     "cus_st",
      "cus_burst"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)sp, parentId, u, 65,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "xdd";
  g_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 0, "xdd")),
      &thisId, y->xdd);
  thisId.fIdentifier = "xdm";
  g_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 1, "xdm")),
      &thisId, y->xdm);
  thisId.fIdentifier = "samples_in";
  y->samples_in = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 2, "samples_in")),
      &thisId);
  thisId.fIdentifier = "step_count";
  y->step_count = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 3, "step_count")),
      &thisId);
  thisId.fIdentifier = "hop_count";
  y->hop_count = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 4, "hop_count")),
      &thisId);
  thisId.fIdentifier = "Suu_seg";
  i_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 5, "Suu_seg")),
      &thisId, y->Suu_seg);
  thisId.fIdentifier = "Syy_seg";
  i_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 6, "Syy_seg")),
      &thisId, y->Syy_seg);
  thisId.fIdentifier = "Suy_seg";
  j_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 7, "Suy_seg")),
      &thisId, y->Suy_seg);
  thisId.fIdentifier = "seg_count";
  y->seg_count = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 8, "seg_count")),
      &thisId);
  thisId.fIdentifier = "ring_pos";
  y->ring_pos = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 9, "ring_pos")),
      &thisId);
  thisId.fIdentifier = "update_count";
  y->update_count =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        10, "update_count")),
                         &thisId);
  thisId.fIdentifier = "cal_res";
  k_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 11, "cal_res")),
      &thisId, y->cal_res);
  thisId.fIdentifier = "cal_med";
  l_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 12, "cal_med")),
      &thisId, y->cal_med);
  thisId.fIdentifier = "cal_pf";
  m_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 13, "cal_pf")),
      &thisId, y->cal_pf);
  thisId.fIdentifier = "cal_d";
  n_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 14, "cal_d")),
      &thisId, y->cal_d);
  thisId.fIdentifier = "cal_d_count";
  y->cal_d_count =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        15, "cal_d_count")),
                         &thisId);
  thisId.fIdentifier = "cal_count";
  y->cal_count = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 16, "cal_count")),
      &thisId);
  thisId.fIdentifier = "cal_tries";
  y->cal_tries = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 17, "cal_tries")),
      &thisId);
  thisId.fIdentifier = "cal_rejects";
  y->cal_rejects =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        18, "cal_rejects")),
                         &thisId);
  thisId.fIdentifier = "ready";
  y->ready = o_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 19, "ready")),
      &thisId);
  thisId.fIdentifier = "baseline";
  p_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 20, "baseline")),
      &thisId, y->baseline);
  thisId.fIdentifier = "baseline0";
  p_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 21, "baseline0")),
      &thisId, y->baseline0);
  thisId.fIdentifier = "mu0";
  p_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 22, "mu0")),
      &thisId, y->mu0);
  thisId.fIdentifier = "sigma0";
  y->sigma0 = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 23, "sigma0")),
      &thisId);
  thisId.fIdentifier = "mu_pf";
  q_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 24, "mu_pf")),
      &thisId, y->mu_pf);
  thisId.fIdentifier = "mu_pf0";
  q_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 25, "mu_pf0")),
      &thisId, y->mu_pf0);
  thisId.fIdentifier = "sig_pf";
  q_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 26, "sig_pf")),
      &thisId, y->sig_pf);
  thisId.fIdentifier = "mu_d";
  y->mu_d = h_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 27, "mu_d")),
      &thisId);
  thisId.fIdentifier = "mu_d0";
  y->mu_d0 = h_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 28, "mu_d0")),
      &thisId);
  thisId.fIdentifier = "sig_d";
  y->sig_d = h_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 29, "sig_d")),
      &thisId);
  thisId.fIdentifier = "res_on";
  y->res_on = o_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 30, "res_on")),
      &thisId);
  thisId.fIdentifier = "res_count";
  y->res_count = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 31, "res_count")),
      &thisId);
  thisId.fIdentifier = "res_age";
  y->res_age = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 32, "res_age")),
      &thisId);
  thisId.fIdentifier = "res_freq";
  y->res_freq = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 33, "res_freq")),
      &thisId);
  thisId.fIdentifier = "regime_mask";
  r_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 34,
                                                    "regime_mask")),
                     &thisId, y->regime_mask);
  thisId.fIdentifier = "regime_count";
  y->regime_count =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        35, "regime_count")),
                         &thisId);
  thisId.fIdentifier = "sb_ndiff";
  y->sb_ndiff = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 36, "sb_ndiff")),
      &thisId);
  thisId.fIdentifier = "recal_pending";
  y->recal_pending =
      o_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        37, "recal_pending")),
                         &thisId);
  thisId.fIdentifier = "slow_hist";
  s_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 38, "slow_hist")),
      &thisId, y->slow_hist);
  thisId.fIdentifier = "detected";
  y->detected = o_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 39, "detected")),
      &thisId);
  thisId.fIdentifier = "detect_step";
  y->detect_step =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        40, "detect_step")),
                         &thisId);
  thisId.fIdentifier = "sb_b";
  y->sb_b = h_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 41, "sb_b")),
      &thisId);
  thisId.fIdentifier = "sb_st";
  y->sb_st = h_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 42, "sb_st")),
      &thisId);
  thisId.fIdentifier = "sb_res";
  y->sb_res = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 43, "sb_res")),
      &thisId);
  thisId.fIdentifier = "sb_fst";
  y->sb_fst = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 44, "sb_fst")),
      &thisId);
  thisId.fIdentifier = "sb_fres";
  y->sb_fres = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 45, "sb_fres")),
      &thisId);
  thisId.fIdentifier = "sb_zmax";
  y->sb_zmax = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 46, "sb_zmax")),
      &thisId);
  thisId.fIdentifier = "sb_stvalid";
  y->sb_stvalid =
      o_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        47, "sb_stvalid")),
                         &thisId);
  thisId.fIdentifier = "sb_nexc";
  y->sb_nexc = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 48, "sb_nexc")),
      &thisId);
  thisId.fIdentifier = "sb_predvalid";
  y->sb_predvalid =
      o_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        49, "sb_predvalid")),
                         &thisId);
  thisId.fIdentifier = "sb_pred";
  t_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 50, "sb_pred")),
      &thisId, y->sb_pred);
  thisId.fIdentifier = "sb_excited";
  r_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 51,
                                                    "sb_excited")),
                     &thisId, y->sb_excited);
  thisId.fIdentifier = "sb_quiet";
  r_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 52, "sb_quiet")),
      &thisId, y->sb_quiet);
  thisId.fIdentifier = "sb_qpmask";
  r_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 53, "sb_qpmask")),
      &thisId, y->sb_qpmask);
  thisId.fIdentifier = "sb_Tsf";
  u_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 54, "sb_Tsf")),
      &thisId, y->sb_Tsf);
  thisId.fIdentifier = "sb_Tsf_valid";
  v_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 55,
                                                    "sb_Tsf_valid")),
                     &thisId, y->sb_Tsf_valid);
  thisId.fIdentifier = "b_slow_filt";
  y->b_slow_filt =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        56, "b_slow_filt")),
                         &thisId);
  thisId.fIdentifier = "fSuu";
  w_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 57, "fSuu")),
      &thisId, y->fSuu);
  thisId.fIdentifier = "fSyy";
  w_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 58, "fSyy")),
      &thisId, y->fSyy);
  thisId.fIdentifier = "fSuy";
  x_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 59, "fSuy")),
      &thisId, y->fSuy);
  thisId.fIdentifier = "fseg_count";
  y->fseg_count =
      h_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0,
                                                        60, "fseg_count")),
                         &thisId);
  thisId.fIdentifier = "fring_pos";
  y->fring_pos = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 61, "fring_pos")),
      &thisId);
  thisId.fIdentifier = "p_in_ema";
  y->p_in_ema = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 62, "p_in_ema")),
      &thisId);
  thisId.fIdentifier = "cus_st";
  y->cus_st = h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 63, "cus_st")),
      &thisId);
  thisId.fIdentifier = "cus_burst";
  q_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)sp, u, 0, 64, "cus_burst")),
      &thisId, y->cus_burst);
  emlrtDestroyArray(&u);
}

static const mxArray *f_emlrt_marshallOut(const real_T u[75])
{
  static const int32_T b_iv[2] = {25, 3};
  const mxArray *m;
  const mxArray *y;
  real_T *pData;
  int32_T b_i;
  int32_T c_i;
  int32_T i;
  y = NULL;
  m = emlrtCreateNumericArray(2, (const void *)&b_iv[0], mxDOUBLE_CLASS,
                              mxREAL);
  pData = emlrtMxGetPr(m);
  i = 0;
  for (b_i = 0; b_i < 3; b_i++) {
    for (c_i = 0; c_i < 25; c_i++) {
      pData[i + c_i] = u[c_i + 25 * b_i];
    }
    i += 25;
  }
  emlrtAssign(&y, m);
  return y;
}

static void fb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[7920])
{
  static const int32_T dims[2] = {99, 80};
  real_T(*r)[7920];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 2U,
                          (const void *)&dims[0]);
  r = (real_T(*)[7920])emlrtMxGetData(src);
  for (i = 0; i < 7920; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void g_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[2048])
{
  bb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static const mxArray *g_emlrt_marshallOut(const struct2_T *u)
{
  static const int32_T i = 25;
  static const int32_T i1 = 25;
  static const char_T *sv[24] = {
      "margin",      "valid",          "ncf_st",      "st_valid",
      "f_st_hz",     "n_excited",      "ncf_res",     "f_res_hz",
      "z_max",       "res_on",         "b_fast",      "fast_trip",
      "trip_reason", "baseline_ready", "pred_margin", "pred_valid",
      "alpha_grid",  "nominal",        "nominal_hz",  "detected",
      "detect_step", "st_binding",     "z_fast",      "regime_recal"};
  const mxArray *b_y;
  const mxArray *c_y;
  const mxArray *d_y;
  const mxArray *e_y;
  const mxArray *f_y;
  const mxArray *g_y;
  const mxArray *h_y;
  const mxArray *i_y;
  const mxArray *j_y;
  const mxArray *k_y;
  const mxArray *l_y;
  const mxArray *m;
  const mxArray *y;
  real_T *pData;
  int32_T b_i;
  y = NULL;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 24, (const char_T **)&sv[0]));
  emlrtSetFieldR2017b(y, 0, "margin", emlrt_marshallOut(u->margin), 0);
  b_y = NULL;
  m = emlrtCreateLogicalScalar(u->valid);
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "valid", b_y, 1);
  emlrtSetFieldR2017b(y, 0, "ncf_st", emlrt_marshallOut(u->ncf_st), 2);
  c_y = NULL;
  m = emlrtCreateLogicalScalar(u->st_valid);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "st_valid", c_y, 3);
  emlrtSetFieldR2017b(y, 0, "f_st_hz", emlrt_marshallOut(u->f_st_hz), 4);
  emlrtSetFieldR2017b(y, 0, "n_excited", emlrt_marshallOut(u->n_excited), 5);
  emlrtSetFieldR2017b(y, 0, "ncf_res", emlrt_marshallOut(u->ncf_res), 6);
  emlrtSetFieldR2017b(y, 0, "f_res_hz", emlrt_marshallOut(u->f_res_hz), 7);
  emlrtSetFieldR2017b(y, 0, "z_max", emlrt_marshallOut(u->z_max), 8);
  d_y = NULL;
  m = emlrtCreateLogicalScalar(u->res_on);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "res_on", d_y, 9);
  emlrtSetFieldR2017b(y, 0, "b_fast", emlrt_marshallOut(u->b_fast), 10);
  e_y = NULL;
  m = emlrtCreateLogicalScalar(u->fast_trip);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "fast_trip", e_y, 11);
  emlrtSetFieldR2017b(y, 0, "trip_reason", emlrt_marshallOut(u->trip_reason),
                      12);
  f_y = NULL;
  m = emlrtCreateLogicalScalar(u->baseline_ready);
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "baseline_ready", f_y, 13);
  g_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 25; b_i++) {
    pData[b_i] = u->pred_margin[b_i];
  }
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "pred_margin", g_y, 14);
  h_y = NULL;
  m = emlrtCreateLogicalScalar(u->pred_valid);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "pred_valid", h_y, 15);
  i_y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i1, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (b_i = 0; b_i < 25; b_i++) {
    pData[b_i] = u->alpha_grid[b_i];
  }
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "alpha_grid", i_y, 16);
  emlrtSetFieldR2017b(y, 0, "nominal", emlrt_marshallOut(u->nominal), 17);
  emlrtSetFieldR2017b(y, 0, "nominal_hz", emlrt_marshallOut(u->nominal_hz), 18);
  j_y = NULL;
  m = emlrtCreateLogicalScalar(u->detected);
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "detected", j_y, 19);
  emlrtSetFieldR2017b(y, 0, "detect_step", emlrt_marshallOut(u->detect_step),
                      20);
  k_y = NULL;
  m = emlrtCreateLogicalScalar(u->st_binding);
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "st_binding", k_y, 21);
  emlrtSetFieldR2017b(y, 0, "z_fast", emlrt_marshallOut(u->z_fast), 22);
  l_y = NULL;
  m = emlrtCreateLogicalScalar(u->regime_recal);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "regime_recal", l_y, 23);
  return y;
}

static void gb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[80])
{
  static const int32_T dims = 80;
  real_T(*r)[80];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[80])emlrtMxGetData(src);
  for (i = 0; i < 80; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static real_T h_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId)
{
  real_T y;
  y = cb_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static void hb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[400])
{
  static const int32_T dims[2] = {5, 80};
  real_T(*r)[400];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 2U,
                          (const void *)&dims[0]);
  r = (real_T(*)[400])emlrtMxGetData(src);
  for (i = 0; i < 400; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void i_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[1683])
{
  db_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void ib_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                real_T ret[320])
{
  static const int32_T dims = 320;
  real_T(*r)[320];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[320])emlrtMxGetData(src);
  for (i = 0; i < 320; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void j_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               creal_T y[1683])
{
  eb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static boolean_T jb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims = 0;
  boolean_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "logical", false, 0U,
                          (const void *)&dims);
  ret = *emlrtMxGetLogicals(src);
  emlrtDestroyArray(&src);
  return ret;
}

static void k_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[7920])
{
  fb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void kb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[99])
{
  static const int32_T dims = 99;
  real_T(*r)[99];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[99])emlrtMxGetData(src);
  for (i = 0; i < 99; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void l_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[80])
{
  gb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void lb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[5])
{
  static const int32_T dims = 5;
  real_T(*r)[5];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[5])emlrtMxGetData(src);
  for (i = 0; i < 5; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void m_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[400])
{
  hb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void mb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                boolean_T ret[99])
{
  static const int32_T dims = 99;
  int32_T i;
  boolean_T(*r)[99];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "logical", false, 1U,
                          (const void *)&dims);
  r = (boolean_T(*)[99])emlrtMxGetLogicals(src);
  for (i = 0; i < 99; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void n_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[320])
{
  ib_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void nb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[3])
{
  static const int32_T dims = 3;
  real_T(*r)[3];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[3])emlrtMxGetData(src);
  ret[0] = (*r)[0];
  ret[1] = (*r)[1];
  ret[2] = (*r)[2];
  emlrtDestroyArray(&src);
}

static boolean_T o_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                    const emlrtMsgIdentifier *parentId)
{
  boolean_T y;
  y = jb_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static void ob_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[25])
{
  static const int32_T dims = 25;
  real_T(*r)[25];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[25])emlrtMxGetData(src);
  for (i = 0; i < 25; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void p_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[99])
{
  kb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void pb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                creal_T ret[25])
{
  static const int32_T dims = 25;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", true, 1U,
                          (const void *)&dims);
  emlrtImportArrayR2015b((emlrtConstCTX)sp, src, &ret[0], 8, true);
  emlrtDestroyArray(&src);
}

static void q_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[5])
{
  lb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void qb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                boolean_T ret[25])
{
  static const int32_T dims = 25;
  int32_T i;
  boolean_T(*r)[25];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "logical", false, 1U,
                          (const void *)&dims);
  r = (boolean_T(*)[25])emlrtMxGetLogicals(src);
  for (i = 0; i < 25; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void r_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               boolean_T y[99])
{
  mb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void rb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId, real_T ret[75])
{
  static const int32_T dims[2] = {25, 3};
  real_T(*r)[75];
  int32_T i;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 2U,
                          (const void *)&dims[0]);
  r = (real_T(*)[75])emlrtMxGetData(src);
  for (i = 0; i < 75; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

static void s_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[3])
{
  nb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void sb_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                const emlrtMsgIdentifier *msgId,
                                creal_T ret[75])
{
  static const int32_T dims[2] = {25, 3};
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", true, 2U,
                          (const void *)&dims[0]);
  emlrtImportArrayR2015b((emlrtConstCTX)sp, src, &ret[0], 8, true);
  emlrtDestroyArray(&src);
}

static void t_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[25])
{
  ob_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void u_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               creal_T y[25])
{
  pb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void v_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               boolean_T y[25])
{
  qb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void w_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[75])
{
  rb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

static void x_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               creal_T y[75])
{
  sb_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

void fable_osi_api(fable_osiStackData *SD, const mxArray *const prhs[4],
                   int32_T nlhs, const mxArray *plhs[3])
{
  static const uint32_T uv[4] = {175678881U, 639523579U, 3001030313U,
                                 2962216001U};
  static const char_T *s = "varargin_3";
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  struct2_T info;
  real_T(*varargin_1)[256];
  real_T(*varargin_2)[256];
  real_T out;
  int32_T i;
  st.tls = emlrtRootTLSGlobal;
  /* Check constant function inputs */
  i = 4;
  emlrtCheckArrayChecksumR2018b(&st, prhs[2], false, &i, (const char_T **)&s,
                                &uv[0]);
  /* Marshall function inputs */
  varargin_1 = c_emlrt_marshallIn(&st, emlrtAlias(prhs[0]), "varargin_1");
  varargin_2 = c_emlrt_marshallIn(&st, emlrtAlias(prhs[1]), "varargin_2");
  e_emlrt_marshallIn(&st, emlrtAliasP(prhs[3]), "varargin_4",
                     &SD->f0.varargin_4);
  /* Invoke the target function */
  fable_osi(&st, *varargin_1, *varargin_2, &SD->f0.varargin_4, &out,
            &SD->f0.state, &info);
  /* Marshall function outputs */
  plhs[0] = emlrt_marshallOut(out);
  if (nlhs > 1) {
    plhs[1] = b_emlrt_marshallOut(&st, &SD->f0.state);
  }
  if (nlhs > 2) {
    plhs[2] = g_emlrt_marshallOut(&info);
  }
}

/* End of code generation (_coder_fable_osi_api.c) */
