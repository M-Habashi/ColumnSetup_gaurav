/*
 * model_ColumnSetup_00_data.cpp
 *
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * Code generation for model "model_ColumnSetup_00".
 *
 * Model version              : 16.210
 * Simulink Coder version : 9.4 (R2020b) 29-Jul-2020
 * C++ source code generated on : Fri Jun  5 09:52:32 2026
 *
 * Target selection: slrealtime.tlc
 * Note: GRT includes extra infrastructure and instrumentation for prototyping
 * Embedded hardware selection: Intel->x86-64 (Linux 64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#include "model_ColumnSetup_00.h"
#include "model_ColumnSetup_00_private.h"

/* Block parameters (default storage) */
P_model_ColumnSetup_00_T model_ColumnSetup_00_P = {
  /* Variable: command_channel_selector
   * Referenced by: '<S10>/Populate command'
   */
  { 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0 },

  /* Variable: correction_gain
   * Referenced by: '<S10>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  '
   */
  1.013,

  /* Variable: dt
   * Referenced by:
   *   '<S1>/Pausable Time'
   *   '<S1>/Pausable Time1'
   *   '<S1>/Smooth Sine'
   */
  0.00048828125,

  /* Variable: f_final
   * Referenced by: '<S4>/deltaFreq'
   */
  50.0,

  /* Variable: f_init
   * Referenced by:
   *   '<S4>/deltaFreq'
   *   '<S4>/initialFreq'
   */
  0.001,

  /* Variable: sat_limit
   * Referenced by: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS'
   */
  60.0,

  /* Variable: tend_chirp
   * Referenced by: '<S4>/targetTime'
   */
  90.0,

  /* Variable: v2a_gain
   * Referenced by: '<S12>/Gain1'
   */
  -19235.294117647059,

  /* Variable: v2d_gain
   * Referenced by:
   *   '<S10>/  '
   *   '<S12>/Gain2'
   */
  7.62,

  /* Variable: v2f_gain
   * Referenced by: '<S12>/Gain4'
   */
  1000.0,

  /* Variable: zero_alpha
   * Referenced by:
   *   '<S13>/zero_alpha'
   *   '<S14>/zero_alpha'
   */
  0.0009765625
};
