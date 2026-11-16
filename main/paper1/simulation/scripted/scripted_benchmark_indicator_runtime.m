function result = scripted_benchmark_indicator_runtime(repetitionCount, saveOutput)
%SCRIPTED_BENCHMARK_INDICATOR_RUNTIME Time the online NCF slow task.
%   RESULT = SCRIPTED_BENCHMARK_INDICATOR_RUNTIME() benchmarks the exact
%   frequency sweep used by BLK_INDICATOR_MARGIN. The RTHS major task runs
%   at fs, whereas the indicator slow task runs once every 100 major steps.
%   Each slow-task update evaluates the same 10,000 frequencies for the
%   active/blended controller and independently for Controllers A and B.
%
%   This command times MATLAB execution on the machine where it is called.
%   It is not, by itself, a Speedgoat or Simulink Real-Time measurement.
%   Run the deployed target profiler separately before describing a result
%   as real-time-target validation.

arguments
    repetitionCount (1, 1) double {mustBeInteger, mustBePositive} = 1000
    saveOutput (1, 1) logical = true
end

scriptedDirectory = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDirectory);
[configuration, configurationPath] = ...
    scripted_last_run_configuration(projectRoot);
if isempty(configuration)
    error('scripted:IndicatorBenchmarkConfiguration', ...
        ['No compatible last-run configuration was found. Run ', ...
        'scripted_main before benchmarking the indicator.'])
end

p = benchmark_parameters(configuration);
frequencyMinimum = 1e-1;
frequencyMaximum = 1e4;
frequencyCount = 10000;
slowTaskStride = 100;
slowTaskPeriod = slowTaskStride / p.fs;
slowTaskRate = 1 / slowTaskPeriod;
marginCount = 3;

