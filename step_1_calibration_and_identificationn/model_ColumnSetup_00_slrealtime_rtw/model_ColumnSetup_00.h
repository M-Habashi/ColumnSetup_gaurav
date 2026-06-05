/*
 * model_ColumnSetup_00.h
 *
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * Code generation for model "model_ColumnSetup_00".
 *
 * Model version              : 16.227
 * Simulink Coder version : 9.4 (R2020b) 29-Jul-2020
 * C++ source code generated on : Fri Jun  5 16:55:13 2026
 *
 * Target selection: slrealtime.tlc
 * Note: GRT includes extra infrastructure and instrumentation for prototyping
 * Embedded hardware selection: Intel->x86-64 (Linux 64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef RTW_HEADER_model_ColumnSetup_00_h_
#define RTW_HEADER_model_ColumnSetup_00_h_
#include <stddef.h>
#include <cstring>
#include <cmath>
#include <logsrv.h>
#include "rtwtypes.h"
#include "simstruc.h"
#include "fixedpoint.h"
#include "verify/verifyIntrf.h"
#include "model_ColumnSetup_00_types.h"

/* Shared type includes */
#include "multiword_types.h"

/* Child system includes */
#include "model_ColumnSetup_00_cal.h"
#include "rt_nonfinite.h"

/* Macros for accessing real-time model data structure */
#ifndef rtmGetContTimeOutputInconsistentWithStateAtMajorStepFlag
#define rtmGetContTimeOutputInconsistentWithStateAtMajorStepFlag(rtm) ((rtm)->CTOutputIncnstWithState)
#endif

#ifndef rtmSetContTimeOutputInconsistentWithStateAtMajorStepFlag
#define rtmSetContTimeOutputInconsistentWithStateAtMajorStepFlag(rtm, val) ((rtm)->CTOutputIncnstWithState = (val))
#endif

#ifndef rtmGetDerivCacheNeedsReset
#define rtmGetDerivCacheNeedsReset(rtm) ((rtm)->derivCacheNeedsReset)
#endif

#ifndef rtmSetDerivCacheNeedsReset
#define rtmSetDerivCacheNeedsReset(rtm, val) ((rtm)->derivCacheNeedsReset = (val))
#endif

#ifndef rtmGetFinalTime
#define rtmGetFinalTime(rtm)           ((rtm)->Timing.tFinal)
#endif

#ifndef rtmGetSampleHitArray
#define rtmGetSampleHitArray(rtm)      ((rtm)->Timing.sampleHitArray)
#endif

#ifndef rtmGetStepSize
#define rtmGetStepSize(rtm)            ((rtm)->Timing.stepSize)
#endif

#ifndef rtmGetZCCacheNeedsReset
#define rtmGetZCCacheNeedsReset(rtm)   ((rtm)->zCCacheNeedsReset)
#endif

#ifndef rtmSetZCCacheNeedsReset
#define rtmSetZCCacheNeedsReset(rtm, val) ((rtm)->zCCacheNeedsReset = (val))
#endif

#ifndef rtmGet_TimeOfLastOutput
#define rtmGet_TimeOfLastOutput(rtm)   ((rtm)->Timing.timeOfLastOutput)
#endif

#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

#ifndef rtmGetStopRequested
#define rtmGetStopRequested(rtm)       ((rtm)->Timing.stopRequestedFlag)
#endif

#ifndef rtmSetStopRequested
#define rtmSetStopRequested(rtm, val)  ((rtm)->Timing.stopRequestedFlag = (val))
#endif

#ifndef rtmGetStopRequestedPtr
#define rtmGetStopRequestedPtr(rtm)    (&((rtm)->Timing.stopRequestedFlag))
#endif

#ifndef rtmGetT
#define rtmGetT(rtm)                   (rtmGetTPtr((rtm))[0])
#endif

#ifndef rtmGetTFinal
#define rtmGetTFinal(rtm)              ((rtm)->Timing.tFinal)
#endif

#ifndef rtmGetTPtr
#define rtmGetTPtr(rtm)                ((rtm)->Timing.t)
#endif

#ifndef rtmGetTStart
#define rtmGetTStart(rtm)              ((rtm)->Timing.tStart)
#endif

#ifndef rtmGetTimeOfLastOutput
#define rtmGetTimeOfLastOutput(rtm)    ((rtm)->Timing.timeOfLastOutput)
#endif

