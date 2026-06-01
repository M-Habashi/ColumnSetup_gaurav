/* Main generated for Simulink Real-Time model Model_Speedgoat_ReadOffset */
#include <ModelInfo.hpp>
#include "Model_Speedgoat_ReadOffset.h"
#include "Model_Speedgoat_ReadOffset_calintf.h"

/* Task descriptors */
slrealtime::TaskInfo task_1( 0u, std::bind(Model_Speedgoat_ReadOffset_step), slrealtime::TaskInfo::PERIODIC, 0.000488281, 0, 40);

/* Model descriptor */
slrealtime::ModelInfo Model_Speedgoat_ReadOffset_Info =
{
    "Model_Speedgoat_ReadOffset",
    Model_Speedgoat_ReadOffset_initialize,
    Model_Speedgoat_ReadOffset_terminate,
    []()->char const*& { return Model_Speedgoat_ReadOffset_M->errorStatus; },
    []()->unsigned char& { return Model_Speedgoat_ReadOffset_M->Timing.stopRequestedFlag; },
    { task_1 },
    slrealtime::getSegmentVector()
};

int main(int argc, char *argv[]) {
    return slrealtime::runModel(argc, argv, Model_Speedgoat_ReadOffset_Info);
}
