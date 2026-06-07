/*
 * model_ColumnSetup_00_private.h
 *
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * Code generation for model "model_ColumnSetup_00".
 *
 * Model version              : 16.250
 * Simulink Coder version : 9.4 (R2020b) 29-Jul-2020
 * C++ source code generated on : Sun Jun  7 11:38:26 2026
 *
 * Target selection: slrealtime.tlc
 * Note: GRT includes extra infrastructure and instrumentation for prototyping
 * Embedded hardware selection: Intel->x86-64 (Linux 64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef RTW_HEADER_model_ColumnSetup_00_private_h_
#define RTW_HEADER_model_ColumnSetup_00_private_h_
#include "rtwtypes.h"
#include "multiword_types.h"
#include "model_ColumnSetup_00.h"

/* Private macros used by the generated code to access rtModel */
#ifndef rtmIsMajorTimeStep
#define rtmIsMajorTimeStep(rtm)        (((rtm)->Timing.simTimeStep) == MAJOR_TIME_STEP)
#endif

#ifndef rtmIsMinorTimeStep
#define rtmIsMinorTimeStep(rtm)        (((rtm)->Timing.simTimeStep) == MINOR_TIME_STEP)
#endif

#ifndef rtmSetTFinal
#define rtmSetTFinal(rtm, val)         ((rtm)->Timing.tFinal = (val))
#endif

#ifndef rtmSetTPtr
#define rtmSetTPtr(rtm, val)           ((rtm)->Timing.t = (val))
#endif

extern real_T rt_urand_Upu32_Yd_f_pw_snf(uint32_T *u);
extern real_T rt_nrand_Upu32_Yd_f_pw_snf(uint32_T *u);
extern real_T rt_powd_snf(real_T u0, real_T u1);
extern void* slrtRegisterSignalToLoggingService(uintptr_t sigAddr);
extern real_T look1_binlcpw(real_T u0, const real_T bp0[], const real_T table[],
  uint32_T maxIndex);
extern "C" void sg_IO113_setup_s(SimStruct *rts);
extern "C" void sg_IO113_da_s(SimStruct *rts);
extern "C" void sg_IO112_setup_s(SimStruct *rts);
extern "C" void sg_IO112_ad_s(SimStruct *rts);
extern void model_ColumnS_PausableTime_Init(DW_PausableTime_model_ColumnS_T
  *localDW);
extern void model_ColumnSetup__PausableTime(real_T rtu_pause_enable,
  B_PausableTime_model_ColumnSe_T *localB, DW_PausableTime_model_ColumnS_T
  *localDW);

#endif                          /* RTW_HEADER_model_ColumnSetup_00_private_h_ */
