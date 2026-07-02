/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * fable_osi.h
 *
 * Code generation for function 'fable_osi'
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
emlrtCTX emlrtGetRootTLSGlobal(void);

void emlrtLockerFunction(EmlrtLockeeFunction aLockee, emlrtConstCTX aTLS,
                         void *aData);

void fable_osi(const emlrtStack *sp, const real_T varargin_1[256],
               const real_T varargin_2[256], const struct1_T *varargin_4,
               real_T *out, struct1_T *state, struct2_T *info);

/* End of code generation (fable_osi.h) */
