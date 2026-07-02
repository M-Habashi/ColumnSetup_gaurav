/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * quickselect.h
 *
 * Code generation for function 'quickselect'
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
real_T b_quickselect(real_T v_data[], int32_T n, int32_T vlen, int32_T *nfirst,
                     int32_T *nlast);

void med3(real_T v[94], int32_T nv, int32_T ia, int32_T ib);

void medmed(real_T v[94], int32_T nv, int32_T ia);

int32_T pivot(const emlrtStack *sp, real_T v[94], int32_T *ip, int32_T ia,
              int32_T ib);

real_T quickselect(emxArray_real_T *v, int32_T n, int32_T vlen, int32_T *nfirst,
                   int32_T *nlast);

int32_T thirdOfFive(const real_T v[17], int32_T ia, int32_T ib);

/* End of code generation (quickselect.h) */