/* Block signals for system '<S1>/Pausable Time' */
typedef struct {
  real_T tau;                          /* '<S1>/Pausable Time' */
} B_PausableTime_model_ColumnSe_T;

/* Block states (default storage) for system '<S1>/Pausable Time' */
typedef struct {
  real_T tau_state;                    /* '<S1>/Pausable Time' */
} DW_PausableTime_model_ColumnS_T;

/* Block signals (default storage) */
typedef struct {
  real_T WhiteNoise;                   /* '<S3>/White Noise' */
  real_T Output;                       /* '<S3>/Output' */
  real_T DigitalFilter;                /* '<S5>/Digital Filter' */
  real_T dd;                           /* '<S1>/Multiport Switch' */
  real_T SmoothStopClock;              /* '<S1>/Smooth Stop Clock' */
  real_T Controllerplaceholder;        /* '<S2>/ Controller placeholder' */
  real_T dcmm;
  /* '<S2>/Saturation limit for the displacement signal  that is sent to the MTS' */
  real_T AnalogControllervsDigitalContro;
  /* '<S11>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  ' */
  real_T signal_offset;                /* '<S14>/signal_offset' */
  real_T Subtract1;                    /* '<S11>/Subtract1' */
  real_T u;                            /* '<S11>/  ' */
  real_T Populatecommand[7];           /* '<S11>/Populate command' */
  real_T Analoginput[18];              /* '<S13>/Analog input' */
  real_T Gain2;                        /* '<S13>/Gain2' */
  real_T signalminusoffset;            /* '<S14>/signal minus offset' */
  real_T zero_alpha;                   /* '<S14>/zero_alpha' */
  real_T enableupdate;                 /* '<S14>/enable update' */
  real_T offsetupdate;                 /* '<S14>/offset update' */
  real_T Gain4;                        /* '<S13>/Gain4' */
  real_T signal_offset_n;              /* '<S15>/signal_offset' */
  real_T signalminusoffset_l;          /* '<S15>/signal minus offset' */
  real_T zero_alpha_m;                 /* '<S15>/zero_alpha' */
  real_T enableupdate_c;               /* '<S15>/enable update' */
  real_T offsetupdate_i;               /* '<S15>/offset update' */
  real_T Gain1;                        /* '<S13>/Gain1' */
  real_T Mux_51[5];
  /* '<S12>/TmpSignal ConversionAtTAQSigLogging_InsertedFor_Mux_5_at_outport_0Inport1' */
  real_T Product;                      /* '<S4>/Product' */
  real_T Gain;                         /* '<S4>/Gain' */
  real_T Product1;                     /* '<S4>/Product1' */
  real_T Sum;                          /* '<S4>/Sum' */
  real_T Product2;                     /* '<S4>/Product2' */
  real_T Output_p;                     /* '<S4>/Output' */
  real_T Gain_c;                       /* '<S1>/Gain' */
  real_T BLWNPauseGate;                /* '<S1>/BLWN Pause Gate' */
  real_T Gain1_j;                      /* '<S1>/Gain1' */
  real_T TimeHistoryLookup;            /* '<S1>/Time History Lookup' */
  real_T y;                            /* '<S1>/Smooth Stop Command' */
  real_T y_f;                          /* '<S1>/Smooth Sine' */
  B_PausableTime_model_ColumnSe_T sf_PausableTime1;/* '<S1>/Pausable Time1' */
  B_PausableTime_model_ColumnSe_T sf_PausableTime;/* '<S1>/Pausable Time' */
} B_model_ColumnSetup_00_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real_T DigitalFilter_states[130];    /* '<S5>/Digital Filter' */
  real_T signal_offset_DSTATE;         /* '<S14>/signal_offset' */
  real_T signal_offset_DSTATE_l;       /* '<S15>/signal_offset' */
  real_T NextOutput;                   /* '<S3>/White Noise' */
  real_T t0;                           /* '<S1>/Smooth Stop Command' */
  real_T blend0;                       /* '<S1>/Smooth Stop Command' */
  real_T blend;                        /* '<S1>/Smooth Stop Command' */
  real_T phase;                        /* '<S1>/Smooth Sine' */
  real_T offset;                       /* '<S1>/Smooth Sine' */
  real_T y_prev;                       /* '<S1>/Smooth Sine' */
  real_T amp_prev;                     /* '<S1>/Smooth Sine' */
  real_T setpoint_prev;                /* '<S1>/Smooth Sine' */
  real_T startup_t;                    /* '<S1>/Smooth Sine' */
  real_T startup_y0;                   /* '<S1>/Smooth Sine' */
  real_T Setup_RWORK[2];               /* '<S11>/Setup' */
  real_T AnalogOutput_RWORK[2];        /* '<S11>/Analog Output' */
  real_T Setup_RWORK_h[2];             /* '<S13>/Setup' */
  real_T Analoginput_RWORK[2];         /* '<S13>/Analog input' */
  void *Setup_PWORK;                   /* '<S11>/Setup' */
  void *AnalogOutput_PWORK;            /* '<S11>/Analog Output' */
  void *Setup_PWORK_o;                 /* '<S13>/Setup' */
  void *Analoginput_PWORK;             /* '<S13>/Analog input' */
  struct {
    void *LoggedData[3];
  } Scope_PWORK;                       /* '<S2>/Scope' */

  struct {
    void *LoggedData[2];
  } Scope2_PWORK;                      /* '<S2>/Scope2' */

  struct {
    void *AQHandles;
    void *SLRTSigHandles;
  } TAQSigLogging_InsertedFor_Mux_5;   /* synthesized block */

  uint32_T RandSeed;                   /* '<S3>/White Noise' */
  int_T AnalogOutput_IWORK;            /* '<S11>/Analog Output' */
  int_T Setup_IWORK;                   /* '<S13>/Setup' */
  int_T Analoginput_IWORK;             /* '<S13>/Analog input' */
  boolean_T last_enable;               /* '<S1>/Smooth Stop Command' */
  boolean_T phase_not_empty;           /* '<S1>/Smooth Sine' */
  boolean_T startup_active;            /* '<S1>/Smooth Sine' */
  boolean_T startup_done;              /* '<S1>/Smooth Sine' */
  DW_PausableTime_model_ColumnS_T sf_PausableTime1;/* '<S1>/Pausable Time1' */
  DW_PausableTime_model_ColumnS_T sf_PausableTime;/* '<S1>/Pausable Time' */
} DW_model_ColumnSetup_00_T;

