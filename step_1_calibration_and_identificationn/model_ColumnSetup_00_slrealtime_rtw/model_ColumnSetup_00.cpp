/*
 * model_ColumnSetup_00.cpp
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

/* Exported block parameters */
real_T dd_pause_enable = 1.0;          /* Variable: dd_pause_enable
                                        * Referenced by: '<S1>/dd_pause_enable'
                                        */
real_T zero_measurements_enable = 0.0; /* Variable: zero_measurements_enable
                                        * Referenced by: '<S12>/zero_measurements_enable'
                                        */

/* Block signals (default storage) */
B_model_ColumnSetup_00_T model_ColumnSetup_00_B;

/* Block states (default storage) */
DW_model_ColumnSetup_00_T model_ColumnSetup_00_DW;

/* Real-time model */
RT_MODEL_model_ColumnSetup_00_T model_ColumnSetup_00_M_ =
  RT_MODEL_model_ColumnSetup_00_T();
RT_MODEL_model_ColumnSetup_00_T *const model_ColumnSetup_00_M =
  &model_ColumnSetup_00_M_;
real_T look1_binlcpw(real_T u0, const real_T bp0[], const real_T table[],
                     uint32_T maxIndex)
{
  real_T frac;
  real_T yL_0d0;
  uint32_T bpIdx;
  uint32_T iLeft;
  uint32_T iRght;

  /* Column-major Lookup 1-D
     Search method: 'binary'
     Use previous index: 'off'
     Interpolation method: 'Linear point-slope'
     Extrapolation method: 'Clip'
     Use last breakpoint for index at or above upper limit: 'off'
     Remove protection against out-of-range input in generated code: 'off'
   */
  /* Prelookup - Index and Fraction
     Index Search method: 'binary'
     Extrapolation method: 'Clip'
     Use previous index: 'off'
     Use last breakpoint for index at or above upper limit: 'off'
     Remove protection against out-of-range input in generated code: 'off'
   */
  if (u0 <= bp0[0U]) {
    iLeft = 0U;
    frac = 0.0;
  } else if (u0 < bp0[maxIndex]) {
    /* Binary Search */
    bpIdx = maxIndex >> 1U;
    iLeft = 0U;
    iRght = maxIndex;
    while (iRght - iLeft > 1U) {
      if (u0 < bp0[bpIdx]) {
        iRght = bpIdx;
      } else {
        iLeft = bpIdx;
      }

      bpIdx = (iRght + iLeft) >> 1U;
    }

    frac = (u0 - bp0[iLeft]) / (bp0[iLeft + 1U] - bp0[iLeft]);
  } else {
    iLeft = maxIndex - 1U;
    frac = 1.0;
  }

  /* Column-major Interpolation 1-D
     Interpolation method: 'Linear point-slope'
     Use last breakpoint for index at or above upper limit: 'off'
     Overflow mode: 'portable wrapping'
   */
  yL_0d0 = table[iLeft];
  return (table[iLeft + 1U] - yL_0d0) * frac + yL_0d0;
}

/*
 * System initialize for atomic system:
 *    '<S1>/Pausable Time'
 *    '<S1>/Pausable Time1'
 */
void model_ColumnS_PausableTime_Init(DW_PausableTime_model_ColumnS_T *localDW)
{
  localDW->tau_state = 0.0;
}

/*
 * Output and update for atomic system:
 *    '<S1>/Pausable Time'
 *    '<S1>/Pausable Time1'
 */
void model_ColumnSetup__PausableTime(real_T rtu_pause_enable,
  B_PausableTime_model_ColumnSe_T *localB, DW_PausableTime_model_ColumnS_T
  *localDW)
{
  /* MATLAB Function 'Signal Generation/Pausable Time': '<S6>:1' */
  if (rtu_pause_enable == 0.0) {
    /* '<S6>:1:8' */
    /* '<S6>:1:9' */
    localDW->tau_state += model_ColumnSetup_00_P.dt;
  }

  /* '<S6>:1:12' */
  localB->tau = localDW->tau_state;
}

real_T rt_urand_Upu32_Yd_f_pw_snf(uint32_T *u)
{
  uint32_T hi;
  uint32_T lo;

  /* Uniform random number generator (random number between 0 and 1)

     #define IA      16807                      magic multiplier = 7^5
     #define IM      2147483647                 modulus = 2^31-1
     #define IQ      127773                     IM div IA
     #define IR      2836                       IM modulo IA
     #define S       4.656612875245797e-10      reciprocal of 2^31-1
     test = IA * (seed % IQ) - IR * (seed/IQ)
     seed = test < 0 ? (test + IM) : test
     return (seed*S)
   */
  lo = *u % 127773U * 16807U;
  hi = *u / 127773U * 2836U;
  if (lo < hi) {
    *u = 2147483647U - (hi - lo);
  } else {
    *u = lo - hi;
  }

  return static_cast<real_T>(*u) * 4.6566128752457969E-10;
}

real_T rt_nrand_Upu32_Yd_f_pw_snf(uint32_T *u)
{
  real_T si;
  real_T sr;
  real_T y;

  /* Normal (Gaussian) random number generator */
  do {
    sr = 2.0 * rt_urand_Upu32_Yd_f_pw_snf(u) - 1.0;
    si = 2.0 * rt_urand_Upu32_Yd_f_pw_snf(u) - 1.0;
    si = sr * sr + si * si;
  } while (si > 1.0);

  y = std::sqrt(-2.0 * std::log(si) / si) * sr;
  return y;
}

