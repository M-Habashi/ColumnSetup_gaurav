/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * fable_osi_internal_types.h
 *
 * Code generation for function 'fable_osi'
 *
 */

#pragma once

/* Include files */
#include "fable_osi_types.h"
#include "rtwtypes.h"
#include "emlrt.h"

/* Type Definitions */
#ifndef c_typedef_coder_internal_Sorted
#define c_typedef_coder_internal_Sorted
typedef struct {
  real_T buf[7];
  int32_T nbuf;
} coder_internal_SortedBuffer;
#endif /* c_typedef_coder_internal_Sorted */

#ifndef c_typedef_b_coder_internal_Sort
#define c_typedef_b_coder_internal_Sort
typedef struct {
  real_T buf[3];
  int32_T nbuf;
} b_coder_internal_SortedBuffer;
#endif /* c_typedef_b_coder_internal_Sort */

#ifndef typedef_rtDesignRangeCheckInfo
#define typedef_rtDesignRangeCheckInfo
typedef struct {
  int32_T lineNo;
  int32_T colNo;
  const char_T *fName;
  const char_T *pName;
} rtDesignRangeCheckInfo;
#endif /* typedef_rtDesignRangeCheckInfo */

#ifndef typedef_rtRunTimeErrorInfo
#define typedef_rtRunTimeErrorInfo
typedef struct {
  int32_T lineNo;
  int32_T colNo;
  const char_T *fName;
  const char_T *pName;
} rtRunTimeErrorInfo;
#endif /* typedef_rtRunTimeErrorInfo */

/* End of code generation (fable_osi_internal_types.h) */