/* Parameters (default storage) */
struct P_model_ColumnSetup_00_T_ {
  real_T command_channel_selector[7];  /* Variable: command_channel_selector
                                        * Referenced by: '<S11>/Populate command'
                                        */
  real_T correction_gain;              /* Variable: correction_gain
                                        * Referenced by: '<S11>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  '
                                        */
  real_T dt;                           /* Variable: dt
                                        * Referenced by:
                                        *   '<S1>/Pausable Time'
                                        *   '<S1>/Pausable Time1'
                                        *   '<S1>/Smooth Sine'
                                        */
  real_T f_final;                      /* Variable: f_final
                                        * Referenced by: '<S4>/deltaFreq'
                                        */
  real_T f_init;                       /* Variable: f_init
                                        * Referenced by:
                                        *   '<S4>/deltaFreq'
                                        *   '<S4>/initialFreq'
                                        */
  real_T sat_limit;                    /* Variable: sat_limit
                                        * Referenced by: '<S2>/Saturation limit for the displacement signal  that is sent to the MTS'
                                        */
  real_T t_ending;                     /* Variable: t_ending
                                        * Referenced by: '<S1>/t_ending'
                                        */
  real_T tend_chirp;                   /* Variable: tend_chirp
                                        * Referenced by: '<S4>/targetTime'
                                        */
  real_T v2a_gain;                     /* Variable: v2a_gain
                                        * Referenced by: '<S13>/Gain1'
                                        */
  real_T v2d_gain;                     /* Variable: v2d_gain
                                        * Referenced by:
                                        *   '<S11>/  '
                                        *   '<S13>/Gain2'
                                        */
  real_T v2f_gain;                     /* Variable: v2f_gain
                                        * Referenced by: '<S13>/Gain4'
                                        */
  real_T zero_alpha;                   /* Variable: zero_alpha
                                        * Referenced by:
                                        *   '<S14>/zero_alpha'
                                        *   '<S15>/zero_alpha'
                                        */
};

