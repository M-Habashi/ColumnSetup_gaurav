/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * abs.c
 *
 * Code generation for function 'abs'
 *
 */

/* Include files */
#include "abs.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"

/* Function Definitions */
int32_T b_abs(const creal_T x_data[], int32_T x_size, real_T y_data[])
{
  int32_T k;
  int32_T y_size;
  y_size = x_size;
  for (k = 0; k < x_size; k++) {
    y_data[k] = muDoubleScalarHypot(x_data[k].re, x_data[k].im);
  }
  return y_size;
}

/* End of code generation (abs.c) */
