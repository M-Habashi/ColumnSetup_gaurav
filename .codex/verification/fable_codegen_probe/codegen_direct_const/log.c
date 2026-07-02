/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * log.c
 *
 * Code generation for function 'log'
 *
 */

/* Include files */
#include "log.h"
#include "fable_osi_data.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"

/* Function Definitions */
void b_log(const emlrtStack *sp, real_T x_data[], const int32_T *x_size)
{
  int32_T i;
  int32_T k;
  boolean_T p;
  p = false;
  i = *x_size;
  for (k = 0; k < i; k++) {
    if (p || (x_data[k] < 0.0)) {
      p = true;
    }
  }
  if (p) {
    emlrtErrorWithMessageIdR2018a(
        sp, &l_emlrtRTEI, "Coder:toolbox:ElFunDomainError",
        "Coder:toolbox:ElFunDomainError", 3, 4, 3, "log");
  }
  for (k = 0; k < i; k++) {
    x_data[k] = muDoubleScalarLog(x_data[k]);
  }
}

/* End of code generation (log.c) */