/* Real-time Model Data Structure */
struct tag_RTM_model_ColumnSetup_00_T {
  struct SimStruct_tag * *childSfunctions;
  const char_T *errorStatus;
  SS_SimMode simMode;
  RTWSolverInfo solverInfo;
  RTWSolverInfo *solverInfoPtr;
  void *sfcnInfo;

  /*
   * NonInlinedSFcns:
   * The following substructure contains information regarding
   * non-inlined s-functions used in the model.
   */
  struct {
    RTWSfcnInfo sfcnInfo;
    time_T *taskTimePtrs[2];
    SimStruct childSFunctions[4];
    SimStruct *childSFunctionPtrs[4];
    struct _ssBlkInfo2 blkInfo2[4];
    struct _ssSFcnModelMethods2 methods2[4];
    struct _ssSFcnModelMethods3 methods3[4];
    struct _ssSFcnModelMethods4 methods4[4];
    struct _ssStatesInfo2 statesInfo2[4];
    ssPeriodicStatesInfo periodicStatesInfo[4];
    struct _ssPortInfo2 inputOutputPortInfo2[4];
    struct {
      time_T sfcnPeriod[1];
      time_T sfcnOffset[1];
      int_T sfcnTsMap[1];
      uint_T attribs[15];
      mxArray *params[15];
      struct _ssDWorkRecord dWork[2];
      struct _ssDWorkAuxRecord dWorkAux[2];
    } Sfcn0;

    struct {
      time_T sfcnPeriod[1];
      time_T sfcnOffset[1];
      int_T sfcnTsMap[1];
      struct _ssPortInputs inputPortInfo[7];
      struct _ssInPortUnit inputPortUnits[7];
      struct _ssInPortCoSimAttribute inputPortCoSimAttribute[7];
      uint_T attribs[6];
      mxArray *params[6];
      struct _ssDWorkRecord dWork[3];
      struct _ssDWorkAuxRecord dWorkAux[3];
    } Sfcn1;

    struct {
      time_T sfcnPeriod[1];
      time_T sfcnOffset[1];
      int_T sfcnTsMap[1];
      uint_T attribs[9];
      mxArray *params[9];
      struct _ssDWorkRecord dWork[3];
      struct _ssDWorkAuxRecord dWorkAux[3];
    } Sfcn2;

    struct {
      time_T sfcnPeriod[1];
      time_T sfcnOffset[1];
      int_T sfcnTsMap[1];
      struct _ssPortOutputs outputPortInfo[1];
      struct _ssOutPortUnit outputPortUnits[1];
      struct _ssOutPortCoSimAttribute outputPortCoSimAttribute[1];
      uint_T attribs[6];
      mxArray *params[6];
      struct _ssDWorkRecord dWork[3];
      struct _ssDWorkAuxRecord dWorkAux[3];
    } Sfcn3;
  } NonInlinedSFcns;

  boolean_T zCCacheNeedsReset;
  boolean_T derivCacheNeedsReset;
  boolean_T CTOutputIncnstWithState;

  /*
   * Sizes:
   * The following substructure contains sizes information
   * for many of the model attributes such as inputs, outputs,
   * dwork, sample times, etc.
   */
  struct {
    uint32_T options;
    int_T numContStates;
    int_T numU;
    int_T numY;
    int_T numSampTimes;
    int_T numBlocks;
    int_T numBlockIO;
    int_T numBlockPrms;
    int_T numDwork;
    int_T numSFcnPrms;
    int_T numSFcns;
    int_T numIports;
    int_T numOports;
    int_T numNonSampZCs;
    int_T sysDirFeedThru;
    int_T rtwGenSfcn;
  } Sizes;

  /*
   * Timing:
   * The following substructure contains information regarding
   * the timing information for the model.
   */
  struct {
    time_T stepSize;
    uint32_T clockTick0;
    uint32_T clockTickH0;
    time_T stepSize0;
    uint32_T clockTick1;
    uint32_T clockTickH1;
    time_T stepSize1;
    time_T tStart;
    time_T tFinal;
    time_T timeOfLastOutput;
    SimTimeStep simTimeStep;
    boolean_T stopRequestedFlag;
    time_T *sampleTimes;
    time_T *offsetTimes;
    int_T *sampleTimeTaskIDPtr;
    int_T *sampleHits;
    int_T *perTaskSampleHits;
    time_T *t;
    time_T sampleTimesArray[2];
    time_T offsetTimesArray[2];
    int_T sampleTimeTaskIDArray[2];
    int_T sampleHitArray[2];
    int_T perTaskSampleHitsArray[4];
    time_T tArray[2];
  } Timing;
};