% Vary alpha and beta so the benchmark cannot benefit from repeated output.
alpha = linspace(0.001, 1, repetitionCount).';
beta = 0.5 + 0.5 * sin(linspace(0, 4 * pi, repetitionCount).');

clear blk_indicator_margin
blk_indicator_margin(alpha(1), beta(1), p, false);
benchmark_slow_task(alpha(1), beta(1), p);

singleDuration = zeros(repetitionCount, 1);
slowTaskDuration = zeros(repetitionCount, 1);
for index = 1:repetitionCount
    startTime = tic;
    blk_indicator_margin(alpha(index), beta(index), p, false);
    singleDuration(index) = toc(startTime);

    startTime = tic;
    benchmark_slow_task(alpha(index), beta(index), p);
    slowTaskDuration(index) = toc(startTime);
end

mode = ["One margin"; "Three-margin slow task"];
marginEvaluations = [1; marginCount];
frequencyControllerPairs = frequencyCount * marginEvaluations;
medianMicroseconds = 1e6 * [median(singleDuration); median(slowTaskDuration)];
p95Microseconds = 1e6 * [percentile(singleDuration, 95); ...
    percentile(slowTaskDuration, 95)];
p99Microseconds = 1e6 * [percentile(singleDuration, 99); ...
    percentile(slowTaskDuration, 99)];
maximumMicroseconds = 1e6 * [max(singleDuration); max(slowTaskDuration)];
medianDeadlineUtilization = 100 * medianMicroseconds * 1e-6 / ...
    slowTaskPeriod;
p99DeadlineUtilization = 100 * p99Microseconds * 1e-6 / slowTaskPeriod;
maximumDeadlineUtilization = 100 * maximumMicroseconds * 1e-6 / ...
    slowTaskPeriod;

timing = table(mode, marginEvaluations, frequencyControllerPairs, ...
    medianMicroseconds, p95Microseconds, p99Microseconds, ...
    maximumMicroseconds, medianDeadlineUtilization, ...
    p99DeadlineUtilization, maximumDeadlineUtilization, ...
    'VariableNames', {'Mode', 'MarginEvaluations', ...
    'FrequencyControllerPairs', 'Median_us', 'P95_us', 'P99_us', ...
    'Maximum_us', 'MedianDeadlineUtilization_pct', ...
    'P99DeadlineUtilization_pct', 'MaximumDeadlineUtilization_pct'});

machine = machine_information;
result = struct;
result.BenchmarkType = "MATLAB host benchmark (not real-time target)";
result.CompletedAt = datetime('now');
result.ConfigurationPath = configurationPath;
result.RepetitionCount = repetitionCount;
result.SamplingFrequency_Hz = p.fs;
result.MajorStepPeriod_us = 1e6 / p.fs;
result.SlowTaskStride = slowTaskStride;
result.SlowTaskRate_Hz = slowTaskRate;
result.SlowTaskPeriod_ms = 1e3 * slowTaskPeriod;
result.FrequencyMinimum_rad_s = frequencyMinimum;
result.FrequencyMaximum_rad_s = frequencyMaximum;
result.UniqueFrequencyCountPerMargin = frequencyCount;
result.MarginEvaluationsPerSlowUpdate = marginCount;
result.FrequencyControllerPairsPerSlowUpdate = ...
    frequencyCount * marginCount;
result.Timing = timing;
result.Machine = machine;

fprintf('\nOnline NCF indicator runtime benchmark\n')
fprintf('  Benchmark type: %s\n', result.BenchmarkType)
fprintf('  Machine: %s\n', machine.Processor)
fprintf('  MATLAB: %s\n', machine.MATLAB)
fprintf(['  Major task: %.6g Hz (%.6g us); indicator task: %.6g Hz ', ...
    '(every %d steps, %.6g ms deadline)\n'], p.fs, ...
    result.MajorStepPeriod_us, slowTaskRate, slowTaskStride, ...
    result.SlowTaskPeriod_ms)
fprintf(['  Frequency grid: %d points from %.1g to %.1g rad/s; ', ...
    '%d margins per slow update (%d frequency-controller pairs)\n\n'], ...
    frequencyCount, frequencyMinimum, frequencyMaximum, marginCount, ...
    result.FrequencyControllerPairsPerSlowUpdate)
disp(timing)
fprintf(['These are host MATLAB timings. Do not report them as Speedgoat ', ...
    'or Simulink Real-Time measurements.\n\n'])

if saveOutput
    outputDirectory = fullfile(projectRoot, 'Results', ...
        'indicator_runtime_benchmark');
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory)
    end
    matPath = fullfile(outputDirectory, 'indicator_runtime_benchmark.mat');
    csvPath = fullfile(outputDirectory, 'indicator_runtime_benchmark.csv');
    textPath = fullfile(outputDirectory, 'indicator_runtime_benchmark.txt');
    result.OutputPaths = struct('MAT', matPath, 'CSV', csvPath, ...
        'Text', textPath);
    save(matPath, 'result', 'singleDuration', 'slowTaskDuration')
    writetable(timing, csvPath)
    write_text_report(textPath, result)
end
end

function values = benchmark_slow_task(alpha, beta, p)
values = [blk_indicator_margin(alpha, beta, p, false), ...
    blk_indicator_margin(alpha, 1, p, false), ...
    blk_indicator_margin(alpha, 0, p, false)];
end

function p = benchmark_parameters(configuration)
options = configuration.Options;
p = struct;
p.fs = options.fs;
p.m_e = 29.13;
if options.modified == 1
    p.m_e = 1.3 * p.m_e;
end
p.k_e = 1190e3;
p.z_e = 0.0097;
p.pi_a_kp = configuration.ControllerA.Kp;
p.pi_a_ki = configuration.ControllerA.Ki;
p.pi_b_kp = configuration.ControllerB.Kp;
p.pi_b_ki = configuration.ControllerB.Ki;
p.pi_c_kp = configuration.ControllerC.Kp;
p.pi_c_ki = configuration.ControllerC.Ki;
end

function value = percentile(data, probability)
ordered = sort(data(:));
position = 1 + (numel(ordered) - 1) * probability / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
if lowerIndex == upperIndex
    value = ordered(lowerIndex);
