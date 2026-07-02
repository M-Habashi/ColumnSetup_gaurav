/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * nnz.c
 *
 * Code generation for function 'nnz'
 *
 */

/* Include files */
#include "nnz.h"
#include "rt_nonfinite.h"

/* Function Definitions */
int32_T b_intnnz(const boolean_T s[25])
{
  int32_T k;
  int32_T n;
  n = 0;
  for (k = 0; k < 25; k++) {
    if (s[k]) {
      n++;
    }
  }
  return n;
}

int32_T intnnz(const boolean_T s[99])
{
  int32_T k;
  int32_T n;
  n = 0;
  for (k = 0; k < 99; k++) {
    if (s[k]) {
      n++;
    }
  }
  return n;
}

/* End of code generation (nnz.c) */
