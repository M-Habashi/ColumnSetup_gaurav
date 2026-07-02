/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * mldivide.h
 *
 * Code generation for function 'mldivide'
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
void b_mldivide(const emlrtStack *sp, const real_T B[2048], real_T Y[2]);

void mldivide(const emlrtStack *sp, const real_T B[512], real_T Y[2]);

/* End of code generation (mldivide.h) */
