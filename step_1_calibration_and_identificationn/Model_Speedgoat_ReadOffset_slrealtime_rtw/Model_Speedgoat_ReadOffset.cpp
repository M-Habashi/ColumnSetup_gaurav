/*
 * Model_Speedgoat_ReadOffset.cpp
 *
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * Code generation for model "Model_Speedgoat_ReadOffset".
 *
 * Model version              : 1.23
 * Simulink Coder version : 9.4 (R2020b) 29-Jul-2020
 * C++ source code generated on : Sun May 31 20:48:39 2026
 *
 * Target selection: slrealtime.tlc
 * Note: GRT includes extra infrastructure and instrumentation for prototyping
 * Embedded hardware selection: Intel->x86-64 (Linux 64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#include "Model_Speedgoat_ReadOffset.h"
#include "Model_Speedgoat_ReadOffset_private.h"

/* Block signals (default storage) */
B_Model_Speedgoat_ReadOffset_T Model_Speedgoat_ReadOffset_B;

/* Block states (default storage) */
DW_Model_Speedgoat_ReadOffset_T Model_Speedgoat_ReadOffset_DW;

/* Real-time model */
RT_MODEL_Model_Speedgoat_ReadOffset_T Model_Speedgoat_ReadOffset_M_ =
  RT_MODEL_Model_Speedgoat_ReadOffset_T();
RT_MODEL_Model_Speedgoat_ReadOffset_T *const Model_Speedgoat_ReadOffset_M =
  &Model_Speedgoat_ReadOffset_M_;

/* Model step function */
void Model_Speedgoat_ReadOffset_step(void)
{
  /* S-Function (sg_IO112_setup_s): '<Root>/Setup' */

  /* Level2 S-Function Block: '<Root>/Setup' (sg_IO112_setup_s) */
  {
    SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[0];
    sfcnOutputs(rts,0);
  }

  /* S-Function (sg_IO112_ad_s): '<Root>/Analog input' */

  /* Level2 S-Function Block: '<Root>/Analog input' (sg_IO112_ad_s) */
  {
    SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[1];
    sfcnOutputs(rts,0);
  }

  /* Outputs for Atomic SubSystem: '<Root>/File Log' */

  /* ToAsyncQueueBlock generated from: '<S1>/Analog input' */
  slrtLogSignal
    (Model_Speedgoat_ReadOffset_DW.TAQSigLogging_InsertedFor_Ana_n.SLRTSigHandles,
     Model_Speedgoat_ReadOffset_M->Timing.t[0]);

  /* End of Outputs for SubSystem: '<Root>/File Log' */

  /* Update absolute time for base rate */
  /* The "clockTick0" counts the number of times the code of this task has
   * been executed. The absolute time is the multiplication of "clockTick0"
   * and "Timing.stepSize0". Size of "clockTick0" ensures timer will not
   * overflow during the application lifespan selected.
   * Timer of this task consists of two 32 bit unsigned integers.
   * The two integers represent the low bits Timing.clockTick0 and the high bits
   * Timing.clockTickH0. When the low bit overflows to 0, the high bits increment.
   */
  if (!(++Model_Speedgoat_ReadOffset_M->Timing.clockTick0)) {
    ++Model_Speedgoat_ReadOffset_M->Timing.clockTickH0;
  }

  Model_Speedgoat_ReadOffset_M->Timing.t[0] =
    Model_Speedgoat_ReadOffset_M->Timing.clockTick0 *
    Model_Speedgoat_ReadOffset_M->Timing.stepSize0 +
    Model_Speedgoat_ReadOffset_M->Timing.clockTickH0 *
    Model_Speedgoat_ReadOffset_M->Timing.stepSize0 * 4294967296.0;
}

