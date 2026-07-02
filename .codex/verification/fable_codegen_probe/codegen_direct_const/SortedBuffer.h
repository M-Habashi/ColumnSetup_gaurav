/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * SortedBuffer.h
 *
 * Code generation for function 'SortedBuffer'
 *
 */

#pragma once

/* Include files */
#include "fable_osi_internal_types.h"
#include "rtwtypes.h"
#include "emlrt.h"
#include "mex.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Function Declarations */
void SortedBuffer_insert(const emlrtStack *sp, coder_internal_SortedBuffer *obj,
                         real_T x);

int32_T SortedBuffer_locateElement(const real_T obj_buf[7], int32_T obj_nbuf,
                                   real_T x);

void SortedBuffer_remove(const emlrtStack *sp, coder_internal_SortedBuffer *obj,
                         real_T x);

void SortedBuffer_replace(const emlrtStack *sp,
                          b_coder_internal_SortedBuffer *obj, real_T xold,
                          real_T xnew);

void b_SortedBuffer_insert(const emlrtStack *sp,
                           b_coder_internal_SortedBuffer *obj, real_T x);

void b_SortedBuffer_remove(const emlrtStack *sp,
                           b_coder_internal_SortedBuffer *obj, real_T x);

/* End of code generation (SortedBuffer.h) */
