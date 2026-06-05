/* Main generated for Simulink Real-Time model model_ColumnSetup_00 */
#include <ModelInfo.hpp>
#include "model_ColumnSetup_00.h"
#include "model_ColumnSetup_00_calintf.h"

/* Task descriptors */
slrealtime::TaskInfo task_1( 0u, std::bind(model_ColumnSetup_00_step), slrealtime::TaskInfo::PERIODIC, 0.000488281, 0, 40);

/* Model descriptor */
slrealtime::ModelInfo model_ColumnSetup_00_Info =
{
    "model_ColumnSetup_00",
    model_ColumnSetup_00_initialize,
    model_ColumnSetup_00_terminate,
    []()->char const*& { return model_ColumnSetup_00_M->errorStatus; },
    []()->unsigned char& { return model_ColumnSetup_00_M->Timing.stopRequestedFlag; },
    { task_1 },
    slrealtime::getSegmentVector()
};

int main(int argc, char *argv[]) {
    return slrealtime::runModel(argc, argv, model_ColumnSetup_00_Info);
}
