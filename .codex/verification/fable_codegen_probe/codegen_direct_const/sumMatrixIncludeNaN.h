/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sumMatrixIncludeNaN.h
 *
 * Code generation for function 'sumMatrixIncludeNaN'
 *
 */

#pragma once

/* Include files */
#include "rtwtypes.h"
#include "emlrt.h"
#include "mex.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Function Declarations */
creal_T b_sumColumnB(const emlrtStack *sp, const creal_T x_data[],
                     int32_T vlen);

real_T c_sumColumnB(const real_T x[24]);

real_T sumColumnB(const emlrtStack *sp, const real_T x_data[], int32_T vlen);

/* End of code generation (sumMatrixIncludeNaN.h) */