/* Block parameters (default storage) */
#ifdef __cplusplus

extern "C" {

#endif

  extern P_model_ColumnSetup_00_T model_ColumnSetup_00_P;

#ifdef __cplusplus

}
#endif

/* Block signals (default storage) */
#ifdef __cplusplus

extern "C" {

#endif

  extern B_model_ColumnSetup_00_T model_ColumnSetup_00_B;

#ifdef __cplusplus

}
#endif

/* Block states (default storage) */
extern DW_model_ColumnSetup_00_T model_ColumnSetup_00_DW;

/*
 * Exported Global Parameters
 *
 * Note: Exported global parameters are tunable parameters with an exported
 * global storage class designation.  Code generation will declare the memory for
 * these parameters and exports their symbols.
 *
 */
extern real_T dd_pause_enable;         /* Variable: dd_pause_enable
                                        * Referenced by: '<S1>/dd_pause_enable'
                                        */
extern real_T smooth_stop_enable;      /* Variable: smooth_stop_enable
                                        * Referenced by: '<S1>/smooth_stop_enable'
                                        */
extern real_T zero_measurements_enable;/* Variable: zero_measurements_enable
                                        * Referenced by: '<S13>/zero_measurements_enable'
                                        */

#ifdef __cplusplus

extern "C" {

#endif

  /* Model entry point functions */
  extern void model_ColumnSetup_00_initialize(void);
  extern void model_ColumnSetup_00_step(void);
  extern void model_ColumnSetup_00_terminate(void);

#ifdef __cplusplus

}
#endif

/* Real-time Model object */
#ifdef __cplusplus

extern "C" {

#endif

  extern RT_MODEL_model_ColumnSetup_00_T *const model_ColumnSetup_00_M;

#ifdef __cplusplus

}
#endif

/*-
 * The generated code includes comments that allow you to trace directly
 * back to the appropriate location in the model.  The basic format
 * is <system>/block_name, where system is the system number (uniquely
 * assigned by Simulink) and block_name is the name of the block.
 *
 * Use the MATLAB hilite_system command to trace the generated code back
 * to the model.  For example,
 *
 * hilite_system('<S3>')    - opens system 3
 * hilite_system('<S3>/Kp') - opens and selects block Kp which resides in S3
 *
 * Here is the system hierarchy for this model
 *
 * '<Root>' : 'model_ColumnSetup_00'
 * '<S1>'   : 'model_ColumnSetup_00/Signal Generation'
 * '<S2>'   : 'model_ColumnSetup_00/columnSetup'
 * '<S3>'   : 'model_ColumnSetup_00/Signal Generation/Band-Limited White Noise'
 * '<S4>'   : 'model_ColumnSetup_00/Signal Generation/Chirp Signal'
 * '<S5>'   : 'model_ColumnSetup_00/Signal Generation/Digital Filter Design'
 * '<S6>'   : 'model_ColumnSetup_00/Signal Generation/Pausable Time'
 * '<S7>'   : 'model_ColumnSetup_00/Signal Generation/Pausable Time1'
 * '<S8>'   : 'model_ColumnSetup_00/Signal Generation/Smooth Sine'
 * '<S9>'   : 'model_ColumnSetup_00/Signal Generation/Smooth Stop Command'
 * '<S10>'  : 'model_ColumnSetup_00/Signal Generation/Digital Filter Design/Check Signal Attributes'
 * '<S11>'  : 'model_ColumnSetup_00/columnSetup/Command to MTS'
 * '<S12>'  : 'model_ColumnSetup_00/columnSetup/File Log'
 * '<S13>'  : 'model_ColumnSetup_00/columnSetup/Measurements'
 * '<S14>'  : 'model_ColumnSetup_00/columnSetup/Measurements/Adaptive signal zeroing - dm'
 * '<S15>'  : 'model_ColumnSetup_00/columnSetup/Measurements/Adaptive signal zeroing - fm'
 */
#endif                                 /* RTW_HEADER_model_ColumnSetup_00_h_ */
