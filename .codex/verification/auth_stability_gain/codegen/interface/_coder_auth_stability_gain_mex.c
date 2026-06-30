/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_auth_stability_gain_mex.c
 *
 * Code generation for function 'auth_stability_gain'
 *
 */

/* Include files */
#include "_coder_auth_stability_gain_mex.h"
#include "_coder_auth_stability_gain_api.h"

/* Function Definitions */
void mexFunction(int32_T nlhs, mxArray *plhs[], int32_T nrhs,
                 const mxArray *prhs[])
{
  mexAtExit(&auth_stability_gain_atexit);
  auth_stability_gain_initialize();
  unsafe_auth_stability_gain_mexFunction(nlhs, plhs, nrhs, prhs);
  auth_stability_gain_terminate();
}

emlrtCTX mexFunctionCreateRootTLS(void)
{
  emlrtCreateRootTLSR2022a(&emlrtRootTLSGlobal, &emlrtContextGlobal, NULL, 1,
                           NULL, "windows-1252", true);
  return emlrtRootTLSGlobal;
}

void unsafe_auth_stability_gain_mexFunction(int32_T nlhs, mxArray *plhs[6],
                                            int32_T nrhs,
                                            const mxArray *prhs[22])
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  const mxArray *b_prhs[22];
  const mxArray *outputs[6];
  int32_T i;
  int32_T i1;
  st.tls = emlrtRootTLSGlobal;
  /* Check for proper number of arguments. */
  if (nrhs != 22) {
    emlrtErrMsgIdAndTxt(&st, "EMLRT:runTime:WrongNumberOfInputs", 5, 12, 22, 4,
                        19, "auth_stability_gain");
  }
  if (nlhs > 6) {
    emlrtErrMsgIdAndTxt(&st, "EMLRT:runTime:TooManyOutputArguments", 3, 4, 19,
                        "auth_stability_gain");
  }
  /* Call the function. */
  for (i = 0; i < 22; i++) {
    b_prhs[i] = prhs[i];
  }
  auth_stability_gain_api(b_prhs, nlhs, outputs);
  /* Copy over outputs to the caller. */
  if (nlhs < 1) {
    i1 = 1;
  } else {
    i1 = nlhs;
  }
  emlrtReturnArrays(i1, &plhs[0], &outputs[0]);
}

/* End of code generation (_coder_auth_stability_gain_mex.c) */