else
    fraction = position - lowerIndex;
    value = ordered(lowerIndex) * (1 - fraction) + ...
        ordered(upperIndex) * fraction;
end
end

function machine = machine_information
machine = struct;
machine.Hostname = string(getenv('COMPUTERNAME'));
if strlength(machine.Hostname) == 0
    machine.Hostname = string(getenv('HOSTNAME'));
end
machine.Processor = processor_name;
machine.Architecture = string(computer('arch'));
machine.LogicalCoresVisibleToMATLAB = feature('numcores');
machine.MATLAB = string(version);
machine.OperatingSystem = string(system_dependent('getos'));
end

function name = processor_name
name = "Unavailable";
if ispc
    [status, output] = system(['powershell -NoProfile -Command ', ...
        '"(Get-CimInstance Win32_Processor | Select-Object ', ...
        '-First 1 -ExpandProperty Name)"']);
elseif isunix
    [status, output] = system( ...
        'grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2-');
else
    status = 1;
    output = '';
end
if status == 0 && ~isempty(strtrim(output))
    name = string(strtrim(output));
end
end

function write_text_report(path, result)
file = fopen(path, 'w');
if file < 0
    error('scripted:IndicatorBenchmarkReport', ...
        'Could not open benchmark report for writing: %s', path)
end
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'Online NCF indicator runtime benchmark\n');
fprintf(file, 'Completed: %s\n', string(result.CompletedAt));
fprintf(file, 'Benchmark type: %s\n', result.BenchmarkType);
fprintf(file, 'Machine: %s\n', result.Machine.Processor);
fprintf(file, 'Architecture: %s\n', result.Machine.Architecture);
fprintf(file, 'MATLAB: %s\n', result.Machine.MATLAB);
fprintf(file, 'Operating system: %s\n', result.Machine.OperatingSystem);
fprintf(file, 'Repetitions: %d\n', result.RepetitionCount);
fprintf(file, 'RTHS sampling frequency: %.12g Hz\n', ...
    result.SamplingFrequency_Hz);
fprintf(file, 'Major-step period: %.12g us\n', result.MajorStepPeriod_us);
fprintf(file, 'Indicator stride: %d major steps\n', result.SlowTaskStride);
fprintf(file, 'Indicator update rate: %.12g Hz\n', result.SlowTaskRate_Hz);
fprintf(file, 'Indicator deadline: %.12g ms\n', result.SlowTaskPeriod_ms);
fprintf(file, 'Frequency range: %.12g to %.12g rad/s\n', ...
    result.FrequencyMinimum_rad_s, result.FrequencyMaximum_rad_s);
fprintf(file, 'Unique frequencies per margin: %d\n', ...
    result.UniqueFrequencyCountPerMargin);
fprintf(file, 'Margins per slow update: %d\n', ...
    result.MarginEvaluationsPerSlowUpdate);
fprintf(file, 'Frequency-controller pairs per slow update: %d\n\n', ...
    result.FrequencyControllerPairsPerSlowUpdate);
fprintf(file, ['Mode | Margins | Frequency-controller pairs | Median us | ', ...
    'P95 us | P99 us | Maximum us | Median deadline %% | P99 deadline %% ', ...
    '| Maximum deadline %%\n']);
for row = 1:height(result.Timing)
    fprintf(file, '%s | %d | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g\n', ...
        result.Timing.Mode(row), result.Timing.MarginEvaluations(row), ...
        result.Timing.FrequencyControllerPairs(row), ...
        result.Timing.Median_us(row), result.Timing.P95_us(row), ...
        result.Timing.P99_us(row), result.Timing.Maximum_us(row), ...
        result.Timing.MedianDeadlineUtilization_pct(row), ...
        result.Timing.P99DeadlineUtilization_pct(row), ...
        result.Timing.MaximumDeadlineUtilization_pct(row));
end
fprintf(file, '\n');
fprintf(file, ['Caution: these are host MATLAB timings, not Speedgoat or ', ...
    'Simulink Real-Time measurements.\n']);
clear cleanup
end
