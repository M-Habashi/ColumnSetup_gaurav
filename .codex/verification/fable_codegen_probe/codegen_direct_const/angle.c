/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * angle.c
 *
 * Code generation for function 'angle'
 *
 */

/* Include files */
#include "angle.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"

/* Function Definitions */
int32_T angle(const creal_T x_data[], int32_T x_size, real_T y_data[])
{
  int32_T k;
  int32_T y_size;
  y_size = x_size;
  for (k = 0; k < x_size; k++) {
    y_data[k] = muDoubleScalarAtan2(x_data[k].im, x_data[k].re);
  }
  return y_size;
}

/* End of code generation (angle.c) */
