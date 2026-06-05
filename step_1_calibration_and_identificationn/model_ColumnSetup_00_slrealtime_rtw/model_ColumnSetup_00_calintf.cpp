#include "model_ColumnSetup_00_calintf.h"
#include "model_ColumnSetup_00.h"
#include "model_ColumnSetup_00_cal.h"

extern model_ColumnSetup_00_cal_type model_ColumnSetup_00_cal_impl;
namespace slrealtime
{
  /* Description of SEGMENTS */
  SegmentVector segmentInfo {
    {
      (void*)&model_ColumnSetup_00_cal_impl, (void**)&model_ColumnSetup_00_cal,
        sizeof(model_ColumnSetup_00_cal_type), 2
    } };

  SegmentVector &getSegmentVector(void)
  {
    return segmentInfo;
  }
}                                      // slrealtime