/* Model step function */
void model_ColumnSetup_00_step(void)
{
  real_T q;
  real_T raw;
  real_T u2;
  int32_T i;
  int32_T j;
  boolean_T rEQ0;

  /* S-Function (sg_IO113_setup_s): '<S10>/Setup' */

  /* Level2 S-Function Block: '<S10>/Setup' (sg_IO113_setup_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[0];
    sfcnOutputs(rts,0);
  }

  /* MATLAB Function: '<S1>/Pausable Time' incorporates:
   *  Constant: '<S1>/dd_pause_enable'
   */
  model_ColumnSetup__PausableTime(dd_pause_enable,
    &model_ColumnSetup_00_B.sf_PausableTime,
    &model_ColumnSetup_00_DW.sf_PausableTime);

  /* MATLAB Function: '<S1>/Smooth Sine' incorporates:
   *  Constant: '<S1>/dd_pause_enable'
   *  Constant: '<S1>/sine_amp'
   *  Constant: '<S1>/sine_freq'
   *  Constant: '<S1>/sine_setpoint'
   */
  /* MATLAB Function 'Signal Generation/Smooth Sine': '<S8>:1' */
  if (!model_ColumnSetup_00_DW.phase_not_empty) {
    /* '<S8>:1:4' */
    model_ColumnSetup_00_DW.phase_not_empty = true;

    /* '<S8>:1:8' */
    model_ColumnSetup_00_DW.amp_prev = model_ColumnSetup_00_cal->sine_amp_Value;

    /* '<S8>:1:9' */
    model_ColumnSetup_00_DW.setpoint_prev =
      model_ColumnSetup_00_cal->sine_setpoint_Value;
  }

  /* '<S8>:1:16' */
  if (dd_pause_enable != 0.0) {
    /* '<S8>:1:18' */
    /* '<S8>:1:19' */
    model_ColumnSetup_00_B.y = model_ColumnSetup_00_DW.y_prev;
  } else if (!model_ColumnSetup_00_DW.startup_done) {
    /* '<S8>:1:23' */
    if (!model_ColumnSetup_00_DW.startup_active) {
      /* '<S8>:1:24' */
      /* '<S8>:1:25' */
      model_ColumnSetup_00_DW.startup_active = true;

      /* '<S8>:1:26' */
      model_ColumnSetup_00_DW.startup_t = 0.0;

      /* '<S8>:1:27' */
      model_ColumnSetup_00_DW.startup_y0 = model_ColumnSetup_00_DW.y_prev;

      /* '<S8>:1:28' */
      model_ColumnSetup_00_DW.phase = 0.0;

      /* '<S8>:1:29' */
      model_ColumnSetup_00_DW.offset = 0.0;
    }

    /* '<S8>:1:32' */
    q = model_ColumnSetup_00_DW.startup_t + model_ColumnSetup_00_P.dt;
    if (q < 2.0) {
      model_ColumnSetup_00_DW.startup_t = q;
    } else {
      model_ColumnSetup_00_DW.startup_t = 2.0;
    }

    /* '<S8>:1:33' */
    raw = model_ColumnSetup_00_DW.startup_t / 2.0;

    /* '<S8>:1:34' */
    /* '<S8>:1:35' */
    model_ColumnSetup_00_B.y = (3.0 - 2.0 * raw) * (raw * raw) *
      (model_ColumnSetup_00_cal->sine_setpoint_Value -
       model_ColumnSetup_00_DW.startup_y0) + model_ColumnSetup_00_DW.startup_y0;

    /* '<S8>:1:36' */
    model_ColumnSetup_00_DW.y_prev = model_ColumnSetup_00_B.y;
    if (model_ColumnSetup_00_DW.startup_t >= 2.0) {
      /* '<S8>:1:38' */
      /* '<S8>:1:39' */
      model_ColumnSetup_00_DW.startup_done = true;

      /* '<S8>:1:40' */
      model_ColumnSetup_00_DW.amp_prev =
        model_ColumnSetup_00_cal->sine_amp_Value;

      /* '<S8>:1:41' */
      model_ColumnSetup_00_DW.setpoint_prev =
        model_ColumnSetup_00_cal->sine_setpoint_Value;
    }
  } else {
    /* '<S8>:1:46' */
    raw = 6.2831853071795862 * model_ColumnSetup_00_cal->sine_freq_Value *
      model_ColumnSetup_00_P.dt + model_ColumnSetup_00_DW.phase;
    if (rtIsNaN(raw) || rtIsInf(raw)) {
      model_ColumnSetup_00_DW.phase = (rtNaN);
    } else if (raw == 0.0) {
      model_ColumnSetup_00_DW.phase = 0.0;
    } else {
      model_ColumnSetup_00_DW.phase = std::fmod(raw, 6.2831853071795862);
      rEQ0 = (model_ColumnSetup_00_DW.phase == 0.0);
      if (!rEQ0) {
        q = std::abs(raw / 6.2831853071795862);
        rEQ0 = !(std::abs(q - std::floor(q + 0.5)) > 2.2204460492503131E-16 * q);
      }

      if (rEQ0) {
        model_ColumnSetup_00_DW.phase = 0.0;
      } else {
        if (raw < 0.0) {
          model_ColumnSetup_00_DW.phase += 6.2831853071795862;
        }
      }
    }

    /* '<S8>:1:47' */
    raw = model_ColumnSetup_00_cal->sine_amp_Value * std::sin
      (model_ColumnSetup_00_DW.phase) +
      model_ColumnSetup_00_cal->sine_setpoint_Value;
    if ((model_ColumnSetup_00_cal->sine_amp_Value !=
         model_ColumnSetup_00_DW.amp_prev) ||
        (model_ColumnSetup_00_cal->sine_setpoint_Value !=
         model_ColumnSetup_00_DW.setpoint_prev)) {
      /* '<S8>:1:49' */
      /* '<S8>:1:50' */
      model_ColumnSetup_00_DW.offset = model_ColumnSetup_00_DW.y_prev - raw;

      /* '<S8>:1:51' */
      model_ColumnSetup_00_DW.amp_prev =
        model_ColumnSetup_00_cal->sine_amp_Value;

      /* '<S8>:1:52' */
      model_ColumnSetup_00_DW.setpoint_prev =
        model_ColumnSetup_00_cal->sine_setpoint_Value;
    }

    /* '<S8>:1:55' */
    model_ColumnSetup_00_B.y = raw + model_ColumnSetup_00_DW.offset;

    /* '<S8>:1:56' */
    model_ColumnSetup_00_DW.offset *= std::exp(-model_ColumnSetup_00_P.dt / 0.1);

    /* '<S8>:1:57' */
    model_ColumnSetup_00_DW.y_prev = model_ColumnSetup_00_B.y;
  }

  /* End of MATLAB Function: '<S1>/Smooth Sine' */

  /* RandomNumber: '<S3>/White Noise' */
  model_ColumnSetup_00_B.WhiteNoise = model_ColumnSetup_00_DW.NextOutput;

  /* Gain: '<S3>/Output' */
  raw = model_ColumnSetup_00_cal->BandLimitedWhiteNoise_Cov;
  raw = std::sqrt(raw);
  raw /= 0.022097086912079612;

  /* Gain: '<S3>/Output' */
  model_ColumnSetup_00_B.Output = raw * model_ColumnSetup_00_B.WhiteNoise;

  /* DiscreteFir: '<S5>/Digital Filter' */
  /* Consume delay line and beginning of input samples */
  for (i = 1; i - 1 < 1; i++) {
    raw = 0.0;
    for (j = 0; j < i; j++) {
      q = model_ColumnSetup_00_B.Output *
        model_ColumnSetup_00_cal->DigitalFilter_Coefficients[j];
      raw += q;
    }

    for (j = 0; j < 131 - i; j++) {
      q = model_ColumnSetup_00_cal->DigitalFilter_Coefficients[i + j] *
        model_ColumnSetup_00_DW.DigitalFilter_states[j];
      raw += q;
    }

    /* DiscreteFir: '<S5>/Digital Filter' */
    model_ColumnSetup_00_B.DigitalFilter = raw;
  }

  /* Update delay line for next frame */
  for (i = 128; i >= 0; i--) {
    model_ColumnSetup_00_DW.DigitalFilter_states[i + 1] =
      model_ColumnSetup_00_DW.DigitalFilter_states[i];
  }

  for (i = 1; i - 1 < 1; i++) {
    model_ColumnSetup_00_DW.DigitalFilter_states[1 - i] =
      model_ColumnSetup_00_B.Output;
  }

  /* End of DiscreteFir: '<S5>/Digital Filter' */

  /* MATLAB Function: '<S1>/Pausable Time1' incorporates:
   *  Constant: '<S1>/dd_pause_enable'
   */
  model_ColumnSetup__PausableTime(dd_pause_enable,
    &model_ColumnSetup_00_B.sf_PausableTime1,
    &model_ColumnSetup_00_DW.sf_PausableTime1);

  /* MultiPortSwitch: '<S1>/Multiport Switch' incorporates:
   *  Constant: '<S1>/Constant'
   */
  switch (static_cast<int32_T>(model_ColumnSetup_00_cal->Constant_Value)) {
   case 1:
    /* Lookup_n-D: '<S1>/Time History Lookup' */
    model_ColumnSetup_00_B.TimeHistoryLookup = look1_binlcpw
      (model_ColumnSetup_00_B.sf_PausableTime.tau,
       model_ColumnSetup_00_cal->TimeHistoryLookup_bp01Data,
       model_ColumnSetup_00_cal->TimeHistoryLookup_tableData, 1U);

    /* MultiPortSwitch: '<S1>/Multiport Switch' */
    model_ColumnSetup_00_B.dd = model_ColumnSetup_00_B.TimeHistoryLookup;
    break;

   case 2:
    /* MultiPortSwitch: '<S1>/Multiport Switch' */
    model_ColumnSetup_00_B.dd = model_ColumnSetup_00_B.y;
    break;

   case 3:
    /* Switch: '<S1>/BLWN Pause Gate' incorporates:
     *  Constant: '<S1>/dd_pause_enable'
     */
    if (dd_pause_enable >= model_ColumnSetup_00_cal->BLWNPauseGate_Threshold) {
      /* Switch: '<S1>/BLWN Pause Gate' incorporates:
       *  Constant: '<S1>/BLWN Pause Zero'
       */
      model_ColumnSetup_00_B.BLWNPauseGate =
        model_ColumnSetup_00_cal->BLWNPauseZero_Value;
    } else {
      /* Gain: '<S1>/Gain1' */
      model_ColumnSetup_00_B.Gain1_j = model_ColumnSetup_00_cal->Gain1_Gain *
        model_ColumnSetup_00_B.DigitalFilter;

      /* Switch: '<S1>/BLWN Pause Gate' */
      model_ColumnSetup_00_B.BLWNPauseGate = model_ColumnSetup_00_B.Gain1_j;
    }

    /* End of Switch: '<S1>/BLWN Pause Gate' */

    /* MultiPortSwitch: '<S1>/Multiport Switch' */
    model_ColumnSetup_00_B.dd = model_ColumnSetup_00_B.BLWNPauseGate;
    break;

   case 4:
    /* Product: '<S4>/Product' incorporates:
     *  Constant: '<S4>/deltaFreq'
     */
    raw = (model_ColumnSetup_00_P.f_final - model_ColumnSetup_00_P.f_init) *
      6.2831853071795862;

    /* Product: '<S4>/Product' incorporates:
     *  Constant: '<S4>/targetTime'
     */
    model_ColumnSetup_00_B.Product = raw / model_ColumnSetup_00_P.tend_chirp;

    /* Gain: '<S4>/Gain' */
    model_ColumnSetup_00_B.Gain = model_ColumnSetup_00_cal->Gain_Gain *
      model_ColumnSetup_00_B.Product;

    /* Product: '<S4>/Product1' */
    model_ColumnSetup_00_B.Product1 =
      model_ColumnSetup_00_B.sf_PausableTime1.tau * model_ColumnSetup_00_B.Gain;

    /* Sum: '<S4>/Sum' incorporates:
     *  Constant: '<S4>/initialFreq'
     */
    raw = 6.2831853071795862 * model_ColumnSetup_00_P.f_init;

    /* Sum: '<S4>/Sum' */
    model_ColumnSetup_00_B.Sum = model_ColumnSetup_00_B.Product1 + raw;

    /* Product: '<S4>/Product2' */
    model_ColumnSetup_00_B.Product2 =
      model_ColumnSetup_00_B.sf_PausableTime1.tau * model_ColumnSetup_00_B.Sum;

    /* Trigonometry: '<S4>/Output' */
    model_ColumnSetup_00_B.Output_p = std::sin(model_ColumnSetup_00_B.Product2);

    /* Gain: '<S1>/Gain' */
    model_ColumnSetup_00_B.Gain_c = model_ColumnSetup_00_cal->Gain_Gain_b *
      model_ColumnSetup_00_B.Output_p;

    /* MultiPortSwitch: '<S1>/Multiport Switch' */
    model_ColumnSetup_00_B.dd = model_ColumnSetup_00_B.Gain_c;
    break;

   default:
    /* MultiPortSwitch: '<S1>/Multiport Switch' incorporates:
     *  Constant: '<S1>/Constant1'
     */
    model_ColumnSetup_00_B.dd = model_ColumnSetup_00_cal->Constant1_Value;
    break;
  }

  /* End of MultiPortSwitch: '<S1>/Multiport Switch' */

  /* Gain: '<S2>/ Controller placeholder' */
  model_ColumnSetup_00_B.Controllerplaceholder =
    model_ColumnSetup_00_cal->Controllerplaceholder_Gain *
    model_ColumnSetup_00_B.dd;

  /* Saturate: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS' */
  raw = -model_ColumnSetup_00_P.sat_limit;
  q = model_ColumnSetup_00_B.Controllerplaceholder;
  u2 = model_ColumnSetup_00_P.sat_limit;
  if (q > u2) {
    /* Saturate: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS' */
    model_ColumnSetup_00_B.dcmm = u2;
  } else if (q < raw) {
    /* Saturate: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS' */
    model_ColumnSetup_00_B.dcmm = raw;
  } else {
    /* Saturate: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS' */
    model_ColumnSetup_00_B.dcmm = q;
  }

  /* End of Saturate: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS' */

  /* UnitDelay: '<S13>/signal_offset' */
  model_ColumnSetup_00_B.signal_offset =
    model_ColumnSetup_00_DW.signal_offset_DSTATE;

  /* Sum: '<S10>/Subtract1' */
  model_ColumnSetup_00_B.Subtract1 = model_ColumnSetup_00_B.dcmm +
    model_ColumnSetup_00_B.signal_offset;

  /* Gain: '<S10>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  ' */
  model_ColumnSetup_00_B.AnalogControllervsDigitalContro =
    model_ColumnSetup_00_P.correction_gain * model_ColumnSetup_00_B.Subtract1;

  /* Gain: '<S10>/  ' */
  raw = 1.0 / model_ColumnSetup_00_P.v2d_gain;

  /* Gain: '<S10>/  ' */
  model_ColumnSetup_00_B.u = raw *
    model_ColumnSetup_00_B.AnalogControllervsDigitalContro;
  for (i = 0; i < 7; i++) {
    /* Gain: '<S10>/Populate command' */
    model_ColumnSetup_00_B.Populatecommand[i] =
      model_ColumnSetup_00_P.command_channel_selector[i] *
      model_ColumnSetup_00_B.u;
  }

  /* S-Function (sg_IO113_da_s): '<S10>/Analog Output' */

  /* Level2 S-Function Block: '<S10>/Analog Output' (sg_IO113_da_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[1];
    sfcnOutputs(rts,0);
  }

  /* S-Function (sg_IO112_setup_s): '<S12>/Setup' */

  /* Level2 S-Function Block: '<S12>/Setup' (sg_IO112_setup_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[2];
    sfcnOutputs(rts,0);
  }

  /* S-Function (sg_IO112_ad_s): '<S12>/Analog input' */

  /* Level2 S-Function Block: '<S12>/Analog input' (sg_IO112_ad_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[3];
    sfcnOutputs(rts,0);
  }

  /* Gain: '<S12>/Gain2' */
  model_ColumnSetup_00_B.Gain2 = model_ColumnSetup_00_P.v2d_gain *
    model_ColumnSetup_00_B.Analoginput[2];

  /* Sum: '<S13>/signal minus offset' */
  model_ColumnSetup_00_B.signalminusoffset = model_ColumnSetup_00_B.Gain2 -
    model_ColumnSetup_00_B.signal_offset;

  /* Gain: '<S13>/zero_alpha' */
  model_ColumnSetup_00_B.zero_alpha = model_ColumnSetup_00_P.zero_alpha *
    model_ColumnSetup_00_B.signalminusoffset;

  /* Product: '<S13>/enable update' incorporates:
   *  Constant: '<S12>/zero_measurements_enable'
   */
  model_ColumnSetup_00_B.enableupdate = model_ColumnSetup_00_B.zero_alpha *
    zero_measurements_enable;

  /* Sum: '<S13>/offset update' */
  model_ColumnSetup_00_B.offsetupdate = model_ColumnSetup_00_B.enableupdate +
    model_ColumnSetup_00_B.signal_offset;

  /* Gain: '<S12>/Gain4' */
  model_ColumnSetup_00_B.Gain4 = model_ColumnSetup_00_P.v2f_gain *
    model_ColumnSetup_00_B.Analoginput[3];

  /* UnitDelay: '<S14>/signal_offset' */
  model_ColumnSetup_00_B.signal_offset_n =
    model_ColumnSetup_00_DW.signal_offset_DSTATE_l;

  /* Sum: '<S14>/signal minus offset' */
  model_ColumnSetup_00_B.signalminusoffset_l = model_ColumnSetup_00_B.Gain4 -
    model_ColumnSetup_00_B.signal_offset_n;

  /* Gain: '<S14>/zero_alpha' */
  model_ColumnSetup_00_B.zero_alpha_m = model_ColumnSetup_00_P.zero_alpha *
    model_ColumnSetup_00_B.signalminusoffset_l;

  /* Product: '<S14>/enable update' incorporates:
   *  Constant: '<S12>/zero_measurements_enable'
   */
  model_ColumnSetup_00_B.enableupdate_c = model_ColumnSetup_00_B.zero_alpha_m *
    zero_measurements_enable;

  /* Sum: '<S14>/offset update' */
  model_ColumnSetup_00_B.offsetupdate_i = model_ColumnSetup_00_B.enableupdate_c
    + model_ColumnSetup_00_B.signal_offset_n;

  /* Gain: '<S12>/Gain1' */
  model_ColumnSetup_00_B.Gain1 = model_ColumnSetup_00_P.v2a_gain *
    model_ColumnSetup_00_B.Analoginput[1];

  /* Outputs for Atomic SubSystem: '<S2>/File Log' */
  /* SignalConversion generated from: '<S11>/Mux_5' */
  model_ColumnSetup_00_B.Mux_51[0] = model_ColumnSetup_00_B.dd;
  model_ColumnSetup_00_B.Mux_51[1] = model_ColumnSetup_00_B.dcmm;
  model_ColumnSetup_00_B.Mux_51[2] = model_ColumnSetup_00_B.signalminusoffset;
  model_ColumnSetup_00_B.Mux_51[3] = model_ColumnSetup_00_B.signalminusoffset_l;
  model_ColumnSetup_00_B.Mux_51[4] = model_ColumnSetup_00_B.Gain1;

  /* ToAsyncQueueBlock generated from: '<S11>/Mux_5' */
  slrtLogSignal
    (model_ColumnSetup_00_DW.TAQSigLogging_InsertedFor_Mux_5.SLRTSigHandles,
     model_ColumnSetup_00_M->Timing.t[0]);

  /* End of Outputs for SubSystem: '<S2>/File Log' */
  /* Update for RandomNumber: '<S3>/White Noise' */
  model_ColumnSetup_00_DW.NextOutput = rt_nrand_Upu32_Yd_f_pw_snf
    (&model_ColumnSetup_00_DW.RandSeed) *
    model_ColumnSetup_00_cal->WhiteNoise_StdDev +
    model_ColumnSetup_00_cal->WhiteNoise_Mean;

  /* Update for UnitDelay: '<S13>/signal_offset' */
  model_ColumnSetup_00_DW.signal_offset_DSTATE =
    model_ColumnSetup_00_B.offsetupdate;

  /* Update for UnitDelay: '<S14>/signal_offset' */
  model_ColumnSetup_00_DW.signal_offset_DSTATE_l =
    model_ColumnSetup_00_B.offsetupdate_i;

  /* Update absolute time for base rate */
  /* The "clockTick0" counts the number of times the code of this task has
   * been executed. The absolute time is the multiplication of "clockTick0"
   * and "Timing.stepSize0". Size of "clockTick0" ensures timer will not
   * overflow during the application lifespan selected.
   * Timer of this task consists of two 32 bit unsigned integers.
   * The two integers represent the low bits Timing.clockTick0 and the high bits
   * Timing.clockTickH0. When the low bit overflows to 0, the high bits increment.
   */
  if (!(++model_ColumnSetup_00_M->Timing.clockTick0)) {
    ++model_ColumnSetup_00_M->Timing.clockTickH0;
  }

  model_ColumnSetup_00_M->Timing.t[0] =
    model_ColumnSetup_00_M->Timing.clockTick0 *
    model_ColumnSetup_00_M->Timing.stepSize0 +
    model_ColumnSetup_00_M->Timing.clockTickH0 *
    model_ColumnSetup_00_M->Timing.stepSize0 * 4294967296.0;
}

