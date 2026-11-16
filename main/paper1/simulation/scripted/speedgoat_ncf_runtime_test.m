function result = speedgoat_ncf_runtime_test(targetName, runSeconds, buildOnly)
%SPEEDGOAT_NCF_RUNTIME_TEST Measure one complete NCF update on Speedgoat.
%   RESULT = SPEEDGOAT_NCF_RUNTIME_TEST() uses the default Simulink
%   Real-Time target selected in SLRT Explorer. The generated application
%   contains one 40.96-Hz real-time task. Every task step performs the
%   complete NCF calculation for Controllers A and B over 200 frequency
%   points from 1 to 200 Hz, giving 400 frequency-controller evaluations.
%   Therefore, the TET of the application's sole task is the measured time
%   required for one indicator update. Its deadline is 24.4140625 ms.
%
%   RESULT = SPEEDGOAT_NCF_RUNTIME_TEST("TargetPC1", 30) selects a named
%   target and collects target task-execution-time (TET) data for 30 s.
%
%   RESULT = SPEEDGOAT_NCF_RUNTIME_TEST("", 1, true) builds and simulates
%   the generated benchmark model locally without requiring Speedgoat.
%   This is only a construction/code-generation check and is not a valid
%   real-time-target timing result.
%
%   The Controller A/B gains are the current paper-case values. If those
%   controllers are retuned, update PI_A_KP/PI_A_KI and PI_B_KP/PI_B_KI in
%   ncf_kernel_script below before collecting manuscript-facing timings.

arguments
    targetName (1, 1) string = ""
    runSeconds (1, 1) double {mustBeFinite, mustBePositive} = 30
    buildOnly (1, 1) logical = false
end

baseRateHz = 4096;
indicatorStride = 100;
indicatorPeriod = indicatorStride / baseRateHz;
frequencyCount = 200;
frequencyMinimumHz = 1;
frequencyMaximumHz = 200;

scriptedDirectory = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDirectory);
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
modelName = ['sg_ncf_runtime_' timestamp];
outputDirectory = fullfile(projectRoot, 'Results', ...
    'speedgoat_ncf_runtime_test', timestamp);
if ~isfolder(outputDirectory)
    mkdir(outputDirectory)
end
modelPath = fullfile(outputDirectory, [modelName '.slx']);

originalDirectory = pwd;
directoryCleanup = onCleanup(@() cd(originalDirectory));
cd(outputDirectory)
create_benchmark_model(modelName, modelPath, indicatorPeriod)

result = struct;
result.CompletedAt = datetime('now');
result.BenchmarkType = "Isolated Speedgoat NCF-update TET benchmark";
result.ModelName = string(modelName);
result.ModelPath = string(modelPath);
result.VRTHSIntegrationRate_Hz = baseRateHz;
result.VRTHSIntegrationStepsPerIndicatorUpdate = indicatorStride;
result.BenchmarkTaskRate_Hz = 1 / indicatorPeriod;
result.BenchmarkTaskPeriod_ms = 1e3 * indicatorPeriod;
result.FrequencyCount = frequencyCount;
result.FrequencyMinimum_Hz = frequencyMinimumHz;
result.FrequencyMaximum_Hz = frequencyMaximumHz;
result.ControllerCount = 2;
result.FrequencyControllerEvaluationsPerUpdate = 2 * frequencyCount;
result.RunSeconds = runSeconds;

if buildOnly
    set_param(modelName, 'SystemTargetFile', 'grt.tlc');
    set_param(modelName, 'SimulationCommand', 'update');
    simulationOutput = sim(modelName, 'StopTime', '0.1', ...
        'ReturnWorkspaceOutputs', 'on');
    result.BenchmarkType = ...
        "Local model-construction check (not a real-time target result)";
    result.SimulationMetadata = simulationOutput.SimulationMetadata;
    result.ResultPath = string(fullfile(outputDirectory, ...
        'local_model_check.mat'));
    save(result.ResultPath, 'result')
    fprintf('\nLocal benchmark-model check passed.\n')
    fprintf('This is not a Speedgoat timing result.\n')
    fprintf('Generated model: %s\n\n', modelPath)
    bdclose(modelName)
    clear directoryCleanup
    return
end

if isempty(ver('slrealtime')) || ~license('test', 'Simulink_Real-Time')
    bdclose(modelName)
    error('scripted:SpeedgoatLicense', ...
        ['Simulink Real-Time is required to build and execute this ', ...
        'benchmark on a Speedgoat target.'])
