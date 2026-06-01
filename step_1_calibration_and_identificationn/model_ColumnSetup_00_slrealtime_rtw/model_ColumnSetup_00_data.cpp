/*
 * model_ColumnSetup_00_data.cpp
 *
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * Code generation for model "model_ColumnSetup_00".
 *
 * Model version              : 16.127
 * Simulink Coder version : 9.4 (R2020b) 29-Jul-2020
 * C++ source code generated on : Sun May 31 20:52:26 2026
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
  /* Variable: ch
   * Referenced by:
   *   '<S5>/init_am'
   *   '<S5>/init_dm'
   *   '<S5>/init_fm'
   */
  {
    2.0,
    3.0,
    4.0,
    5.0
  },

  /* Variable: chirp_gain
   * Referenced by: '<S2>/Gain'
   */
  5.0,

  /* Variable: command_channel_selector
   * Referenced by: '<S3>/Populate command'
   */
  { 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0 },

  /* Variable: correction_gain
   * Referenced by: '<S1>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  '
   */
  1.01,

  /* Variable: f_final
   * Referenced by: '<S7>/deltaFreq'
   */
  50.0,

  /* Variable: f_init
   * Referenced by:
   *   '<S7>/deltaFreq'
   *   '<S7>/initialFreq'
   */
  0.001,

  /* Variable: ini_v
   * Referenced by:
   *   '<S5>/init_am'
   *   '<S5>/init_dm'
   *   '<S5>/init_fm'
   */
  { 8.2358439880262782E-6, 8.7018340758005742E-5, 0.00063036054755952035,
    0.00060754156055180437, 0.00063386944174189861, 0.00063716228936104363,
    0.00062208372922274138, 0.0006765200132793119, -4.8115059611776537E-5,
    2.7925880769358252E-5, -1.6669109837203727E-5, 0.013593102193168083,
    3.4302979325912714E-5, 1.9149920372769241E-5, 0.016320406958656105,
    -2.038660070133344E-5, 8.1952421343933014E-5, -6.4542048300017326E-5 },

  /* Variable: sat_limit
   * Referenced by: '<S1>/Saturation limit for the voltage signal  that is sent to the MTS'
   */
  7.8740157480314963,

  /* Variable: tend_chirp
   * Referenced by: '<S7>/targetTime'
   */
  90.0,

  /* Variable: test_signal
   * Referenced by: '<S2>/Constant'
   */
  2.0,

  /* Variable: v2a_const
   * Referenced by: '<S1>/Constant1'
   */
  0.0,

  /* Variable: v2a_gain
   * Referenced by: '<S1>/Gain1'
   */
  -19.762845849802371,

  /* Variable: v2d_const
   * Referenced by:
   *   '<S1>/Constant3'
   *   '<S1>/Conversion factor from  engineering units to voltage. It is a linear regression with a slope and an offeset'
   */
  0.0,

  /* Variable: v2d_gain
   * Referenced by:
   *   '<S1>/Conversion factor from  engineering units to voltage. It is a linear regression with a slope and an offeset'
   *   '<S1>/  '
   *   '<S1>/Gain2'
   */
  7.62,

  /* Variable: v2f_const
   * Referenced by: '<S1>/Constant5'
   */
  0.0,

  /* Variable: v2f_gain
   * Referenced by: '<S1>/Gain4'
   */
  1000.0,

  /* Variable: wn_power
   * Referenced by: '<S6>/Output'
   */
  1.0
};
