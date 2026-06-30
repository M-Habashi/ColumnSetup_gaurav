/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_auth_stability_gain_api.c
 *
 * Code generation for function 'auth_stability_gain'
 *
 */

/* Include files */
#include "_coder_auth_stability_gain_api.h"
#include "_coder_auth_stability_gain_mex.h"

/* Variable Definitions */
emlrtCTX emlrtRootTLSGlobal = NULL;

emlrtContext emlrtContextGlobal = {
    true,                                                 /* bFirstTime */
    false,                                                /* bInitialized */
    131675U,                                              /* fVersionInfo */
    NULL,                                                 /* fErrorFunction */
    "auth_stability_gain",                                /* fFunctionName */
    NULL,                                                 /* fRTCallStack */
    false,                                                /* bDebugMode */
    {2045744189U, 2170104910U, 2743257031U, 4284093946U}, /* fSigWrd */
    NULL                                                  /* fSigMem */
};

/* Function Declarations */
static real_T b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId);

static real_T c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                 const emlrtMsgIdentifier *msgId);

static void emlrtExitTimeCleanupDtorFcn(const void *r);

static real_T emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                               const char_T *identifier);

static const mxArray *emlrt_marshallOut(const real_T u);

/* Function Definitions */
static real_T b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId)
{
  real_T y;
  y = c_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real_T c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
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

static void emlrtExitTimeCleanupDtorFcn(const void *r)
{
  emlrtExitTimeCleanup(&emlrtContextGlobal);
}

static real_T emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                               const char_T *identifier)
{
  emlrtMsgIdentifier thisId;
  real_T y;
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = b_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static const mxArray *emlrt_marshallOut(const real_T u)
{
  const mxArray *m;
  const mxArray *y;
  y = NULL;
  m = emlrtCreateDoubleScalar(u);
  emlrtAssign(&y, m);
  return y;
}

void auth_stability_gain_api(const mxArray *const prhs[22], int32_T nlhs,
                             const mxArray *plhs[6])
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  real_T a_max;
  real_T a_min;
  real_T above_count;
  real_T above_count_next;
  real_T authority;
  real_T authority_next;
  real_T below_count;
  real_T below_count_next;
  real_T down_confirm_n;
  real_T down_confirmed;
  real_T down_deadband;
  real_T down_immediate_margin;
  real_T down_rate;
  real_T m91_margin;
  real_T margin_filter_alpha;
  real_T margin_filtered;
  real_T margin_filtered_next;
  real_T margin_guard_down_rate;
  real_T margin_guard_up_rate;
  real_T margin_guarded;
  real_T margin_guarded_next;
  real_T power_law;
  real_T smooth_down;
  real_T target_margin;
  real_T up_deadband;
  real_T up_hold_s;
  real_T up_rate;
  real_T update_interval_s;
  st.tls = emlrtRootTLSGlobal;
  /* Marshall function inputs */
  m91_margin = emlrt_marshallIn(&st, emlrtAliasP(prhs[0]), "m91_margin");
  authority = emlrt_marshallIn(&st, emlrtAliasP(prhs[1]), "authority");
  margin_filtered =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[2]), "margin_filtered");
  margin_guarded =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[3]), "margin_guarded");
  above_count = emlrt_marshallIn(&st, emlrtAliasP(prhs[4]), "above_count");
  below_count = emlrt_marshallIn(&st, emlrtAliasP(prhs[5]), "below_count");
  target_margin = emlrt_marshallIn(&st, emlrtAliasP(prhs[6]), "target_margin");
  update_interval_s =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[7]), "update_interval_s");
  a_min = emlrt_marshallIn(&st, emlrtAliasP(prhs[8]), "a_min");
  a_max = emlrt_marshallIn(&st, emlrtAliasP(prhs[9]), "a_max");
  down_deadband = emlrt_marshallIn(&st, emlrtAliasP(prhs[10]), "down_deadband");
  down_rate = emlrt_marshallIn(&st, emlrtAliasP(prhs[11]), "down_rate");
  down_immediate_margin =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[12]), "down_immediate_margin");
  down_confirm_n =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[13]), "down_confirm_n");
  up_deadband = emlrt_marshallIn(&st, emlrtAliasP(prhs[14]), "up_deadband");
  power_law = emlrt_marshallIn(&st, emlrtAliasP(prhs[15]), "power_law");
  smooth_down = emlrt_marshallIn(&st, emlrtAliasP(prhs[16]), "smooth_down");
  up_rate = emlrt_marshallIn(&st, emlrtAliasP(prhs[17]), "up_rate");
  up_hold_s = emlrt_marshallIn(&st, emlrtAliasP(prhs[18]), "up_hold_s");
  margin_guard_up_rate =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[19]), "margin_guard_up_rate");
  margin_guard_down_rate =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[20]), "margin_guard_down_rate");
  margin_filter_alpha =
      emlrt_marshallIn(&st, emlrtAliasP(prhs[21]), "margin_filter_alpha");
  /* Invoke the target function */
  auth_stability_gain(
      m91_margin, authority, margin_filtered, margin_guarded, above_count,
      below_count, target_margin, update_interval_s, a_min, a_max,
      down_deadband, down_rate, down_immediate_margin, down_confirm_n,
      up_deadband, power_law, smooth_down, up_rate, up_hold_s,
      margin_guard_up_rate, margin_guard_down_rate, margin_filter_alpha,
      &authority_next, &margin_filtered_next, &margin_guarded_next,
      &above_count_next, &below_count_next, &down_confirmed);
  /* Marshall function outputs */
  plhs[0] = emlrt_marshallOut(authority_next);
  if (nlhs > 1) {
    plhs[1] = emlrt_marshallOut(margin_filtered_next);
  }
  if (nlhs > 2) {
    plhs[2] = emlrt_marshallOut(margin_guarded_next);
  }
  if (nlhs > 3) {
    plhs[3] = emlrt_marshallOut(above_count_next);
  }
  if (nlhs > 4) {
    plhs[4] = emlrt_marshallOut(below_count_next);
  }
  if (nlhs > 5) {
    plhs[5] = emlrt_marshallOut(down_confirmed);
  }
}

void auth_stability_gain_atexit(void)
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtPushHeapReferenceStackR2021a(
      &st, false, NULL, (void *)&emlrtExitTimeCleanupDtorFcn, NULL, NULL, NULL);
  emlrtEnterRtStackR2012b(&st);
  emlrtDestroyRootTLS(&emlrtRootTLSGlobal);
  auth_stability_gain_xil_terminate();
  auth_stability_gain_xil_shutdown();
  emlrtExitTimeCleanup(&emlrtContextGlobal);
}

void auth_stability_gain_initialize(void)
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtClearAllocCountR2012b(&st, false, 0U, NULL);
  emlrtEnterRtStackR2012b(&st);
  emlrtFirstTimeR2012b(emlrtRootTLSGlobal);
}

void auth_stability_gain_terminate(void)
{
  emlrtDestroyRootTLS(&emlrtRootTLSGlobal);
}

/* End of code generation (_coder_auth_stability_gain_api.c) */
