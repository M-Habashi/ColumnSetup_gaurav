/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * exp.c
 *
 * Code generation for function 'exp'
 *
 */

/* Include files */
#include "exp.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"

/* Function Definitions */
void b_exp(creal_T x_data[], const int32_T *x_size)
{
  int32_T i;
  int32_T k;
  i = *x_size;
  for (k = 0; k < i; k++) {
    creal_T dc;
    dc = x_data[k];
    if (dc.re == 0.0) {
      real_T r;
      r = dc.im;
      dc.re = muDoubleScalarCos(r);
      dc.im = muDoubleScalarSin(r);
      x_data[k] = dc;
    } else if (dc.im == 0.0) {
      real_T r;
      r = dc.re;
      dc.re = muDoubleScalarExp(r);
      dc.im = 0.0;
      x_data[k] = dc;
    } else if (muDoubleScalarIsInf(dc.im) && muDoubleScalarIsInf(dc.re) &&
               (dc.re < 0.0)) {
      x_data[k].re = 0.0;
      x_data[k].im = 0.0;
    } else {
      real_T d;
      real_T r;
      r = muDoubleScalarExp(dc.re / 2.0);
      d = dc.im;
      dc.re = r * (r * muDoubleScalarCos(d));
      dc.im = r * (r * muDoubleScalarSin(d));
      x_data[k] = dc;
    }
  }
}

/* End of code generation (exp.c) */
