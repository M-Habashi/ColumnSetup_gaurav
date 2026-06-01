/*
 * model_ColumnSetup_00.h
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

#ifndef RTW_HEADER_model_ColumnSetup_00_h_
#define RTW_HEADER_model_ColumnSetup_00_h_
#include <cmath>
#include <stddef.h>
#include <cstring>
#include <logsrv.h>
#include "rtwtypes.h"
#include "simstruc.h"
#include "fixedpoint.h"
#include "model_ColumnSetup_00_types.h"

/* Shared type includes */
#include "multiword_types.h"

/* Child system includes */
#include "model_ColumnSetup_00_cal.h"
#include "rt_nonfinite.h"
#include "rtGetInf.h"

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

/* Block signals (default storage) */
typedef struct {
  real_T time_history;                 /* '<S2>/From Workspace' */
  real_T SineWave;                     /* '<S2>/Sine Wave' */
  real_T WhiteNoise;                   /* '<S6>/White Noise' */
  real_T Output;                       /* '<S6>/Output' */
  real_T DigitalFilter;                /* '<S8>/Digital Filter' */
  real_T Gain1;                        /* '<S2>/Gain1' */
  real_T Clock1;                       /* '<S7>/Clock1' */
  real_T Product;                      /* '<S7>/Product' */
  real_T Gain;                         /* '<S7>/Gain' */
  real_T dd;                           /* '<S2>/Multiport Switch' */
  real_T dcmm;                         /* '<S1>/ Controller placeholder' */
  real_T AnalogControllervsDigitalContro;
  /* '<S1>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  ' */
  real_T u;                            /* '<S1>/  ' */
  real_T Sum1;                         /* '<S1>/Sum1' */
  real_T vcV;
  /* '<S1>/Saturation limit for the voltage signal  that is sent to the MTS' */
  real_T Populatecommand[7];           /* '<S3>/Populate command' */
  real_T Analoginput[18];              /* '<S5>/Analog input' */
  real_T Subtract1;                    /* '<S5>/Subtract1' */
  real_T Subtract2;                    /* '<S5>/Subtract2' */
  real_T Subtract4;                    /* '<S5>/Subtract4' */
  real_T Gain2;                        /* '<S1>/Gain2' */
  real_T dmmm;                         /* '<S1>/Add2' */
  real_T Gain4;                        /* '<S1>/Gain4' */
  real_T fmN;                          /* '<S1>/Add4' */
  real_T Gain1_g;                      /* '<S1>/Gain1' */
  real_T ammms2;                       /* '<S1>/Add1' */
  real_T Product1;                     /* '<S7>/Product1' */
  real_T Sum;                          /* '<S7>/Sum' */
  real_T Product2;                     /* '<S7>/Product2' */
  real_T Output_p;                     /* '<S7>/Output' */
  real_T Gain_c;                       /* '<S2>/Gain' */
  real_T Mux_51[6];
  /* '<S4>/TmpSignal ConversionAtTAQSigLogging_InsertedFor_Mux_5_at_outport_0Inport1' */
} B_model_ColumnSetup_00_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real_T DigitalFilter_states[130];    /* '<S8>/Digital Filter' */
  real_T NextOutput;                   /* '<S6>/White Noise' */
  real_T Setup_RWORK[2];               /* '<S3>/Setup' */
  real_T AnalogOutput_RWORK[2];        /* '<S3>/Analog Output' */
  real_T Setup_RWORK_h[2];             /* '<S5>/Setup' */
  real_T Analoginput_RWORK[2];         /* '<S5>/Analog input' */
  void *Setup_PWORK;                   /* '<S3>/Setup' */
  struct {
    void *TimePtr;
    void *DataPtr;
    void *RSimInfoPtr;
  } FromWorkspace_PWORK;               /* '<S2>/From Workspace' */

  void *AnalogOutput_PWORK;            /* '<S3>/Analog Output' */
  void *Setup_PWORK_o;                 /* '<S5>/Setup' */
  void *Analoginput_PWORK;             /* '<S5>/Analog input' */
  struct {
    void *LoggedData[3];
  } Scope_PWORK;                       /* '<S1>/Scope' */

  struct {
    void *AQHandles;
    void *SLRTSigHandles;
  } TAQSigLogging_InsertedFor_Mux_5;   /* synthesized block */

  uint32_T RandSeed;                   /* '<S6>/White Noise' */
  struct {
    int_T PrevIndex;
  } FromWorkspace_IWORK;               /* '<S2>/From Workspace' */

  int_T AnalogOutput_IWORK;            /* '<S3>/Analog Output' */
  int_T Setup_IWORK;                   /* '<S5>/Setup' */
  int_T Analoginput_IWORK;             /* '<S5>/Analog input' */
} DW_model_ColumnSetup_00_T;

