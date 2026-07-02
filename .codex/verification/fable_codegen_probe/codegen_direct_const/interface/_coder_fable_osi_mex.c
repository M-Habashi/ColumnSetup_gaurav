/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_fable_osi_mex.c
 *
 * Code generation for function '_coder_fable_osi_mex'
 *
 */

/* Include files */
#include "_coder_fable_osi_mex.h"
#include "_coder_fable_osi_api.h"
#include "fable_osi.h"
#include "fable_osi_data.h"
#include "fable_osi_initialize.h"
#include "fable_osi_terminate.h"
#include "fable_osi_types.h"
#include "rt_nonfinite.h"
#include "omp.h"

/* Function Definitions */
void fable_osi_mexFunction(fable_osiStackData *SD, int32_T nlhs,
                           mxArray *plhs[3], int32_T nrhs,
                           const mxArray *prhs[4])
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  const mxArray *outputs[3];
  int32_T i;
  st.tls = emlrtRootTLSGlobal;
  /* Check for proper number of arguments. */
  if (nrhs < 4) {
    emlrtErrMsgIdAndTxt(&st, "EMLRT:runTime:TooFewInputsConstants", 9, 4, 9,
                        "fable_osi", 4, 9, "fable_osi", 4, 9, "fable_osi");
  }
  if (nrhs != 4) {
    emlrtErrMsgIdAndTxt(&st, "EMLRT:runTime:WrongNumberOfInputs", 5, 12, 4, 4,
                        9, "fable_osi");
  }
  if (nlhs > 3) {
    emlrtErrMsgIdAndTxt(&st, "EMLRT:runTime:TooManyOutputArguments", 3, 4, 9,
                        "fable_osi");
  }
  /* Call the function. */
  fable_osi_api(SD, prhs, nlhs, outputs);
  /* Copy over outputs to the caller. */
  if (nlhs < 1) {
    i = 1;
  } else {
    i = nlhs;
  }
  emlrtReturnArrays(i, &plhs[0], &outputs[0]);
}

void mexFunction(int32_T nlhs, mxArray *plhs[], int32_T nrhs,
                 const mxArray *prhs[])
{
  static jmp_buf emlrtJBEnviron;
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  fable_osiStackData *fable_osiStackDataGlobal = NULL;
  fable_osiStackDataGlobal = (fable_osiStackData *)emlrtMxCalloc(
      (size_t)1, (size_t)1U * sizeof(fable_osiStackData));
  mexAtExit(&fable_osi_atexit);
  /* Initialize the memory manager. */
  omp_init_lock(&emlrtLockGlobal);
  omp_init_nest_lock(&fable_osi_nestLockGlobal);
  fable_osi_initialize();
  st.tls = emlrtRootTLSGlobal;
  emlrtSetJmpBuf(&st, &emlrtJBEnviron);
  if (setjmp(emlrtJBEnviron) == 0) {
    fable_osi_mexFunction(fable_osiStackDataGlobal, nlhs, plhs, nrhs, prhs);
    fable_osi_terminate();
    omp_destroy_lock(&emlrtLockGlobal);
    omp_destroy_nest_lock(&fable_osi_nestLockGlobal);
  } else {
    omp_destroy_lock(&emlrtLockGlobal);
    omp_destroy_nest_lock(&fable_osi_nestLockGlobal);
    emlrtReportParallelRunTimeError(&st);
  }
  emlrtMxFree(fable_osiStackDataGlobal);
}

emlrtCTX mexFunctionCreateRootTLS(void)
{
  emlrtCreateRootTLSR2022a(&emlrtRootTLSGlobal, &emlrtContextGlobal,
                           &emlrtLockerFunction, omp_get_num_procs(), NULL,
                           "windows-1252", true);
  return emlrtRootTLSGlobal;
}

/* End of code generation (_coder_fable_osi_mex.c) */
