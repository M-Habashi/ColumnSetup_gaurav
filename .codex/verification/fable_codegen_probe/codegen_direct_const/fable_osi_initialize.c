/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * fable_osi_initialize.c
 *
 * Code generation for function 'fable_osi_initialize'
 *
 */

/* Include files */
#include "fable_osi_initialize.h"
#include "_coder_fable_osi_mex.h"
#include "fable_osi_data.h"
#include "rt_nonfinite.h"

/* Function Declarations */
static void fable_osi_once(void);

/* Function Definitions */
static void fable_osi_once(void)
{
  mex_InitInfAndNan();
}

void fable_osi_initialize(void)
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtBreakCheckR2012bFlagVar = emlrtGetBreakCheckFlagAddressR2022b(&st);
  emlrtClearAllocCountR2012b(&st, false, 0U, NULL);
  emlrtEnterRtStackR2012b(&st);
  if (emlrtFirstTimeR2012b(emlrtRootTLSGlobal)) {
    fable_osi_once();
  }
}

/* End of code generation (fable_osi_initialize.c) */