/* Parameters (default storage) */
struct P_model_ColumnSetup_00_T_ {
  struct_KqGwiLEuE5vNox0GSlB1d ch;     /* Variable: ch
                                        * Referenced by:
                                        *   '<S5>/init_am'
                                        *   '<S5>/init_dm'
                                        *   '<S5>/init_fm'
                                        */
  real_T chirp_gain;                   /* Variable: chirp_gain
                                        * Referenced by: '<S2>/Gain'
                                        */
  real_T command_channel_selector[7];  /* Variable: command_channel_selector
                                        * Referenced by: '<S3>/Populate command'
                                        */
  real_T correction_gain;              /* Variable: correction_gain
                                        * Referenced by: '<S1>/ Analog Controller vs.  Digital Controller  Voltage-to-Voltage  Correction Gain  '
                                        */
  real_T f_final;                      /* Variable: f_final
                                        * Referenced by: '<S7>/deltaFreq'
                                        */
  real_T f_init;                       /* Variable: f_init
                                        * Referenced by:
                                        *   '<S7>/deltaFreq'
                                        *   '<S7>/initialFreq'
                                        */
  real_T ini_v[18];                    /* Variable: ini_v
                                        * Referenced by:
                                        *   '<S5>/init_am'
                                        *   '<S5>/init_dm'
                                        *   '<S5>/init_fm'
                                        */
  real_T sat_limit;                    /* Variable: sat_limit
                                        * Referenced by: '<S1>/Saturation limit for the voltage signal  that is sent to the MTS'
                                        */
  real_T tend_chirp;                   /* Variable: tend_chirp
                                        * Referenced by: '<S7>/targetTime'
                                        */
  real_T test_signal;                  /* Variable: test_signal
                                        * Referenced by: '<S2>/Constant'
                                        */
  real_T v2a_const;                    /* Variable: v2a_const
                                        * Referenced by: '<S1>/Constant1'
                                        */
  real_T v2a_gain;                     /* Variable: v2a_gain
                                        * Referenced by: '<S1>/Gain1'
                                        */
  real_T v2d_const;                    /* Variable: v2d_const
                                        * Referenced by:
                                        *   '<S1>/Constant3'
                                        *   '<S1>/Conversion factor from  engineering units to voltage. It is a linear regression with a slope and an offeset'
                                        */
  real_T v2d_gain;                     /* Variable: v2d_gain
                                        * Referenced by:
                                        *   '<S1>/Conversion factor from  engineering units to voltage. It is a linear regression with a slope and an offeset'
                                        *   '<S1>/  '
                                        *   '<S1>/Gain2'
                                        */
  real_T v2f_const;                    /* Variable: v2f_const
                                        * Referenced by: '<S1>/Constant5'
                                        */
  real_T v2f_gain;                     /* Variable: v2f_gain
                                        * Referenced by: '<S1>/Gain4'
                                        */
  real_T wn_power;                     /* Variable: wn_power
                                        * Referenced by: '<S6>/Output'
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
 * '<S1>'   : 'model_ColumnSetup_00/IsolatorSetup'
 * '<S2>'   : 'model_ColumnSetup_00/Signal Generation'
 * '<S3>'   : 'model_ColumnSetup_00/IsolatorSetup/Command to MTS'
 * '<S4>'   : 'model_ColumnSetup_00/IsolatorSetup/File Log'
 * '<S5>'   : 'model_ColumnSetup_00/IsolatorSetup/Measurements'
 * '<S6>'   : 'model_ColumnSetup_00/Signal Generation/Band-Limited White Noise'
 * '<S7>'   : 'model_ColumnSetup_00/Signal Generation/Chirp Signal'
 * '<S8>'   : 'model_ColumnSetup_00/Signal Generation/Digital Filter Design'
 * '<S9>'   : 'model_ColumnSetup_00/Signal Generation/Digital Filter Design/Check Signal Attributes'
 */
#endif                                 /* RTW_HEADER_model_ColumnSetup_00_h_ */