/* Model initialize function */
void Model_Speedgoat_ReadOffset_initialize(void)
{
  /* Registration code */

  /* initialize non-finites */
  rt_InitInfAndNaN(sizeof(real_T));
  rtsiSetSolverName(&Model_Speedgoat_ReadOffset_M->solverInfo,
                    "FixedStepDiscrete");
  Model_Speedgoat_ReadOffset_M->solverInfoPtr =
    (&Model_Speedgoat_ReadOffset_M->solverInfo);

  /* Initialize timing info */
  {
    int_T *mdlTsMap = Model_Speedgoat_ReadOffset_M->Timing.sampleTimeTaskIDArray;
    mdlTsMap[0] = 0;
    Model_Speedgoat_ReadOffset_M->Timing.sampleTimeTaskIDPtr = (&mdlTsMap[0]);
    Model_Speedgoat_ReadOffset_M->Timing.sampleTimes =
      (&Model_Speedgoat_ReadOffset_M->Timing.sampleTimesArray[0]);
    Model_Speedgoat_ReadOffset_M->Timing.offsetTimes =
      (&Model_Speedgoat_ReadOffset_M->Timing.offsetTimesArray[0]);

    /* task periods */
    Model_Speedgoat_ReadOffset_M->Timing.sampleTimes[0] = (0.00048828125);

    /* task offsets */
    Model_Speedgoat_ReadOffset_M->Timing.offsetTimes[0] = (0.0);
  }

  rtmSetTPtr(Model_Speedgoat_ReadOffset_M,
             &Model_Speedgoat_ReadOffset_M->Timing.tArray[0]);

  {
    int_T *mdlSampleHits = Model_Speedgoat_ReadOffset_M->Timing.sampleHitArray;
    mdlSampleHits[0] = 1;
    Model_Speedgoat_ReadOffset_M->Timing.sampleHits = (&mdlSampleHits[0]);
  }

  rtmSetTFinal(Model_Speedgoat_ReadOffset_M, -1);
  Model_Speedgoat_ReadOffset_M->Timing.stepSize0 = 0.00048828125;
  Model_Speedgoat_ReadOffset_M->solverInfoPtr =
    (&Model_Speedgoat_ReadOffset_M->solverInfo);
  Model_Speedgoat_ReadOffset_M->Timing.stepSize = (0.00048828125);
  rtsiSetFixedStepSize(&Model_Speedgoat_ReadOffset_M->solverInfo, 0.00048828125);
  rtsiSetSolverMode(&Model_Speedgoat_ReadOffset_M->solverInfo,
                    SOLVER_MODE_SINGLETASKING);

  /* block I/O */
  (void) std::memset((static_cast<void *>(&Model_Speedgoat_ReadOffset_B)), 0,
                     sizeof(B_Model_Speedgoat_ReadOffset_T));

  /* states (dwork) */
  (void) std::memset(static_cast<void *>(&Model_Speedgoat_ReadOffset_DW), 0,
                     sizeof(DW_Model_Speedgoat_ReadOffset_T));

  /* child S-Function registration */
  {
    RTWSfcnInfo *sfcnInfo =
      &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.sfcnInfo;
    Model_Speedgoat_ReadOffset_M->sfcnInfo = (sfcnInfo);
    rtssSetErrorStatusPtr(sfcnInfo, (&rtmGetErrorStatus
      (Model_Speedgoat_ReadOffset_M)));
    rtssSetNumRootSampTimesPtr(sfcnInfo,
      &Model_Speedgoat_ReadOffset_M->Sizes.numSampTimes);
    Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.taskTimePtrs[0] = &(rtmGetTPtr
      (Model_Speedgoat_ReadOffset_M)[0]);
    rtssSetTPtrPtr(sfcnInfo,
                   Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.taskTimePtrs);
    rtssSetTStartPtr(sfcnInfo, &rtmGetTStart(Model_Speedgoat_ReadOffset_M));
    rtssSetTFinalPtr(sfcnInfo, &rtmGetTFinal(Model_Speedgoat_ReadOffset_M));
    rtssSetTimeOfLastOutputPtr(sfcnInfo, &rtmGetTimeOfLastOutput
      (Model_Speedgoat_ReadOffset_M));
    rtssSetStepSizePtr(sfcnInfo, &Model_Speedgoat_ReadOffset_M->Timing.stepSize);
    rtssSetStopRequestedPtr(sfcnInfo, &rtmGetStopRequested
      (Model_Speedgoat_ReadOffset_M));
    rtssSetDerivCacheNeedsResetPtr(sfcnInfo,
      &Model_Speedgoat_ReadOffset_M->derivCacheNeedsReset);
    rtssSetZCCacheNeedsResetPtr(sfcnInfo,
      &Model_Speedgoat_ReadOffset_M->zCCacheNeedsReset);
    rtssSetContTimeOutputInconsistentWithStateAtMajorStepPtr(sfcnInfo,
      &Model_Speedgoat_ReadOffset_M->CTOutputIncnstWithState);
    rtssSetSampleHitsPtr(sfcnInfo,
                         &Model_Speedgoat_ReadOffset_M->Timing.sampleHits);
    rtssSetPerTaskSampleHitsPtr(sfcnInfo,
      &Model_Speedgoat_ReadOffset_M->Timing.perTaskSampleHits);
    rtssSetSimModePtr(sfcnInfo, &Model_Speedgoat_ReadOffset_M->simMode);
    rtssSetSolverInfoPtr(sfcnInfo, &Model_Speedgoat_ReadOffset_M->solverInfoPtr);
  }

  Model_Speedgoat_ReadOffset_M->Sizes.numSFcns = (2);

  /* register each child */
  {
    (void) std::memset(static_cast<void *>
                       (&Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.childSFunctions
                        [0]), 0,
                       2*sizeof(SimStruct));
    Model_Speedgoat_ReadOffset_M->childSfunctions =
      (&Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.childSFunctionPtrs[0]);
    Model_Speedgoat_ReadOffset_M->childSfunctions[0] =
      (&Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.childSFunctions[0]);
    Model_Speedgoat_ReadOffset_M->childSfunctions[1] =
      (&Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.childSFunctions[1]);

    /* Level2 S-Function Block: Model_Speedgoat_ReadOffset/<Root>/Setup (sg_IO112_setup_s) */
    {
      SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[0];

      /* timing info */
      time_T *sfcnPeriod =
        Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn0.sfcnPeriod;
      time_T *sfcnOffset =
        Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn0.sfcnOffset;
      int_T *sfcnTsMap =
        Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn0.sfcnTsMap;
      (void) std::memset(static_cast<void*>(sfcnPeriod), 0,
                         sizeof(time_T)*1);
      (void) std::memset(static_cast<void*>(sfcnOffset), 0,
                         sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts,
                         &Model_Speedgoat_ReadOffset_M->
                         NonInlinedSFcns.blkInfo2[0]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.inputOutputPortInfo2[0]);

      /* Set up the mdlInfo pointer */
      ssSetRTWSfcnInfo(rts, Model_Speedgoat_ReadOffset_M->sfcnInfo);

      /* Allocate memory of model methods 2 */
      {
        ssSetModelMethods2(rts,
                           &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.methods2
                           [0]);
      }

      /* Allocate memory of model methods 3 */
      {
        ssSetModelMethods3(rts,
                           &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.methods3
                           [0]);
      }

      /* Allocate memory of model methods 4 */
      {
        ssSetModelMethods4(rts,
                           &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.methods4
                           [0]);
      }

      /* Allocate memory for states auxilliary information */
      {
        ssSetStatesInfo2(rts,
                         &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.statesInfo2
                         [0]);
        ssSetPeriodicStatesInfo(rts,
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.periodicStatesInfo[0]);
      }

      /* path info */
      ssSetModelName(rts, "Setup");
      ssSetPath(rts, "Model_Speedgoat_ReadOffset/Setup");
      ssSetRTModel(rts,Model_Speedgoat_ReadOffset_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      /* parameters */
      {
        mxArray **sfcnParams = (mxArray **)
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn0.params;
        ssSetSFcnParamsCount(rts, 9);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P1_Size);
        ssSetSFcnParam(rts, 1, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P2_Size);
        ssSetSFcnParam(rts, 2, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P3_Size);
        ssSetSFcnParam(rts, 3, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P4_Size);
        ssSetSFcnParam(rts, 4, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P5_Size);
        ssSetSFcnParam(rts, 5, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P6_Size);
        ssSetSFcnParam(rts, 6, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P7_Size);
        ssSetSFcnParam(rts, 7, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P8_Size);
        ssSetSFcnParam(rts, 8, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Setup_P9_Size);
      }

      /* work vectors */
      ssSetRWork(rts, (real_T *) &Model_Speedgoat_ReadOffset_DW.Setup_RWORK[0]);
      ssSetIWork(rts, (int_T *) &Model_Speedgoat_ReadOffset_DW.Setup_IWORK);
      ssSetPWork(rts, (void **) &Model_Speedgoat_ReadOffset_DW.Setup_PWORK);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn0.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn0.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        _ssSetNumDWork(rts, 3);

        /* RWORK */
        ssSetDWorkWidth(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_DOUBLE);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &Model_Speedgoat_ReadOffset_DW.Setup_RWORK[0]);

        /* IWORK */
        ssSetDWorkWidth(rts, 1, 1);
        ssSetDWorkDataType(rts, 1,SS_INTEGER);
        ssSetDWorkComplexSignal(rts, 1, 0);
        ssSetDWork(rts, 1, &Model_Speedgoat_ReadOffset_DW.Setup_IWORK);

        /* PWORK */
        ssSetDWorkWidth(rts, 2, 1);
        ssSetDWorkDataType(rts, 2,SS_POINTER);
        ssSetDWorkComplexSignal(rts, 2, 0);
        ssSetDWork(rts, 2, &Model_Speedgoat_ReadOffset_DW.Setup_PWORK);
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

    /* Level2 S-Function Block: Model_Speedgoat_ReadOffset/<Root>/Analog input (sg_IO112_ad_s) */
    {
      SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[1];

      /* timing info */
      time_T *sfcnPeriod =
        Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.sfcnPeriod;
      time_T *sfcnOffset =
        Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.sfcnOffset;
      int_T *sfcnTsMap =
        Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.sfcnTsMap;
      (void) std::memset(static_cast<void*>(sfcnPeriod), 0,
                         sizeof(time_T)*1);
      (void) std::memset(static_cast<void*>(sfcnOffset), 0,
                         sizeof(time_T)*1);
      ssSetSampleTimePtr(rts, &sfcnPeriod[0]);
      ssSetOffsetTimePtr(rts, &sfcnOffset[0]);
      ssSetSampleTimeTaskIDPtr(rts, sfcnTsMap);

      {
        ssSetBlkInfo2Ptr(rts,
                         &Model_Speedgoat_ReadOffset_M->
                         NonInlinedSFcns.blkInfo2[1]);
      }

      _ssSetBlkInfo2PortInfo2Ptr(rts,
        &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.inputOutputPortInfo2[1]);

      /* Set up the mdlInfo pointer */
      ssSetRTWSfcnInfo(rts, Model_Speedgoat_ReadOffset_M->sfcnInfo);

      /* Allocate memory of model methods 2 */
      {
        ssSetModelMethods2(rts,
                           &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.methods2
                           [1]);
      }

      /* Allocate memory of model methods 3 */
      {
        ssSetModelMethods3(rts,
                           &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.methods3
                           [1]);
      }

      /* Allocate memory of model methods 4 */
      {
        ssSetModelMethods4(rts,
                           &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.methods4
                           [1]);
      }

      /* Allocate memory for states auxilliary information */
      {
        ssSetStatesInfo2(rts,
                         &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.statesInfo2
                         [1]);
        ssSetPeriodicStatesInfo(rts,
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.periodicStatesInfo[1]);
      }

      /* outputs */
      {
        ssSetPortInfoForOutputs(rts,
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.outputPortInfo[0]);
        _ssSetNumOutputPorts(rts, 1);
        _ssSetPortInfo2ForOutputUnits(rts,
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.outputPortUnits[0]);
        ssSetOutputPortUnit(rts, 0, 0);
        _ssSetPortInfo2ForOutputCoSimAttribute(rts,
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.outputPortCoSimAttribute
          [0]);
        ssSetOutputPortIsContinuousQuantity(rts, 0, 0);

        /* port 0 */
        {
          _ssSetOutputPortNumDimensions(rts, 0, 1);
          ssSetOutputPortWidth(rts, 0, 18);
          ssSetOutputPortSignal(rts, 0, ((real_T *)
            Model_Speedgoat_ReadOffset_B.Analoginput));
        }
      }

      /* path info */
      ssSetModelName(rts, "Analog input");
      ssSetPath(rts, "Model_Speedgoat_ReadOffset/Analog input");
      ssSetRTModel(rts,Model_Speedgoat_ReadOffset_M);
      ssSetParentSS(rts, (NULL));
      ssSetRootSS(rts, rts);
      ssSetVersion(rts, SIMSTRUCT_VERSION_LEVEL2);

      /* parameters */
      {
        mxArray **sfcnParams = (mxArray **)
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.params;
        ssSetSFcnParamsCount(rts, 6);
        ssSetSFcnParamsPtr(rts, &sfcnParams[0]);
        ssSetSFcnParam(rts, 0, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Analoginput_P1_Size);
        ssSetSFcnParam(rts, 1, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Analoginput_P2_Size);
        ssSetSFcnParam(rts, 2, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Analoginput_P3_Size);
        ssSetSFcnParam(rts, 3, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Analoginput_P4_Size);
        ssSetSFcnParam(rts, 4, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Analoginput_P5_Size);
        ssSetSFcnParam(rts, 5, (mxArray*)
                       Model_Speedgoat_ReadOffset_cal->Analoginput_P6_Size);
      }

      /* work vectors */
      ssSetRWork(rts, (real_T *)
                 &Model_Speedgoat_ReadOffset_DW.Analoginput_RWORK[0]);
      ssSetIWork(rts, (int_T *) &Model_Speedgoat_ReadOffset_DW.Analoginput_IWORK);
      ssSetPWork(rts, (void **) &Model_Speedgoat_ReadOffset_DW.Analoginput_PWORK);

      {
        struct _ssDWorkRecord *dWorkRecord = (struct _ssDWorkRecord *)
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.dWork;
        struct _ssDWorkAuxRecord *dWorkAuxRecord = (struct _ssDWorkAuxRecord *)
          &Model_Speedgoat_ReadOffset_M->NonInlinedSFcns.Sfcn1.dWorkAux;
        ssSetSFcnDWork(rts, dWorkRecord);
        ssSetSFcnDWorkAux(rts, dWorkAuxRecord);
        _ssSetNumDWork(rts, 3);

        /* RWORK */
        ssSetDWorkWidth(rts, 0, 2);
        ssSetDWorkDataType(rts, 0,SS_DOUBLE);
        ssSetDWorkComplexSignal(rts, 0, 0);
        ssSetDWork(rts, 0, &Model_Speedgoat_ReadOffset_DW.Analoginput_RWORK[0]);

        /* IWORK */
        ssSetDWorkWidth(rts, 1, 1);
        ssSetDWorkDataType(rts, 1,SS_INTEGER);
        ssSetDWorkComplexSignal(rts, 1, 0);
        ssSetDWork(rts, 1, &Model_Speedgoat_ReadOffset_DW.Analoginput_IWORK);

        /* PWORK */
        ssSetDWorkWidth(rts, 2, 1);
        ssSetDWorkDataType(rts, 2,SS_POINTER);
        ssSetDWorkComplexSignal(rts, 2, 0);
        ssSetDWork(rts, 2, &Model_Speedgoat_ReadOffset_DW.Analoginput_PWORK);
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

  /* Start for S-Function (sg_IO112_setup_s): '<Root>/Setup' */
  /* Level2 S-Function Block: '<Root>/Setup' (sg_IO112_setup_s) */
  {
    SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[0];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  /* Start for S-Function (sg_IO112_ad_s): '<Root>/Analog input' */
  /* Level2 S-Function Block: '<Root>/Analog input' (sg_IO112_ad_s) */
  {
    SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[1];
    sfcnStart(rts);
    if (ssGetErrorStatus(rts) != (NULL))
      return;
  }

  /* SystemInitialize for Atomic SubSystem: '<Root>/File Log' */

  /* Start for ToAsyncQueueBlock generated from: '<S1>/Analog input' */
  Model_Speedgoat_ReadOffset_DW.TAQSigLogging_InsertedFor_Ana_n.SLRTSigHandles =
    slrtRegisterSignalToLoggingService(reinterpret_cast<uintptr_t>
    (&Model_Speedgoat_ReadOffset_B.Analoginput[0]));

  /* End of SystemInitialize for SubSystem: '<Root>/File Log' */
}

/* Model terminate function */
void Model_Speedgoat_ReadOffset_terminate(void)
{
  /* Terminate for S-Function (sg_IO112_setup_s): '<Root>/Setup' */
  /* Level2 S-Function Block: '<Root>/Setup' (sg_IO112_setup_s) */
  {
    SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[0];
    sfcnTerminate(rts);
  }

  /* Terminate for S-Function (sg_IO112_ad_s): '<Root>/Analog input' */
  /* Level2 S-Function Block: '<Root>/Analog input' (sg_IO112_ad_s) */
  {
    SimStruct *rts = Model_Speedgoat_ReadOffset_M->childSfunctions[1];
    sfcnTerminate(rts);
  }
}