end

if strlength(targetName) == 0
    target = slrealtime;
else
    target = slrealtime(targetName);
end
connect(target)
if ~isConnected(target)
    bdclose(modelName)
    error('scripted:SpeedgoatConnection', ...
        'Could not connect to Speedgoat target %s.', targetName)
end
if isRunning(target)
    bdclose(modelName)
    error('scripted:SpeedgoatBusy', ...
        ['The target is already running an application. Stop that ', ...
        'application before starting this benchmark.'])
end

configureModelForTargetPlatform(target, modelName)
set_param(modelName, 'CodeProfilingInstrumentation', 'Detailed');
save_system(modelName, modelPath)

fprintf('\nBuilding Speedgoat NCF benchmark application...\n')
slbuild(modelName)
load(target, modelName)
resetProfiler(target)

targetVersion = getVersion(target);
result.TargetName = string(target.TargetSettings.name);
result.TargetVersion = targetVersion;

runCleanup = onCleanup(@() stop_target_safely(target));
startProfiler(target, modelName)
start(target, 'StopTime', Inf, 'AutoImportFileLog', false)

% Let initialization effects settle before collecting status snapshots.
pause(2)
snapshotInterval = 0.1;
snapshotCount = max(1, ceil(runSeconds / snapshotInterval));
tetSnapshots = cell(snapshotCount, 1);
snapshotTime = zeros(snapshotCount, 1);
startTime = tic;
for index = 1:snapshotCount
    if ~isRunning(target)
        error('scripted:SpeedgoatStopped', ...
            'The real-time application stopped before the test completed.')
    end
    modelStatus = target.ModelStatus;
    tetSnapshots{index} = modelStatus.TETInfo;
    snapshotTime(index) = toc(startTime);
    pause(snapshotInterval)
end

stopProfiler(target)
stop(target)
clear runCleanup

profileStem = fullfile(outputDirectory, ...
    [modelName '_execution_profile']);
getProfilerData(target, modelName, profileStem)
profilePath = [profileStem '.perf'];

result.SnapshotTime_s = snapshotTime;
result.TETSnapshots = tetSnapshots;
result.LastTETInfo = tetSnapshots{end};
result.ProfilePath = string(profilePath);
result.ResultPath = string(fullfile(outputDirectory, ...
    'speedgoat_ncf_runtime_result.mat'));
save(result.ResultPath, 'result')

fprintf('\nSpeedgoat NCF runtime test completed.\n')
fprintf('  Sole target task: %.6g Hz (%.6g ms deadline)\n', ...
    result.BenchmarkTaskRate_Hz, result.BenchmarkTaskPeriod_ms)
fprintf(['  Workload: %d frequencies from %g to %g Hz x %d ', ...
    'controllers = %d evaluations/update\n'], frequencyCount, ...
    frequencyMinimumHz, frequencyMaximumHz, result.ControllerCount, ...
    result.FrequencyControllerEvaluationsPerUpdate)
fprintf('\nFinal target TET information:\n')
disp(result.LastTETInfo)
fprintf(['The application has one task, so its TET is the execution time ', ...
    'of one complete 400-evaluation NCF update.\n'])
fprintf('Profiler data: %s\n', profilePath)
fprintf('Complete result: %s\n\n', result.ResultPath)

bdclose(modelName)
clear directoryCleanup
end

function create_benchmark_model(modelName, modelPath, indicatorPeriod)
new_system(modelName)
open_system(modelName)
set_param(modelName, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', sprintf('%.17g', indicatorPeriod), ...
    'EnableMultiTasking', 'off', ...
    'StopTime', 'Inf', ...
    'SaveOutput', 'off', ...
    'SignalLogging', 'off');

add_block('simulink/Discrete/Unit Delay', ...
    [modelName '/Alpha state'], ...
    'Position', [80 80 130 110], ...
    'InitialCondition', '0.2', ...
    'SampleTime', sprintf('%.17g', indicatorPeriod));
add_block('simulink/Sources/Constant', ...
    [modelName '/Alpha increment'], ...
    'Position', [80 145 130 175], ...
    'Value', '1e-4', ...
    'SampleTime', sprintf('%.17g', indicatorPeriod));
add_block('simulink/Math Operations/Add', ...
    [modelName '/Advance alpha'], ...
    'Position', [180 82 210 173], ...
    'Inputs', '++');
