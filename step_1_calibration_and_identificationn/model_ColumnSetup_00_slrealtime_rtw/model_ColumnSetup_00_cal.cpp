#include "model_ColumnSetup_00.h"

/* Storage class 'PageSwitching' */

/* Storage class 'PageSwitching' */
model_ColumnSetup_00_cal_type model_ColumnSetup_00_cal_impl = {
  /* Mask Parameter: BandLimitedWhiteNoise_Cov
   * Referenced by: '<S3>/Output'
   */
  0.01,

  /* Mask Parameter: BandLimitedWhiteNoise_seed
   * Referenced by: '<S3>/White Noise'
   */
  22451.0,

  /* Expression: time_history(:,2)
   * Referenced by: '<S1>/Time History Lookup'
   */
  { 0.0, 0.0 },

  /* Expression: time_history(:,1)
   * Referenced by: '<S1>/Time History Lookup'
   */
  { 0.0, 0.00048828125 },

  /* Expression: 0
   * Referenced by: '<S1>/BLWN Pause Zero'
   */
  0.0,

  /* Expression: 0.15
   * Referenced by: '<S1>/Gain1'
   */
  0.15,

  /* Expression: 0.5
   * Referenced by: '<S1>/BLWN Pause Gate'
   */
  0.5,

  /* Expression: 0.5
   * Referenced by: '<S4>/Gain'
   */
  0.5,

  /* Expression: 1
   * Referenced by: '<S1>/Gain'
   */
  1.0,

  /* Expression: 0
   * Referenced by: '<S1>/Constant1'
   */
  0.0,

  /* Computed Parameter: Setup_P1_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: id
   * Referenced by: '<S11>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P2_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: pciSlot
   * Referenced by: '<S11>/Setup'
   */
  -1.0,

  /* Computed Parameter: Setup_P3_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: triggerSignal
   * Referenced by: '<S11>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P4_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: cal
   * Referenced by: '<S11>/Setup'
   */
  0.0,

  /* Computed Parameter: Setup_P5_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 7.0 },

  /* Expression: daChannel
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0 },

  /* Computed Parameter: Setup_P6_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: range
   * Referenced by: '<S11>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P7_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: daMode
   * Referenced by: '<S11>/Setup'
   */
  2.0,

  /* Computed Parameter: Setup_P8_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 7.0 },

  /* Expression: daReset
   * Referenced by: '<S11>/Setup'
   */
  { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },

  /* Computed Parameter: Setup_P9_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 7.0 },

  /* Expression: daInitValue
   * Referenced by: '<S11>/Setup'
   */
  { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },

  /* Computed Parameter: Setup_P10_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 7.0 },

  /* Expression: daIndex
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0 },

  /* Computed Parameter: Setup_P11_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 4.0 },

  /* Expression: doChannel
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 2.0, 3.0, 4.0 },

  /* Computed Parameter: Setup_P12_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: doReset
   * Referenced by: '<S11>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P13_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: doInitValue
   * Referenced by: '<S11>/Setup'
   */
  0.0,

  /* Computed Parameter: Setup_P14_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: dioDirLo
   * Referenced by: '<S11>/Setup'
   */
  2.0,

  /* Computed Parameter: Setup_P15_Size
   * Referenced by: '<S11>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: dioDirHi
   * Referenced by: '<S11>/Setup'
   */
  1.0,

  /* Expression: 5
   * Referenced by: '<S1>/Constant'
   */
  5.0,

  /* Expression: 1
   * Referenced by: '<S1>/sine_amp'
   */
  1.0,

  /* Expression: 1
   * Referenced by: '<S1>/sine_freq'
   */
  1.0,

  /* Expression: 0
   * Referenced by: '<S1>/sine_setpoint'
   */
  0.0,

  /* Expression: 0
   * Referenced by: '<S3>/White Noise'
   */
  0.0,

  /* Computed Parameter: WhiteNoise_StdDev
   * Referenced by: '<S3>/White Noise'
   */
  1.0,

  /* Expression: 0
   * Referenced by: '<S5>/Digital Filter'
   */
  0.0,

  /* Expression: [0.00012946263423023791 0.000201802505402940314 0.000344890714241278249 0.000539520066398483321 0.000790048815993902556 0.00109704860820652875 0.00145614066668182354 0.00185731290117687646 0.00228414660602320897 0.00271387861303170903 0.00311795085570092546 0.00346346741853643817 0.00371474868735020879 0.00383616484288291449 0.00379517013481009543 0.00356556558459923591 0.00313048799699837876 0.0024862666727050787 0.00164400511204603156 0.000631708757665863999 -0.000505660046906055653 -0.00170744883803255554 -0.00289952339925300716 -0.00399886789266523657 -0.00491871238798705524 -0.00557531237136617893 -0.00589492657218318103 -0.00582128314499867888 -0.00532207589096847598 -0.00439461787539684352 -0.00306958012653518178 -0.00141248049319674649 0.000477600337521285722 0.00247203916995587846 0.00441982611943538863 0.00615705334122740398 0.00751866950093036616 0.00835168795553385863 0.00852853488243243696 0.00796023651230604382 0.00660759901522492074 0.00448994317249431021 0.0016900575682941689 -0.0 */
  { 0.00012946263423023791, 0.00020180250540294031, 0.00034489071424127825,
    0.00053952006639848332, 0.00079004881599390256, 0.0010970486082065288,
    0.0014561406666818235, 0.0018573129011768765, 0.002284146606023209,
    0.002713878613031709, 0.0031179508557009255, 0.0034634674185364382,
    0.0037147486873502088, 0.0038361648428829145, 0.0037951701348100954,
    0.0035655655845992359, 0.0031304879969983788, 0.0024862666727050787,
    0.0016440051120460316, 0.000631708757665864, -0.00050566004690605565,
    -0.0017074488380325555, -0.0028995233992530072, -0.0039988678926652366,
    -0.0049187123879870552, -0.0055753123713661789, -0.005894926572183181,
    -0.0058212831449986789, -0.005322075890968476, -0.0043946178753968435,
    -0.0030695801265351818, -0.0014124804931967465, 0.00047760033752128572,
    0.0024720391699558785, 0.0044198261194353886, 0.006157053341227404,
    0.0075186695009303662, 0.0083516879555338586, 0.008528534882432437,
    0.0079602365123060438, 0.0066075990152249207, 0.00448994317249431,
    0.0016900575682941689, -0.0016450114554808319, -0.0053080189013834734,
    -0.0090403207032744327, -0.012545225242159688, -0.015505253944900722,
    -0.017602190445037941, -0.018538801139378943, -0.018060711430947639,
    -0.015976775251304285, -0.01217651353297715, -0.0066432239213067967,
    0.00053860169695195621, 0.0091819961315122035, 0.019003114438860123,
    0.029633307490325996, 0.040637264198032319, 0.051536145155141627,
    0.061834276382724, 0.071047722824939971, 0.0787327997013432,
    0.084512788910927672, 0.08810073226197912, 0.089317083742753142,
    0.08810073226197912, 0.084512788910927672, 0.0787327997013432,
    0.071047722824939971, 0.061834276382724, 0.051536145155141627,
    0.040637264198032319, 0.029633307490325996, 0.019003114438860123,
    0.0091819961315122035, 0.00053860169695195621, -0.0066432239213067967,
    -0.01217651353297715, -0.015976775251304285, -0.018060711430947639,
    -0.018538801139378943, -0.017602190445037941, -0.015505253944900722,
    -0.012545225242159688, -0.0090403207032744327, -0.0053080189013834734,
    -0.0016450114554808319, 0.0016900575682941689, 0.00448994317249431,
    0.0066075990152249207, 0.0079602365123060438, 0.008528534882432437,
    0.0083516879555338586, 0.0075186695009303662, 0.006157053341227404,
    0.0044198261194353886, 0.0024720391699558785, 0.00047760033752128572,
    -0.0014124804931967465, -0.0030695801265351818, -0.0043946178753968435,
    -0.005322075890968476, -0.0058212831449986789, -0.005894926572183181,
    -0.0055753123713661789, -0.0049187123879870552, -0.0039988678926652366,
    -0.0028995233992530072, -0.0017074488380325555, -0.00050566004690605565,
    0.000631708757665864, 0.0016440051120460316, 0.0024862666727050787,
    0.0031304879969983788, 0.0035655655845992359, 0.0037951701348100954,
    0.0038361648428829145, 0.0037147486873502088, 0.0034634674185364382,
    0.0031179508557009255, 0.002713878613031709, 0.002284146606023209,
    0.0018573129011768765, 0.0014561406666818235, 0.0010970486082065288,
    0.00079004881599390256, 0.00053952006639848332, 0.00034489071424127825,
    0.00020180250540294031, 0.00012946263423023791 },

  /* Expression: 1
   * Referenced by: '<S2>/ Controller placeholder'
   */
  1.0,

  /* Expression: 0
   * Referenced by: '<S14>/signal_offset'
   */
  0.0,

  /* Computed Parameter: AnalogOutput_P1_Size
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 1.0 },

  /* Expression: id
   * Referenced by: '<S11>/Analog Output'
   */
  1.0,

  /* Computed Parameter: AnalogOutput_P2_Size
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 7.0 },

  /* Expression: index
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0 },

  /* Computed Parameter: AnalogOutput_P3_Size
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 7.0 },

  /* Expression: channels
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0 },

  /* Computed Parameter: AnalogOutput_P4_Size
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 1.0 },

  /* Expression: range
   * Referenced by: '<S11>/Analog Output'
   */
  1.0,

  /* Computed Parameter: AnalogOutput_P5_Size
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 1.0 },

  /* Expression: ts
   * Referenced by: '<S11>/Analog Output'
   */
  0.00048828125,

  /* Computed Parameter: AnalogOutput_P6_Size
   * Referenced by: '<S11>/Analog Output'
   */
  { 1.0, 1.0 },

  /* Expression: pciSlot
   * Referenced by: '<S11>/Analog Output'
   */
  -1.0,

  /* Computed Parameter: Setup_P1_Size_n
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: id
   * Referenced by: '<S13>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P2_Size_f
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: cal
   * Referenced by: '<S13>/Setup'
   */
  0.0,

  /* Computed Parameter: Setup_P3_Size_p
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: initiator
   * Referenced by: '<S13>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P4_Size_i
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: pciSlot
   * Referenced by: '<S13>/Setup'
   */
  -1.0,

  /* Computed Parameter: Setup_P5_Size_f
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: adChannel
   * Referenced by: '<S13>/Setup'
   */
  18.0,

  /* Computed Parameter: Setup_P6_Size_g
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: adRange
   * Referenced by: '<S13>/Setup'
   */
  1.0,

  /* Computed Parameter: Setup_P7_Size_e
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: adCoupling
   * Referenced by: '<S13>/Setup'
   */
  3.0,

  /* Computed Parameter: Setup_P8_Size_l
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: invertIO
   * Referenced by: '<S13>/Setup'
   */
  0.0,

  /* Computed Parameter: Setup_P9_Size_j
   * Referenced by: '<S13>/Setup'
   */
  { 1.0, 1.0 },

  /* Expression: adResolution
   * Referenced by: '<S13>/Setup'
   */
  1.0,

  /* Computed Parameter: Analoginput_P1_Size
   * Referenced by: '<S13>/Analog input'
   */
  { 1.0, 1.0 },

  /* Expression: id
   * Referenced by: '<S13>/Analog input'
   */
  1.0,

  /* Computed Parameter: Analoginput_P2_Size
   * Referenced by: '<S13>/Analog input'
   */
  { 1.0, 1.0 },

  /* Expression: channels
   * Referenced by: '<S13>/Analog input'
   */
  18.0,

  /* Computed Parameter: Analoginput_P3_Size
   * Referenced by: '<S13>/Analog input'
   */
  { 1.0, 1.0 },

  /* Expression: range
   * Referenced by: '<S13>/Analog input'
   */
  1.0,

  /* Computed Parameter: Analoginput_P4_Size
   * Referenced by: '<S13>/Analog input'
   */
  { 1.0, 1.0 },

  /* Expression: resolution
   * Referenced by: '<S13>/Analog input'
   */
  1.0,

  /* Computed Parameter: Analoginput_P5_Size
   * Referenced by: '<S13>/Analog input'
   */
  { 1.0, 1.0 },

  /* Expression: ts
   * Referenced by: '<S13>/Analog input'
   */
  0.00048828125,

  /* Computed Parameter: Analoginput_P6_Size
   * Referenced by: '<S13>/Analog input'
   */
  { 1.0, 1.0 },

  /* Expression: pciSlot
   * Referenced by: '<S13>/Analog input'
   */
  -1.0,

  /* Expression: 0
   * Referenced by: '<S15>/signal_offset'
   */
  0.0
};

model_ColumnSetup_00_cal_type *model_ColumnSetup_00_cal =
  &model_ColumnSetup_00_cal_impl;
