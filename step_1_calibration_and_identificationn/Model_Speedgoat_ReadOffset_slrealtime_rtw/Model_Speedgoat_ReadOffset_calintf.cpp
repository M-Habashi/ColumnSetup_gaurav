#include "Model_Speedgoat_ReadOffset_calintf.h"
#include "Model_Speedgoat_ReadOffset.h"
#include "Model_Speedgoat_ReadOffset_cal.h"

extern Model_Speedgoat_ReadOf_cal_type Model_Speedgoat_ReadOf_cal_impl;
namespace slrealtime
{
  /* Description of SEGMENTS */
  SegmentVector segmentInfo {
    {
      (void*)&Model_Speedgoat_ReadOf_cal_impl, (void**)
        &Model_Speedgoat_ReadOffset_cal, sizeof(Model_Speedgoat_ReadOf_cal_type),
        2
    } };

  SegmentVector &getSegmentVector(void)
  {
    return segmentInfo;
  }
}                                      // slrealtime