add_block('simulink/Discontinuities/Saturation', ...
    [modelName '/Bound alpha'], ...
    'Position', [255 95 305 145], ...
    'UpperLimit', '1', ...
    'LowerLimit', '0.001');
functionPath = [modelName '/NCF A and B - 200 points'];
add_block('simulink/User-Defined Functions/MATLAB Function', ...
    functionPath, 'Position', [385 75 590 165]);
chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', functionPath);
if isempty(chart)
    error('scripted:SpeedgoatChart', ...
        'Could not access the generated MATLAB Function block.')
end
chart.Script = ncf_kernel_script;

add_block('simulink/Sinks/Out1', [modelName '/NCF margins'], ...
    'Position', [660 100 690 120]);

add_line(modelName, 'Alpha state/1', 'Advance alpha/1')
add_line(modelName, 'Alpha increment/1', 'Advance alpha/2')
add_line(modelName, 'Advance alpha/1', 'Bound alpha/1')
add_line(modelName, 'Bound alpha/1', 'Alpha state/1', 'autorouting', 'on')
add_line(modelName, 'Bound alpha/1', 'NCF A and B - 200 points/1')
add_line(modelName, 'NCF A and B - 200 points/1', 'NCF margins/1')

save_system(modelName, modelPath)
end

function script = ncf_kernel_script
lines = [
    "function bg = fcn(alpha)"
    "%#codegen"
    "% Two-controller NCF margin on 200 linearly spaced points, 1:200 Hz."
    "M_E = 37.869;"
    "K_E = 1190e3;"
    "ZETA_E = 0.0097;"
    "PI_A_KP = 1.3707518216953329;"
    "PI_A_KI = 72.152543298465318;"
    "PI_B_KP = 0.69372176774343919;"
    "PI_B_KI = 73.30528353642319;"
    "A1 = 2.1283e13;"
    "A2 = 4.2297e6;"
    "A3 = 3.3;"
    "B1 = 425;"
    "B2 = 9.9976e4;"
    "alpha = min(max(alpha, 0.001), 1);"
    "stiffness = alpha * K_E;"
    "damping = 2 * ZETA_E * sqrt(stiffness * M_E);"
    "d4 = damping + M_E * (A3 + B1);"
    "d3 = stiffness + (A3 + B1) * damping + A2 + M_E * (B1 * A3 + B2);"
    "d2 = stiffness * (A3 + B1) + damping * (B1 * A3 + B2) + B1 * A2 + B2 * A3 * M_E;"
    "d1 = stiffness * (B1 * A3 + B2) + B2 * A3 * damping + B2 * A2;"
    "d0 = B2 * A3 * stiffness;"
    "maxSigmaA = 0;"
    "maxSigmaB = 0;"
    "for frequencyIndex = 1:200"
    "    omega = 2 * pi * double(frequencyIndex);"
    "    s = complex(0, omega);"
    "    denominator = ((((M_E * s + d4) * s + d3) * s + d2) * s + d1) * s + d0;"
    "    plant = A1 / (denominator + A1);"
    "    plantAbsSquared = real(plant)^2 + imag(plant)^2;"
    "    controllerA = complex(PI_A_KP, -PI_A_KI / omega);"
    "    controllerB = complex(PI_B_KP, -PI_B_KI / omega);"
    "    closedA = 1 + plant * controllerA;"
    "    closedB = 1 + plant * controllerB;"
    "    closedAAbsSquared = max(real(closedA)^2 + imag(closedA)^2, realmin);"
    "    closedBAbsSquared = max(real(closedB)^2 + imag(closedB)^2, realmin);"
    "    controllerAAbsSquared = PI_A_KP^2 + (PI_A_KI / omega)^2;"
    "    controllerBAbsSquared = PI_B_KP^2 + (PI_B_KI / omega)^2;"
    "    sigmaA = sqrt((plantAbsSquared + 1) * (controllerAAbsSquared + 1) / closedAAbsSquared);"
    "    sigmaB = sqrt((plantAbsSquared + 1) * (controllerBAbsSquared + 1) / closedBAbsSquared);"
    "    maxSigmaA = max(maxSigmaA, sigmaA);"
    "    maxSigmaB = max(maxSigmaB, sigmaB);"
    "end"
    "bg = [1 / maxSigmaA; 1 / maxSigmaB];"
    "end"
    ];
script = char(strjoin(lines, newline));
end

function stop_target_safely(target)
try
    if isRunning(target)
        try
            stopProfiler(target)
        catch
        end
        stop(target)
    end
catch
end
end
