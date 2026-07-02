/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sort3.c
 *
 * Code generation for function 'sort3'
 *
 */

/* Include files */
#include "sort3.h"
#include "rt_nonfinite.h"

/* Function Definitions */
int32_T sort3(real_T v1, real_T v2, real_T v3, int32_T *j2)
{
  int32_T b_j1;
  if (v1 < v2) {
    if (v2 < v3) {
      b_j1 = 1;
      *j2 = 2;
    } else if (v1 < v3) {
      b_j1 = 1;
      *j2 = 3;
    } else {
      b_j1 = 3;
      *j2 = 1;
    }
  } else if (v1 < v3) {
    b_j1 = 2;
    *j2 = 1;
  } else if (v2 < v3) {
    b_j1 = 2;
    *j2 = 3;
  } else {
    b_j1 = 3;
    *j2 = 2;
  }
  return b_j1;
}

/* End of code generation (sort3.c) */
