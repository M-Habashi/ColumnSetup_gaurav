#ifndef RTW_HEADER_model_ColumnSetup_00_cal_h_
#define RTW_HEADER_model_ColumnSetup_00_cal_h_
#include "rtwtypes.h"
#include "model_ColumnSetup_00_types.h"

/* Storage class 'PageSwitching', for system '<Root>' */
typedef struct {
  real_T BandLimitedWhiteNoise_Cov; /* Mask Parameter: BandLimitedWhiteNoise_Cov
                                     * Referenced by: '<S3>/Output'
                                     */
  real_T BandLimitedWhiteNoise_seed;
                                   /* Mask Parameter: BandLimitedWhiteNoise_seed
                                    * Referenced by: '<S3>/White Noise'
                                    */
  real_T TimeHistoryLookup_tableData[2];/* Expression: time_history(:,2)
                                         * Referenced by: '<S1>/Time History Lookup'
                                         */
  real_T TimeHistoryLookup_bp01Data[2];/* Expression: time_history(:,1)
                                        * Referenced by: '<S1>/Time History Lookup'
                                        */
  real_T BLWNPauseZero_Value;          /* Expression: 0
                                        * Referenced by: '<S1>/BLWN Pause Zero'
                                        */
  real_T Gain1_Gain;                   /* Expression: 0.15
                                        * Referenced by: '<S1>/Gain1'
                                        */
  real_T BLWNPauseGate_Threshold;      /* Expression: 0.5
                                        * Referenced by: '<S1>/BLWN Pause Gate'
                                        */
  real_T Gain_Gain;                    /* Expression: 0.5
                                        * Referenced by: '<S4>/Gain'
                                        */
  real_T Gain_Gain_b;                  /* Expression: 1
                                        * Referenced by: '<S1>/Gain'
                                        */
  real_T Constant1_Value;              /* Expression: 0
                                        * Referenced by: '<S1>/Constant1'
                                        */
  real_T Setup_P1_Size[2];             /* Computed Parameter: Setup_P1_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P1;                     /* Expression: id
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P2_Size[2];             /* Computed Parameter: Setup_P2_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P2;                     /* Expression: pciSlot
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P3_Size[2];             /* Computed Parameter: Setup_P3_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P3;                     /* Expression: triggerSignal
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P4_Size[2];             /* Computed Parameter: Setup_P4_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P4;                     /* Expression: cal
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P5_Size[2];             /* Computed Parameter: Setup_P5_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P5[7];                  /* Expression: daChannel
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P6_Size[2];             /* Computed Parameter: Setup_P6_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P6;                     /* Expression: range
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P7_Size[2];             /* Computed Parameter: Setup_P7_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P7;                     /* Expression: daMode
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P8_Size[2];             /* Computed Parameter: Setup_P8_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P8[7];                  /* Expression: daReset
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P9_Size[2];             /* Computed Parameter: Setup_P9_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P9[7];                  /* Expression: daInitValue
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P10_Size[2];            /* Computed Parameter: Setup_P10_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P10[7];                 /* Expression: daIndex
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P11_Size[2];            /* Computed Parameter: Setup_P11_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P11[4];                 /* Expression: doChannel
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P12_Size[2];            /* Computed Parameter: Setup_P12_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P12;                    /* Expression: doReset
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P13_Size[2];            /* Computed Parameter: Setup_P13_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P13;                    /* Expression: doInitValue
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P14_Size[2];            /* Computed Parameter: Setup_P14_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P14;                    /* Expression: dioDirLo
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P15_Size[2];            /* Computed Parameter: Setup_P15_Size
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Setup_P15;                    /* Expression: dioDirHi
                                        * Referenced by: '<S10>/Setup'
                                        */
  real_T Constant_Value;               /* Expression: 2
                                        * Referenced by: '<S1>/Constant'
                                        */
  real_T sine_amp_Value;               /* Expression: 2
                                        * Referenced by: '<S1>/sine_amp'
                                        */
  real_T sine_freq_Value;              /* Expression: 1
                                        * Referenced by: '<S1>/sine_freq'
                                        */
  real_T sine_setpoint_Value;          /* Expression: -5
                                        * Referenced by: '<S1>/sine_setpoint'
                                        */
  real_T WhiteNoise_Mean;              /* Expression: 0
                                        * Referenced by: '<S3>/White Noise'
                                        */
  real_T WhiteNoise_StdDev;            /* Computed Parameter: WhiteNoise_StdDev
                                        * Referenced by: '<S3>/White Noise'
                                        */
  real_T DigitalFilter_InitialStates;  /* Expression: 0
                                        * Referenced by: '<S5>/Digital Filter'
                                        */
  real_T DigitalFilter_Coefficients[131];
  /* Expression: [0.00012946263423023791 0.000201802505402940314 0.000344890714241278249 0.000539520066398483321 0.000790048815993902556 0.00109704860820652875 0.00145614066668182354 0.00185731290117687646 0.00228414660602320897 0.00271387861303170903 0.00311795085570092546 0.00346346741853643817 0.00371474868735020879 0.00383616484288291449 0.00379517013481009543 0.00356556558459923591 0.00313048799699837876 0.0024862666727050787 0.00164400511204603156 0.000631708757665863999 -0.000505660046906055653 -0.00170744883803255554 -0.00289952339925300716 -0.00399886789266523657 -0.00491871238798705524 -0.00557531237136617893 -0.00589492657218318103 -0.00582128314499867888 -0.00532207589096847598 -0.00439461787539684352 -0.00306958012653518178 -0.00141248049319674649 0.000477600337521285722 0.00247203916995587846 0.00441982611943538863 0.00615705334122740398 0.00751866950093036616 0.00835168795553385863 0.00852853488243243696 0.00796023651230604382 0.00660759901522492074 0.00448994317249431021 0.0016900575682941689 -0.00164501145548083191 -0.00530801890138347335 -0.00904032070327443274 -0.0125452252421596883 -0.015505253944900722 -0.0176021904450379407 -0.018538801139378943 -0.0180607114309476388 -0.015976775251304285 -0.0121765135329771502 -0.00664322392130679666 0.000538601696951956205 0.00918199613151220347 0.0190031144388601234 0.0296333074903259962 0.040637264198032319 0.0515361451551416272 0.0618342763827239988 0.0710477228249399712 0.0787327997013431979 0.084512788910927672 0.08810073226197912 0.0893170837427531422 0.08810073226197912 0.084512788910927672 0.0787327997013431979 0.0710477228249399712 0.0618342763827239988 0.0515361451551416272 0.040637264198032319 0.0296333074903259962 0.0190031144388601234 0.00918199613151220347 0.000538601696951956205 -0.00664322392130679666 -0.0121765135329771502 -0.015976775251304285 -0.0180607114309476388 -0.018538801139378943 -0.0176021904450379407 -0.015505253944900722 -0.0125452252421596883 -0.00904032070327443274 -0.00530801890138347335 -0.00164501145548083191 0.0016900575682941689 0.00448994317249431021 0.00660759901522492074 0.00796023651230604382 0.00852853488243243696 0.00835168795553385863 0.00751866950093036616 0.00615705334122740398 0.00441982611943538863 0.00247203916995587846 0.000477600337521285722 -0.00141248049319674649 -0.00306958012653518178 -0.00439461787539684352 -0.00532207589096847598 -0.00582128314499867888 -0.00589492657218318103 -0.00557531237136617893 -0.00491871238798705524 -0.00399886789266523657 -0.00289952339925300716 -0.00170744883803255554 -0.000505660046906055653 0.000631708757665863999 0.00164400511204603156 0.0024862666727050787 0.00313048799699837876 0.00356556558459923591 0.00379517013481009543 0.00383616484288291449 0.00371474868735020879 0.00346346741853643817 0.00311795085570092546 0.00271387861303170903 0.00228414660602320897 0.00185731290117687646 0.00145614066668182354 0.00109704860820652875 0.000790048815993902556 0.000539520066398483321 0.000344890714241278249 0.000201802505402940314 0.00012946263423023791]
   * Referenced by: '<S5>/Digital Filter'
   */
  real_T Controllerplaceholder_Gain;   /* Expression: 1
                                        * Referenced by: '<S2>/ Controller placeholder'
                                        */
  real_T signal_offset_InitialCondition;/* Expression: 0
                                         * Referenced by: '<S13>/signal_offset'
                                         */
  real_T AnalogOutput_P1_Size[2];    /* Computed Parameter: AnalogOutput_P1_Size
                                      * Referenced by: '<S10>/Analog Output'
                                      */
  real_T AnalogOutput_P1;              /* Expression: id
                                        * Referenced by: '<S10>/Analog Output'
                                        */
  real_T AnalogOutput_P2_Size[2];    /* Computed Parameter: AnalogOutput_P2_Size
                                      * Referenced by: '<S10>/Analog Output'
                                      */
  real_T AnalogOutput_P2[7];           /* Expression: index
                                        * Referenced by: '<S10>/Analog Output'
                                        */
  real_T AnalogOutput_P3_Size[2];    /* Computed Parameter: AnalogOutput_P3_Size
                                      * Referenced by: '<S10>/Analog Output'
                                      */
  real_T AnalogOutput_P3[7];           /* Expression: channels
                                        * Referenced by: '<S10>/Analog Output'
                                        */
  real_T AnalogOutput_P4_Size[2];    /* Computed Parameter: AnalogOutput_P4_Size
                                      * Referenced by: '<S10>/Analog Output'
                                      */
  real_T AnalogOutput_P4;              /* Expression: range
                                        * Referenced by: '<S10>/Analog Output'
                                        */
  real_T AnalogOutput_P5_Size[2];    /* Computed Parameter: AnalogOutput_P5_Size
                                      * Referenced by: '<S10>/Analog Output'
                                      */
  real_T AnalogOutput_P5;              /* Expression: ts
                                        * Referenced by: '<S10>/Analog Output'
                                        */
  real_T AnalogOutput_P6_Size[2];    /* Computed Parameter: AnalogOutput_P6_Size
                                      * Referenced by: '<S10>/Analog Output'
                                      */
  real_T AnalogOutput_P6;              /* Expression: pciSlot
                                        * Referenced by: '<S10>/Analog Output'
                                        */
  real_T Setup_P1_Size_n[2];           /* Computed Parameter: Setup_P1_Size_n
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P1_p;                   /* Expression: id
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P2_Size_f[2];           /* Computed Parameter: Setup_P2_Size_f
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P2_j;                   /* Expression: cal
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P3_Size_p[2];           /* Computed Parameter: Setup_P3_Size_p
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P3_h;                   /* Expression: initiator
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P4_Size_i[2];           /* Computed Parameter: Setup_P4_Size_i
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P4_m;                   /* Expression: pciSlot
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P5_Size_f[2];           /* Computed Parameter: Setup_P5_Size_f
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P5_o;                   /* Expression: adChannel
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P6_Size_g[2];           /* Computed Parameter: Setup_P6_Size_g
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P6_l;                   /* Expression: adRange
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P7_Size_e[2];           /* Computed Parameter: Setup_P7_Size_e
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P7_h;                   /* Expression: adCoupling
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P8_Size_l[2];           /* Computed Parameter: Setup_P8_Size_l
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P8_l;                   /* Expression: invertIO
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P9_Size_j[2];           /* Computed Parameter: Setup_P9_Size_j
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Setup_P9_d;                   /* Expression: adResolution
                                        * Referenced by: '<S12>/Setup'
                                        */
  real_T Analoginput_P1_Size[2];      /* Computed Parameter: Analoginput_P1_Size
                                       * Referenced by: '<S12>/Analog input'
                                       */
  real_T Analoginput_P1;               /* Expression: id
                                        * Referenced by: '<S12>/Analog input'
                                        */
  real_T Analoginput_P2_Size[2];      /* Computed Parameter: Analoginput_P2_Size
                                       * Referenced by: '<S12>/Analog input'
                                       */
  real_T Analoginput_P2;               /* Expression: channels
                                        * Referenced by: '<S12>/Analog input'
                                        */
  real_T Analoginput_P3_Size[2];      /* Computed Parameter: Analoginput_P3_Size
                                       * Referenced by: '<S12>/Analog input'
                                       */
  real_T Analoginput_P3;               /* Expression: range
                                        * Referenced by: '<S12>/Analog input'
                                        */
  real_T Analoginput_P4_Size[2];      /* Computed Parameter: Analoginput_P4_Size
                                       * Referenced by: '<S12>/Analog input'
                                       */
  real_T Analoginput_P4;               /* Expression: resolution
                                        * Referenced by: '<S12>/Analog input'
                                        */
  real_T Analoginput_P5_Size[2];      /* Computed Parameter: Analoginput_P5_Size
                                       * Referenced by: '<S12>/Analog input'
                                       */
  real_T Analoginput_P5;               /* Expression: ts
                                        * Referenced by: '<S12>/Analog input'
                                        */
  real_T Analoginput_P6_Size[2];      /* Computed Parameter: Analoginput_P6_Size
                                       * Referenced by: '<S12>/Analog input'
                                       */
  real_T Analoginput_P6;               /* Expression: pciSlot
                                        * Referenced by: '<S12>/Analog input'
                                        */
  real_T signal_offset_InitialConditio_b;/* Expression: 0
                                          * Referenced by: '<S14>/signal_offset'
                                          */
} model_ColumnSetup_00_cal_type;

/* Storage class 'PageSwitching' */

/* Storage class 'PageSwitching' */
extern model_ColumnSetup_00_cal_type model_ColumnSetup_00_cal_impl;
extern model_ColumnSetup_00_cal_type *model_ColumnSetup_00_cal;

#endif                              /* RTW_HEADER_model_ColumnSetup_00_cal_h_ */