/* Model initialize function */
void model_ColumnSetup_00_initialize(void)
{
  /* Registration code */

  /* initialize non-finites */
  rt_InitInfAndNaN(sizeof(real_T));
  rtsiSetSolverName(&model_ColumnSetup_00_M->solverInfo,"FixedStepDiscrete");
  model_ColumnSetup_00_M->solverInfoPtr = (&model_ColumnSetup_00_M->solverInfo);

  /* Initialize timing info */
  {
    int_T *mdlTsMap = model_ColumnSetup_00_M->Timing.sampleTimeTaskIDArray;
    mdlTsMap[0] = 0;
    model_ColumnSetup_00_M->Timing.sampleTimeTaskIDPtr = (&mdlTsMap[0]);
    model_ColumnSetup_00_M->Timing.sampleTimes =
      (&model_ColumnSetup_00_M->Timing.sampleTimesArray[0]);
    model_ColumnSetup_00_M->Timing.offsetTimes =
      (&model_ColumnSetup_00_M->Timing.offsetTimesArray[0]);

    /* task periods */
    model_ColumnSetup_00_M->Timing.sampleTimes[0] = (0.00048828125);

    /* task offsets */
    model_ColumnSetup_00_M->Timing.offsetTimes[0] = (0.0);
  }

  rtmSetTPtr(model_ColumnSetup_00_M, &model_ColumnSetup_00_M->Timing.tArray[0]);

  {
    int_T *mdlSampleHits = model_ColumnSetup_00_M->Timing.sampleHitArray;
    mdlSampleHits[0] = 1;
    model_ColumnSetup_00_M->Timing.sampleHits = (&mdlSampleHits[0]);
  }

  rtmSetTFinal(model_ColumnSetup_00_M, -1);
  model_ColumnSetup_00_M->Timing.stepSize0 = 0.00048828125;
  model_ColumnSetup_00_M->solverInfoPtr = (&model_ColumnSetup_00_M->solverInfo);
  model_ColumnSetup_00_M->Timing.stepSize = (0.00048828125);
  rtsiSetFixedStepSize(&model_ColumnSetup_00_M->solverInfo, 0.00048828125);
  rtsiSetSolverMode(&model_ColumnSetup_00_M->solverInfo,
                    SOLVER_MODE_SINGLETASKING);

  /* block I/O */
  (void) std::memset((static_cast<void *>(&model_ColumnSetup_00_B)), 0,
                     sizeof(B_model_ColumnSetup_00_T));

  /* states (dwork) */
  (void) std::memset(static_cast<void *>(&model_ColumnSetup_00_DW), 0,
                     sizeof(DW_model_ColumnSetup_00_T));

  /* child S-Function registration */
  {
    RTWSfcnInfo *sfcnInfo = &model_ColumnSetup_00_M->NonInlinedSFcns.sfcnInfo;
    model_ColumnSetup_00_M->sfcnInfo = (sfcnInfo);
    rtssSetErrorStatusPtr(sfcnInfo, (&rtmGetErrorStatus(model_ColumnSetup_00_M)));
    rtssSetNumRootSampTimesPtr(sfcnInfo,
      &model_ColumnSetup_00_M->Sizes.numSampTimes);
    model_ColumnSetup_00_M->NonInlinedSFcns.taskTimePtrs[0] = &(rtmGetTPtr
      (model_ColumnSetup_00_M)[0]);
    rtssSetTPtrPtr(sfcnInfo,model_ColumnSetup_00_M->NonInlinedSFcns.taskTimePtrs);
    rtssSetTStartPtr(sfcnInfo, &rtmGetTStart(model_ColumnSetup_00_M));
    rtssSetTFinalPtr(sfcnInfo, &rtmGetTFinal(model_ColumnSetup_00_M));
    rtssSetTimeOfLastOutputPtr(sfcnInfo, &rtmGetTimeOfLastOutput
      (model_ColumnSetup_00_M));
    rtssSetStepSizePtr(sfcnInfo, &model_ColumnSetup_00_M->Timing.stepSize);
    rtssSetStopRequestedPtr(sfcnInfo, &rtmGetStopRequested
      (model_ColumnSetup_00_M));
    rtssSetDerivCacheNeedsResetPtr(sfcnInfo,
      &model_ColumnSetup_00_M->derivCacheNeedsReset);
    rtssSetZCCacheNeedsResetPtr(sfcnInfo,
      &model_ColumnSetup_00_M->zCCacheNeedsReset);
    rtssSetContTimeOutputInconsistentWithStateAtMajorStepPtr(sfcnInfo,
      &model_ColumnSetup_00_M->CTOutputIncnstWithState);
    rtssSetSampleHitsPtr(sfcnInfo, &model_ColumnSetup_00_M->Timing.sampleHits);
    rtssSetPerTaskSampleHitsPtr(sfcnInfo,
      &model_ColumnSetup_00_M->Timing.perTaskSampleHits);
    rtssSetSimModePtr(sfcnInfo, &model_ColumnSetup_00_M->simMode);
    rtssSetSolverInfoPtr(sfcnInfo, &model_ColumnSetup_00_M->solverInfoPtr);
  }

  model_ColumnSetup_00_M->Sizes.numSFcns = (4);

  /* register each child */
  {
    (void) std::memset(static_cast<void *>
                       (&model_ColumnSetup_00_M->
                        NonInlinedSFcns.childSFunctions[0]), 0,
                       4*sizeof(SimStruct));
    model_ColumnSetup_00_M->childSfunctions =
      (&model_ColumnSetup_00_M->NonInlinedSFcns.childSFunctionPtrs[0]);
    model_ColumnSetup_00_M->childSfunctions[0] =
      (&model_ColumnSetup_00_M->NonInlinedSFcns.childSFunctions[0]);
    model_ColumnSetup_00_M->childSfunctions[1] =
      (&model_ColumnSetup_00_M->NonInlinedSFcns.childSFunctions[1]);
    model_ColumnSetup_00_M->childSfunctions[2] =
      (&model_ColumnSetup_00_M->NonInlinedSFcns.childSFunctions[2]);
    model_ColumnSetup_00_M->childSfunctions[3] =
      (&model_ColumnSetup_00_M->NonInlinedSFcns.childSFunctions[3]);

    /* Level2 S-Function Block: model_ColumnSetup_00/<S10>/Setup (sg_IO113_setup_s) */
    {
      SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[0];

      /* timing info */
      time_T *sfcnPeriod =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn0.sfcnPeriod;
      time_T *sfcnOffset =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn0.sfcnOffset;
      int_T *sfcnTsMap = model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn0.sfcnTsMap;
      (void) std::memset(static_cast<void*>(sfcnPeriod), 0,
                         sizeof(time_T)*1);
      (void) std::memset(static_cast<void*>(sfcnOffset), 0,
                         sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts, &model_ColumnSetup_00_M->NonInlinedSFcns.blkInfo2
                         [0]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &model_ColumnSetup_00_M->NonInlinedSFcns.inputOutputPortInfo2[0]);

      /* Set up the mdlInfo pointer */
      ssSetRTWSfcnInfo(rts, model_ColumnSetup_00_M->sfcnInfo);

      /* Allocate memory of model methods 2 */
      {
        ssSetModelMethods2(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods2[0]);
      }

      /* Allocate memory of model methods 3 */
      {
        ssSetModelMethods3(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods3[0]);
      }

      /* Allocate memory of model methods 4 */
      {
        ssSetModelMethods4(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods4[0]);
      }

      /* Allocate memory for states auxilliary information */
      {
        ssSetStatesInfo2(rts,
                         &model_ColumnSetup_00_M->NonInlinedSFcns.statesInfo2[0]);
        ssSetPeriodicStatesInfo(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.periodicStatesInfo[0]);
      }

      /* path info */
      ssSetModelName(rts, "Setup");
      ssSetPath(rts, "model_ColumnSetup_00/columnSetup/Command to MTS/Setup");
      ssSetRTModel(rts,model_ColumnSetup_00_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      /* parameters */
      {
        mxArray **sfcnParams = (mxArray **)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn0.params;
        ssSetSFcnParamsCount(rts, 15);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)model_ColumnSetup_00_cal->Setup_P1_Size);
        ssSetSFcnParam(rts, 1, (mxArray*)model_ColumnSetup_00_cal->Setup_P2_Size);
        ssSetSFcnParam(rts, 2, (mxArray*)model_ColumnSetup_00_cal->Setup_P3_Size);
        ssSetSFcnParam(rts, 3, (mxArray*)model_ColumnSetup_00_cal->Setup_P4_Size);
        ssSetSFcnParam(rts, 4, (mxArray*)model_ColumnSetup_00_cal->Setup_P5_Size);
        ssSetSFcnParam(rts, 5, (mxArray*)model_ColumnSetup_00_cal->Setup_P6_Size);
        ssSetSFcnParam(rts, 6, (mxArray*)model_ColumnSetup_00_cal->Setup_P7_Size);
        ssSetSFcnParam(rts, 7, (mxArray*)model_ColumnSetup_00_cal->Setup_P8_Size);
        ssSetSFcnParam(rts, 8, (mxArray*)model_ColumnSetup_00_cal->Setup_P9_Size);
        ssSetSFcnParam(rts, 9, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P10_Size);
        ssSetSFcnParam(rts, 10, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P11_Size);
        ssSetSFcnParam(rts, 11, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P12_Size);
        ssSetSFcnParam(rts, 12, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P13_Size);
        ssSetSFcnParam(rts, 13, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P14_Size);
        ssSetSFcnParam(rts, 14, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P15_Size);
      }

      /* work vectors */
      ssSetRWork(rts, (real_T *) &model_ColumnSetup_00_DW.Setup_RWORK[0]);
      ssSetPWork(rts, (void **) &model_ColumnSetup_00_DW.Setup_PWORK);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn0.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn0.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        _ssSetNumDWork(rts, 2);

        /* RWORK */
        ssSetDWorkWidth(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_DOUBLE);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &model_ColumnSetup_00_DW.Setup_RWORK[0]);

        /* PWORK */
        ssSetDWorkWidth(rts, 1, 1);
        ssSetDWorkDataType(rts, 1,SS_POINTER);
        ssSetDWorkComplexSignal(rts, 1, 0);
        ssSetDWork(rts, 1, &model_ColumnSetup_00_DW.Setup_PWORK);
      }

      /* registration */
      sg_IO113_setup_s(rts);
      sfcnInitializeSizes(rts);
      sfcnInitializeSampleTimes(rts);

      /* adjust sample time */
      ssSetSampleTime(rts, 0, 0.00048828125);
      ssSetOffsetTime(rts, 0, 0.0);
      sfcnTsMap[0] = 0;

      /* set compiled values of dynamic vector attributes */
      ssSetNumNonsampledZCs(rts, 0);

      /* Update connectivity flags for each port */
      /* Update the BufferDstPort flags for each input port */
    }

    /* Level2 S-Function Block: model_ColumnSetup_00/<S10>/Analog Output (sg_IO113_da_s) */
    {
      SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[1];

      /* timing info */
      time_T *sfcnPeriod =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.sfcnPeriod;
      time_T *sfcnOffset =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.sfcnOffset;
      int_T *sfcnTsMap = model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.sfcnTsMap;
      (void) std::memset(static_cast<void*>(sfcnPeriod), 0,
                         sizeof(time_T)*1);
      (void) std::memset(static_cast<void*>(sfcnOffset), 0,
                         sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts, &model_ColumnSetup_00_M->NonInlinedSFcns.blkInfo2
                         [1]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &model_ColumnSetup_00_M->NonInlinedSFcns.inputOutputPortInfo2[1]);

      /* Set up the mdlInfo pointer */
      ssSetRTWSfcnInfo(rts, model_ColumnSetup_00_M->sfcnInfo);

      /* Allocate memory of model methods 2 */
      {
        ssSetModelMethods2(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods2[1]);
      }

      /* Allocate memory of model methods 3 */
      {
        ssSetModelMethods3(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods3[1]);
      }

      /* Allocate memory of model methods 4 */
      {
        ssSetModelMethods4(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods4[1]);
      }

      /* Allocate memory for states auxilliary information */
      {
        ssSetStatesInfo2(rts,
                         &model_ColumnSetup_00_M->NonInlinedSFcns.statesInfo2[1]);
        ssSetPeriodicStatesInfo(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.periodicStatesInfo[1]);
      }

      /* inputs */
      {
        _ssSetNumInputPorts(rts, 7);
        ssSetPortInfoForInputs(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.inputPortInfo[0]);
        _ssSetPortInfo2ForInputUnits(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.inputPortUnits[0]);
        ssSetInputPortUnit(rts, 0, 0);
        ssSetInputPortUnit(rts, 1, 0);
        ssSetInputPortUnit(rts, 2, 0);
        ssSetInputPortUnit(rts, 3, 0);
        ssSetInputPortUnit(rts, 4, 0);
        ssSetInputPortUnit(rts, 5, 0);
        ssSetInputPortUnit(rts, 6, 0);
        _ssSetPortInfo2ForInputCoSimAttribute(rts,
          &model_ColumnSetup_00_M->
          NonInlinedSFcns.Sfcn1.inputPortCoSimAttribute[0]);
        ssSetInputPortIsContinuousQuantity(rts, 0, 0);
        ssSetInputPortIsContinuousQuantity(rts, 1, 0);
        ssSetInputPortIsContinuousQuantity(rts, 2, 0);
        ssSetInputPortIsContinuousQuantity(rts, 3, 0);
        ssSetInputPortIsContinuousQuantity(rts, 4, 0);
        ssSetInputPortIsContinuousQuantity(rts, 5, 0);
        ssSetInputPortIsContinuousQuantity(rts, 6, 0);

        /* port 0 */
        {
          ssSetInputPortRequiredContiguous(rts, 0, 1);
          ssSetInputPortSignal(rts, 0, &model_ColumnSetup_00_B.Populatecommand[0]);
          _ssSetInputPortNumDimensions(rts, 0, 1);
          ssSetInputPortWidth(rts, 0, 1);
        }

        /* port 1 */
        {
          ssSetInputPortRequiredContiguous(rts, 1, 1);
          ssSetInputPortSignal(rts, 1, &model_ColumnSetup_00_B.Populatecommand[1]);
          _ssSetInputPortNumDimensions(rts, 1, 1);
          ssSetInputPortWidth(rts, 1, 1);
        }

        /* port 2 */
        {
          ssSetInputPortRequiredContiguous(rts, 2, 1);
          ssSetInputPortSignal(rts, 2, &model_ColumnSetup_00_B.Populatecommand[2]);
          _ssSetInputPortNumDimensions(rts, 2, 1);
          ssSetInputPortWidth(rts, 2, 1);
        }

        /* port 3 */
        {
          ssSetInputPortRequiredContiguous(rts, 3, 1);
          ssSetInputPortSignal(rts, 3, &model_ColumnSetup_00_B.Populatecommand[3]);
          _ssSetInputPortNumDimensions(rts, 3, 1);
          ssSetInputPortWidth(rts, 3, 1);
        }

        /* port 4 */
        {
          ssSetInputPortRequiredContiguous(rts, 4, 1);
          ssSetInputPortSignal(rts, 4, &model_ColumnSetup_00_B.Populatecommand[4]);
          _ssSetInputPortNumDimensions(rts, 4, 1);
          ssSetInputPortWidth(rts, 4, 1);
        }

        /* port 5 */
        {
          ssSetInputPortRequiredContiguous(rts, 5, 1);
          ssSetInputPortSignal(rts, 5, &model_ColumnSetup_00_B.Populatecommand[5]);
          _ssSetInputPortNumDimensions(rts, 5, 1);
          ssSetInputPortWidth(rts, 5, 1);
        }

        /* port 6 */
        {
          ssSetInputPortRequiredContiguous(rts, 6, 1);
          ssSetInputPortSignal(rts, 6, &model_ColumnSetup_00_B.Populatecommand[6]);
          _ssSetInputPortNumDimensions(rts, 6, 1);
          ssSetInputPortWidth(rts, 6, 1);
        }
      }

      /* path info */
      ssSetModelName(rts, "Analog Output");
      ssSetPath(rts,
                "model_ColumnSetup_00/columnSetup/Command to MTS/Analog Output");
      ssSetRTModel(rts,model_ColumnSetup_00_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      /* parameters */
      {
        mxArray **sfcnParams = (mxArray **)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.params;
        ssSetSFcnParamsCount(rts, 6);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)
                       model_ColumnSetup_00_cal->AnalogOutput_P1_Size);
        ssSetSFcnParam(rts, 1, (mxArray*)
                       model_ColumnSetup_00_cal->AnalogOutput_P2_Size);
        ssSetSFcnParam(rts, 2, (mxArray*)
                       model_ColumnSetup_00_cal->AnalogOutput_P3_Size);
        ssSetSFcnParam(rts, 3, (mxArray*)
                       model_ColumnSetup_00_cal->AnalogOutput_P4_Size);
        ssSetSFcnParam(rts, 4, (mxArray*)
                       model_ColumnSetup_00_cal->AnalogOutput_P5_Size);
        ssSetSFcnParam(rts, 5, (mxArray*)
                       model_ColumnSetup_00_cal->AnalogOutput_P6_Size);
      }

      /* work vectors */
      ssSetRWork(rts, (real_T *) &model_ColumnSetup_00_DW.AnalogOutput_RWORK[0]);
      ssSetIWork(rts, (int_T *) &model_ColumnSetup_00_DW.AnalogOutput_IWORK);
      ssSetPWork(rts, (void **) &model_ColumnSetup_00_DW.AnalogOutput_PWORK);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn1.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        _ssSetNumDWork(rts, 3);

        /* RWORK */
        ssSetDWorkWidth(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_DOUBLE);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &model_ColumnSetup_00_DW.AnalogOutput_RWORK[0]);

        /* IWORK */
        ssSetDWorkWidth(rts, 1, 1);
        ssSetDWorkDataType(rts, 1,SS_INTEGER);
        ssSetDWorkComplexSignal(rts, 1, 0);
        ssSetDWork(rts, 1, &model_ColumnSetup_00_DW.AnalogOutput_IWORK);

        /* PWORK */
        ssSetDWorkWidth(rts, 2, 1);
        ssSetDWorkDataType(rts, 2,SS_POINTER);
        ssSetDWorkComplexSignal(rts, 2, 0);
        ssSetDWork(rts, 2, &model_ColumnSetup_00_DW.AnalogOutput_PWORK);
      }

      /* registration */
      sg_IO113_da_s(rts);
      sfcnInitializeSizes(rts);
      sfcnInitializeSampleTimes(rts);

      /* adjust sample time */
      ssSetSampleTime(rts, 0, 0.00048828125);
      ssSetOffsetTime(rts, 0, 0.0);
      sfcnTsMap[0] = 0;

      /* set compiled values of dynamic vector attributes */
      ssSetNumNonsampledZCs(rts, 0);

      /* Update connectivity flags for each port */
      _ssSetInputPortConnected(rts, 0, 1);
      _ssSetInputPortConnected(rts, 1, 1);
      _ssSetInputPortConnected(rts, 2, 1);
      _ssSetInputPortConnected(rts, 3, 1);
      _ssSetInputPortConnected(rts, 4, 1);
      _ssSetInputPortConnected(rts, 5, 1);
      _ssSetInputPortConnected(rts, 6, 1);

      /* Update the BufferDstPort flags for each input port */
      ssSetInputPortBufferDstPort(rts, 0, -1);
      ssSetInputPortBufferDstPort(rts, 1, -1);
      ssSetInputPortBufferDstPort(rts, 2, -1);
      ssSetInputPortBufferDstPort(rts, 3, -1);
      ssSetInputPortBufferDstPort(rts, 4, -1);
      ssSetInputPortBufferDstPort(rts, 5, -1);
      ssSetInputPortBufferDstPort(rts, 6, -1);
    }

    /* Level2 S-Function Block: model_ColumnSetup_00/<S12>/Setup (sg_IO112_setup_s) */
    {
      SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[2];

      /* timing info */
      time_T *sfcnPeriod =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn2.sfcnPeriod;
      time_T *sfcnOffset =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn2.sfcnOffset;
      int_T *sfcnTsMap = model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn2.sfcnTsMap;
      (void) std::memset(static_cast<void*>(sfcnPeriod), 0,
                         sizeof(time_T)*1);
      (void) std::memset(static_cast<void*>(sfcnOffset), 0,
                         sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts, &model_ColumnSetup_00_M->NonInlinedSFcns.blkInfo2
                         [2]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &model_ColumnSetup_00_M->NonInlinedSFcns.inputOutputPortInfo2[2]);

      /* Set up the mdlInfo pointer */
      ssSetRTWSfcnInfo(rts, model_ColumnSetup_00_M->sfcnInfo);

      /* Allocate memory of model methods 2 */
      {
        ssSetModelMethods2(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods2[2]);
      }

      /* Allocate memory of model methods 3 */
      {
        ssSetModelMethods3(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods3[2]);
      }

      /* Allocate memory of model methods 4 */
      {
        ssSetModelMethods4(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods4[2]);
      }

      /* Allocate memory for states auxilliary information */
      {
        ssSetStatesInfo2(rts,
                         &model_ColumnSetup_00_M->NonInlinedSFcns.statesInfo2[2]);
        ssSetPeriodicStatesInfo(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.periodicStatesInfo[2]);
      }

      /* path info */
      ssSetModelName(rts, "Setup");
      ssSetPath(rts, "model_ColumnSetup_00/columnSetup/Measurements/Setup");
      ssSetRTModel(rts,model_ColumnSetup_00_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      /* parameters */
      {
        mxArray **sfcnParams = (mxArray **)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn2.params;
        ssSetSFcnParamsCount(rts, 9);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P1_Size_n);
        ssSetSFcnParam(rts, 1, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P2_Size_f);
        ssSetSFcnParam(rts, 2, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P3_Size_p);
        ssSetSFcnParam(rts, 3, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P4_Size_i);
        ssSetSFcnParam(rts, 4, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P5_Size_f);
        ssSetSFcnParam(rts, 5, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P6_Size_g);
        ssSetSFcnParam(rts, 6, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P7_Size_e);
        ssSetSFcnParam(rts, 7, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P8_Size_l);
        ssSetSFcnParam(rts, 8, (mxArray*)
                       model_ColumnSetup_00_cal->Setup_P9_Size_j);
      }

      /* work vectors */
      ssSetRWork(rts, (real_T *) &model_ColumnSetup_00_DW.Setup_RWORK_h[0]);
      ssSetIWork(rts, (int_T *) &model_ColumnSetup_00_DW.Setup_IWORK);
      ssSetPWork(rts, (void **) &model_ColumnSetup_00_DW.Setup_PWORK_o);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn2.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn2.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        _ssSetNumDWork(rts, 3);

        /* RWORK */
        ssSetDWorkWidth(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_DOUBLE);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &model_ColumnSetup_00_DW.Setup_RWORK_h[0]);

        /* IWORK */
        ssSetDWorkWidth(rts, 1, 1);
        ssSetDWorkDataType(rts, 1,SS_INTEGER);
        ssSetDWorkComplexSignal(rts, 1, 0);
        ssSetDWork(rts, 1, &model_ColumnSetup_00_DW.Setup_IWORK);

        /* PWORK */
        ssSetDWorkWidth(rts, 2, 1);
        ssSetDWorkDataType(rts, 2,SS_POINTER);
        ssSetDWorkComplexSignal(rts, 2, 0);
        ssSetDWork(rts, 2, &model_ColumnSetup_00_DW.Setup_PWORK_o);
      }

      /* registration */
      sg_IO112_setup_s(rts);
      sfcnInitializeSizes(rts);
      sfcnInitializeSampleTimes(rts);

      /* adjust sample time */
      ssSetSampleTime(rts, 0, 0.00048828125);
      ssSetOffsetTime(rts, 0, 0.0);
      sfcnTsMap[0] = 0;

      /* set compiled values of dynamic vector attributes */
      ssSetNumNonsampledZCs(rts, 0);

      /* Update connectivity flags for each port */
      /* Update the BufferDstPort flags for each input port */
    }

    /* Level2 S-Function Block: model_ColumnSetup_00/<S12>/Analog input (sg_IO112_ad_s) */
    {
      SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[3];

      /* timing info */
      time_T *sfcnPeriod =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.sfcnPeriod;
      time_T *sfcnOffset =
        model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.sfcnOffset;
      int_T *sfcnTsMap = model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.sfcnTsMap;
      (void) std::memset(static_cast<void*>(sfcnPeriod), 0,
                         sizeof(time_T)*1);
      (void) std::memset(static_cast<void*>(sfcnOffset), 0,
                         sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts, &model_ColumnSetup_00_M->NonInlinedSFcns.blkInfo2
                         [3]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &model_ColumnSetup_00_M->NonInlinedSFcns.inputOutputPortInfo2[3]);

      /* Set up the mdlInfo pointer */
      ssSetRTWSfcnInfo(rts, model_ColumnSetup_00_M->sfcnInfo);

      /* Allocate memory of model methods 2 */
      {
        ssSetModelMethods2(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods2[3]);
      }

      /* Allocate memory of model methods 3 */
      {
        ssSetModelMethods3(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods3[3]);
      }

      /* Allocate memory of model methods 4 */
      {
        ssSetModelMethods4(rts,
                           &model_ColumnSetup_00_M->NonInlinedSFcns.methods4[3]);
      }

      /* Allocate memory for states auxilliary information */
      {
        ssSetStatesInfo2(rts,
                         &model_ColumnSetup_00_M->NonInlinedSFcns.statesInfo2[3]);
        ssSetPeriodicStatesInfo(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.periodicStatesInfo[3]);
      }

      /* outputs */
      {
        ssSetPortInfoForOutputs(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.outputPortInfo[0]);
        _ssSetNumOutputPorts(rts, 1);
        _ssSetPortInfo2ForOutputUnits(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.outputPortUnits[0]);
        ssSetOutputPortUnit(rts, 0, 0);
        _ssSetPortInfo2ForOutputCoSimAttribute(rts,
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.outputPortCoSimAttribute
          [0]);
        ssSetOutputPortIsContinuousQuantity(rts, 0, 0);

        /* port 0 */
        {
          _ssSetOutputPortNumDimensions(rts, 0, 1);
          ssSetOutputPortWidth(rts, 0, 18);
          ssSetOutputPortSignal(rts, 0, ((real_T *)
            model_ColumnSetup_00_B.Analoginput));
        }
      }

      /* path info */
      ssSetModelName(rts, "Analog input");
      ssSetPath(rts,
                "model_ColumnSetup_00/columnSetup/Measurements/Analog input");
      ssSetRTModel(rts,model_ColumnSetup_00_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      /* parameters */
      {
        mxArray **sfcnParams = (mxArray **)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.params;
        ssSetSFcnParamsCount(rts, 6);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)
                       model_ColumnSetup_00_cal->Analoginput_P1_Size);
        ssSetSFcnParam(rts, 1, (mxArray*)
                       model_ColumnSetup_00_cal->Analoginput_P2_Size);
        ssSetSFcnParam(rts, 2, (mxArray*)
                       model_ColumnSetup_00_cal->Analoginput_P3_Size);
        ssSetSFcnParam(rts, 3, (mxArray*)
                       model_ColumnSetup_00_cal->Analoginput_P4_Size);
        ssSetSFcnParam(rts, 4, (mxArray*)
                       model_ColumnSetup_00_cal->Analoginput_P5_Size);
        ssSetSFcnParam(rts, 5, (mxArray*)
                       model_ColumnSetup_00_cal->Analoginput_P6_Size);
      }

      /* work vectors */
      ssSetRWork(rts, (real_T *) &model_ColumnSetup_00_DW.Analoginput_RWORK[0]);
      ssSetIWork(rts, (int_T *) &model_ColumnSetup_00_DW.Analoginput_IWORK);
      ssSetPWork(rts, (void **) &model_ColumnSetup_00_DW.Analoginput_PWORK);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &model_ColumnSetup_00_M->NonInlinedSFcns.Sfcn3.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        _ssSetNumDWork(rts, 3);

        /* RWORK */
        ssSetDWorkWidth(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_DOUBLE);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &model_ColumnSetup_00_DW.Analoginput_RWORK[0]);

        /* IWORK */
        ssSetDWorkWidth(rts, 1, 1);
        ssSetDWorkDataType(rts, 1,SS_INTEGER);
        ssSetDWorkComplexSignal(rts, 1, 0);
        ssSetDWork(rts, 1, &model_ColumnSetup_00_DW.Analoginput_IWORK);

        /* PWORK */
        ssSetDWorkWidth(rts, 2, 1);
        ssSetDWorkDataType(rts, 2,SS_POINTER);
        ssSetDWorkComplexSignal(rts, 2, 0);
        ssSetDWork(rts, 2, &model_ColumnSetup_00_DW.Analoginput_PWORK);
      }

      /* registration */
      sg_IO112_ad_s(rts);
      sfcnInitializeSizes(rts);
      sfcnInitializeSampleTimes(rts);

      /* adjust sample time */
      ssSetSampleTime(rts, 0, 0.00048828125);
      ssSetOffsetTime(rts, 0, 0.0);
      sfcnTsMap[0] = 0;

      /* set compiled values of dynamic vector attributes */
      ssSetNumNonsampledZCs(rts, 0);

      /* Update connectivity flags for each port */
      _ssSetOutputPortConnected(rts, 0, 1);
      _ssSetOutputPortBeingMerged(rts, 0, 0);

      /* Update the BufferDstPort flags for each input port */
    }
  }

  /* Start for S-Function (sg_IO113_setup_s): '<S10>/Setup' */
  /* Level2 S-Function Block: '<S10>/Setup' (sg_IO113_setup_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[0];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  /* Start for S-Function (sg_IO113_da_s): '<S10>/Analog Output' */
  /* Level2 S-Function Block: '<S10>/Analog Output' (sg_IO113_da_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[1];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  /* Start for S-Function (sg_IO112_setup_s): '<S12>/Setup' */
  /* Level2 S-Function Block: '<S12>/Setup' (sg_IO112_setup_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[2];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  /* Start for S-Function (sg_IO112_ad_s): '<S12>/Analog input' */
  /* Level2 S-Function Block: '<S12>/Analog input' (sg_IO112_ad_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[3];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  /* Start for Atomic SubSystem: '<S2>/File Log' */

  /* Start for ToAsyncQueueBlock generated from: '<S11>/Mux_5' */
  model_ColumnSetup_00_DW.TAQSigLogging_InsertedFor_Mux_5.SLRTSigHandles =
    slrtRegisterSignalToLoggingService(reinterpret_cast<uintptr_t>
    (&model_ColumnSetup_00_B.Mux_51[0]));

  /* End of Start for SubSystem: '<S2>/File Log' */
  {
    real_T tmp;
    int32_T i;
    int32_T t;
    uint32_T tseed;

    /* InitializeConditions for RandomNumber: '<S3>/White Noise' */
    tmp = std::floor(model_ColumnSetup_00_cal->BandLimitedWhiteNoise_seed);
    if (rtIsNaN(tmp) || rtIsInf(tmp)) {
      tmp = 0.0;
    } else {
      tmp = std::fmod(tmp, 4.294967296E+9);
    }

    tseed = tmp < 0.0 ? static_cast<uint32_T>(-static_cast<int32_T>(static_cast<
      uint32_T>(-tmp))) : static_cast<uint32_T>(tmp);
    i = static_cast<int32_T>(tseed >> 16U);
    t = static_cast<int32_T>(tseed & 32768U);
    tseed = ((((tseed - (static_cast<uint32_T>(i) << 16U)) + t) << 16U) + t) + i;
    if (tseed < 1U) {
      tseed = 1144108930U;
    } else {
      if (tseed > 2147483646U) {
        tseed = 2147483646U;
      }
    }

    model_ColumnSetup_00_DW.RandSeed = tseed;
    model_ColumnSetup_00_DW.NextOutput = rt_nrand_Upu32_Yd_f_pw_snf
      (&model_ColumnSetup_00_DW.RandSeed) *
      model_ColumnSetup_00_cal->WhiteNoise_StdDev +
      model_ColumnSetup_00_cal->WhiteNoise_Mean;

    /* End of InitializeConditions for RandomNumber: '<S3>/White Noise' */

    /* InitializeConditions for DiscreteFir: '<S5>/Digital Filter' */
    for (i = 0; i < 130; i++) {
      model_ColumnSetup_00_DW.DigitalFilter_states[i] =
        model_ColumnSetup_00_cal->DigitalFilter_InitialStates;
    }

    /* End of InitializeConditions for DiscreteFir: '<S5>/Digital Filter' */

    /* InitializeConditions for UnitDelay: '<S13>/signal_offset' */
    model_ColumnSetup_00_DW.signal_offset_DSTATE =
      model_ColumnSetup_00_cal->signal_offset_InitialCondition;

    /* InitializeConditions for UnitDelay: '<S14>/signal_offset' */
    model_ColumnSetup_00_DW.signal_offset_DSTATE_l =
      model_ColumnSetup_00_cal->signal_offset_InitialConditio_b;

    /* SystemInitialize for MATLAB Function: '<S1>/Pausable Time' */
    model_ColumnS_PausableTime_Init(&model_ColumnSetup_00_DW.sf_PausableTime);

    /* SystemInitialize for MATLAB Function: '<S1>/Smooth Sine' */
    model_ColumnSetup_00_DW.phase_not_empty = false;
    model_ColumnSetup_00_DW.phase = 0.0;
    model_ColumnSetup_00_DW.offset = 0.0;
    model_ColumnSetup_00_DW.y_prev = 0.0;
    model_ColumnSetup_00_DW.startup_t = 0.0;
    model_ColumnSetup_00_DW.startup_y0 = 0.0;
    model_ColumnSetup_00_DW.startup_active = false;
    model_ColumnSetup_00_DW.startup_done = false;

    /* SystemInitialize for MATLAB Function: '<S1>/Pausable Time1' */
    model_ColumnS_PausableTime_Init(&model_ColumnSetup_00_DW.sf_PausableTime1);
  }
}

/* Model terminate function */
void model_ColumnSetup_00_terminate(void)
{
  /* Terminate for S-Function (sg_IO113_setup_s): '<S10>/Setup' */
  /* Level2 S-Function Block: '<S10>/Setup' (sg_IO113_setup_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[0];
    sfcnTerminate(rts);
  }

  /* Terminate for S-Function (sg_IO113_da_s): '<S10>/Analog Output' */
  /* Level2 S-Function Block: '<S10>/Analog Output' (sg_IO113_da_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[1];
    sfcnTerminate(rts);
  }

  /* Terminate for S-Function (sg_IO112_setup_s): '<S12>/Setup' */
  /* Level2 S-Function Block: '<S12>/Setup' (sg_IO112_setup_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[2];
    sfcnTerminate(rts);
  }

  /* Terminate for S-Function (sg_IO112_ad_s): '<S12>/Analog input' */
  /* Level2 S-Function Block: '<S12>/Analog input' (sg_IO112_ad_s) */
  {
    SimStruct *rts = model_ColumnSetup_00_M->childSfunctions[3];
    sfcnTerminate(rts);
  }
}
