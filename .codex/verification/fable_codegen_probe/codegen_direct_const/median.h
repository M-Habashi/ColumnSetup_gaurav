/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * median.h
 *
 * Code generation for function 'median'
 *
 */

#pragma once

/* Include files */
#include "fable_osi_types.h"
#include "rtwtypes.h"
#include "emlrt.h"
#include "mex.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Function Declarations */
real_T b_median(const emlrtStack *sp, const real_T x[94]);

real_T c_median(const emlrtStack *sp, const real_T x_data[], int32_T x_size);

void d_median(const emlrtStack *sp, const emxArray_real_T *x, real_T y[99]);

real_T e_median(const real_T x_data[], const int32_T x_size[2]);

void f_median(const real_T x[75], real_T y[25]);

void median(const real_T x[1683], real_T y[99]);

/* End of code generation (median.h) */
