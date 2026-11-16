function report = scripted_compare_sample_rates(runs)
%SCRIPTED_COMPARE_SAMPLE_RATES Compare same-rate fidelity and rate effects.
%
% Supply one element for each requested rate. Each element must have fs and
% scripted fields; simulink is optional. A result field may be either a
% result MAT-file name or the structure returned by scripted_run. For
% example:
%
% runs = [ ...
%     struct('fs', 4096, 'scripted', 'Results/scripted_4096_Nom_.mat', ...
%            'simulink', 'Results/simulink_4096_Nom_.mat'), ...
%     struct('fs', 2048, 'scripted', 'Results/scripted_2048_Nom_.mat', ...
%            'simulink', 'Results/simulink_2048_Nom_.mat'), ...
%     struct('fs', 1024, 'scripted', 'Results/scripted_1024_Nom_.mat', ...
%            'simulink', 'Results/simulink_1024_Nom_.mat')];
% report = scripted_compare_sample_rates(runs);
%
% For a same-rate comparison, the Simulink signal is linearly interpolated
% onto the scripted time grid. For 2048/1024-versus-4096 comparisons, the
% 4096-Hz signal is interpolated onto the lower-rate grid. Consequently no
% artificial samples are created in the lower-rate result. All signal
% errors are candidate minus reference-on-candidate-grid.

arguments
    runs (1,:) struct
end

required = {'fs', 'scripted'};
for runIndex = 1:numel(runs)
    missing = required(~isfield(runs(runIndex), required));
    if ~isempty(missing)
        error('scripted:ComparisonInput', ...
            'Run %d is missing field(s): %s.', runIndex, strjoin(missing, ', '));
    end
    validateattributes(runs(runIndex).fs, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, mfilename, 'runs.fs');
end

rates = [runs.fs];
if numel(unique(rates)) ~= numel(rates)
    error('scripted:ComparisonInput', 'Each run must use a distinct fs.')
end
baseIndex = find(rates == 4096, 1);
if isempty(baseIndex)
    error('scripted:ComparisonInput', ...
        'A 4096-Hz baseline run is required for rate comparisons.')
end

normalized = repmat(struct('fs', [], 'scripted', struct, ...
    'hasSimulink', false, 'simulink', struct), 1, numel(runs));
for runIndex = 1:numel(runs)
    normalized(runIndex).fs = runs(runIndex).fs;
    normalized(runIndex).scripted = load_result(runs(runIndex).scripted);
    normalized(runIndex).hasSimulink = isfield(runs, 'simulink') && ...
        ~isempty(runs(runIndex).simulink);
    if normalized(runIndex).hasSimulink
        normalized(runIndex).simulink = load_result(runs(runIndex).simulink);
    else
        normalized(runIndex).simulink = struct;
    end
end

report = struct;
emptyComparisons = struct('label', {}, 'reference_label', {}, ...
    'time_grid', {}, 'signal_errors', {}, 'j_metrics', {});
report.same_rate = emptyComparisons;
report.rate_effect_scripted = emptyComparisons;
report.rate_effect_simulink = emptyComparisons;

for runIndex = 1:numel(normalized)
    rate = normalized(runIndex).fs;
    if normalized(runIndex).hasSimulink
        label = sprintf('%g Hz: scripted vs Simulink', rate);
        comparison = compare_results(normalized(runIndex).scripted, ...
            normalized(runIndex).simulink, label, 'Simulink');
        report.same_rate(end + 1) = comparison;
        print_comparison(comparison);
    else
        fprintf('\n%g Hz: same-rate comparison skipped (no Simulink result supplied).\n', ...
            rate)
    end
end

baseline = normalized(baseIndex);
for runIndex = 1:numel(normalized)
    if runIndex == baseIndex
        continue
    end
    rate = normalized(runIndex).fs;
    label = sprintf('%g Hz scripted vs 4096 Hz scripted', rate);
    comparison = compare_results(normalized(runIndex).scripted, ...
        baseline.scripted, label, '4096 Hz scripted');
    report.rate_effect_scripted(end + 1) = comparison;
    print_comparison(comparison);

    if normalized(runIndex).hasSimulink && baseline.hasSimulink
        label = sprintf('%g Hz Simulink vs 4096 Hz Simulink', rate);
        comparison = compare_results(normalized(runIndex).simulink, ...
            baseline.simulink, label, '4096 Hz Simulink');
        report.rate_effect_simulink(end + 1) = comparison;
        print_comparison(comparison);
    end
end
end

function result = load_result(source)
if isstruct(source)
    result = source;
elseif ischar(source) || (isstring(source) && isscalar(source))
    source = char(source);
    if ~isfile(source)
        error('scripted:ComparisonInput', 'Result file does not exist: %s', source)
    end
    result = load(source);
else
    error('scripted:ComparisonInput', ...
        'A result must be a struct or a scalar MAT-file name.')
end
if ~isfield(result, 't') || ~isfield(result, 'eval_crit')
    error('scripted:ComparisonInput', ...
        'Each result must contain t and eval_crit.')
end
end

function comparison = compare_results(candidate, reference, label, referenceLabel)
comparison = struct;
comparison.label = label;
comparison.reference_label = referenceLabel;
comparison.time_grid = time_grid_summary(candidate.t, reference.t);
comparison.signal_errors = compare_signals(candidate, reference);
comparison.j_metrics = compare_metrics(candidate.eval_crit, reference.eval_crit);
end

function grid = time_grid_summary(candidateTime, referenceTime)
candidateTime = check_time(candidateTime, 'candidate');
referenceTime = check_time(referenceTime, 'reference');
startTime = max(candidateTime(1), referenceTime(1));
endTime = min(candidateTime(end), referenceTime(end));
candidateMask = candidateTime >= startTime & candidateTime <= endTime;
if ~any(candidateMask)
    error('scripted:ComparisonTime', 'The two result time grids do not overlap.')
end
grid = table(numel(candidateTime), numel(referenceTime), nnz(candidateMask), ...
    candidateTime(1), candidateTime(end), referenceTime(1), referenceTime(end), ...
    median(diff(candidateTime)), median(diff(referenceTime)), ...
    'VariableNames', {'CandidateSamples', 'ReferenceSamples', ...
    'ComparedSamples', 'CandidateStartSec', 'CandidateEndSec', ...
    'ReferenceStartSec', 'ReferenceEndSec', 'CandidateDtSec', ...
    'ReferenceDtSec'});
end

function signalErrors = compare_signals(candidate, reference)
signalNames = {'X_m', 'Num_resp', 'Ref_Resp', 'Force_act', 'alpha', 'indicator'};
rows = struct('Signal', {}, 'Channel', {}, 'Samples', {}, 'MaxAbs', {}, ...
    'RmsAbs', {}, 'NormalizedRmsPercent', {}, 'NormalizedPeakPercent', {});
for signalIndex = 1:numel(signalNames)
    signalName = signalNames{signalIndex};
    if ~isfield(candidate, signalName) || ~isfield(reference, signalName)
        continue
    end
    [candidateTime, candidateData] = extract_signal(candidate, signalName);
    [referenceTime, referenceData] = extract_signal(reference, signalName);
    [comparisonTime, candidateData, referenceData] = align_on_candidate_grid( ...
        candidateTime, candidateData, referenceTime, referenceData);
    for channel = 1:size(candidateData, 2)
        errorData = candidateData(:, channel) - referenceData(:, channel);
        referenceChannel = referenceData(:, channel);
        rmsReference = sqrt(mean(referenceChannel .^ 2));
        peakReference = max(abs(referenceChannel));
        if rmsReference == 0
            rmsReference = 1;
        end
        if peakReference == 0
            peakReference = 1;
        end
        rows(end + 1) = struct( ...
            'Signal', string(signalName), ...
            'Channel', channel, ...
            'Samples', numel(comparisonTime), ...
            'MaxAbs', max(abs(errorData)), ...
            'RmsAbs', sqrt(mean(errorData .^ 2)), ...
            'NormalizedRmsPercent', 100 * sqrt(mean(errorData .^ 2)) / rmsReference, ...
            'NormalizedPeakPercent', ...
            100 * max(abs(errorData)) / peakReference); %#ok<AGROW>
    end
end
if isempty(rows)
    signalErrors = table;
else
    signalErrors = struct2table(rows);
end
end

function metrics = compare_metrics(candidateMetrics, referenceMetrics)
candidateMetrics = candidateMetrics(:);
referenceMetrics = referenceMetrics(:);
if numel(candidateMetrics) ~= 9 || numel(referenceMetrics) ~= 9
    error('scripted:ComparisonMetrics', 'eval_crit must contain exactly nine J metrics.')
end
metricName = "J" + string((1:9).');
absoluteDifference = abs(candidateMetrics - referenceMetrics);
relativeDifference = nan(9, 1);
nonzeroReference = referenceMetrics ~= 0;
relativeDifference(nonzeroReference) = 100 * ...
    absoluteDifference(nonzeroReference) ./ abs(referenceMetrics(nonzeroReference));
metrics = table(metricName, candidateMetrics, referenceMetrics, ...
    absoluteDifference, relativeDifference, 'VariableNames', ...
    {'Metric', 'Candidate', 'Reference', 'AbsoluteDifference', ...
    'RelativeDifferencePercent'});
end

function [time, data] = extract_signal(result, signalName)
value = result.(signalName);
if isa(value, 'timeseries') || (isobject(value) && ...
        isprop(value, 'Time') && isprop(value, 'Data'))
    time = value.Time;
    data = value.Data;
else
    time = result.t;
    data = value;
end
time = check_time(time, signalName);
if isvector(data)
    data = data(:);
end
if size(data, 1) ~= numel(time)
    if size(data, 2) == numel(time)
        data = data.';
    else
        error('scripted:ComparisonSignal', ...
            '%s data does not have one row per time sample.', signalName)
    end
end
if ~isnumeric(data) || ~isreal(data) || any(~isfinite(data), 'all')
    error('scripted:ComparisonSignal', '%s contains non-finite data.', signalName)
end
end

function [time, candidateData, referenceData] = align_on_candidate_grid( ...
        candidateTime, candidateData, referenceTime, referenceData)
startTime = max(candidateTime(1), referenceTime(1));
endTime = min(candidateTime(end), referenceTime(end));
mask = candidateTime >= startTime & candidateTime <= endTime;
time = candidateTime(mask);
candidateData = candidateData(mask, :);
if isempty(time)
    error('scripted:ComparisonTime', 'The two signal time grids do not overlap.')
end
referenceData = interp1(referenceTime, referenceData, time, 'linear');
end

function time = check_time(time, label)
time = time(:);
if ~isnumeric(time) || ~isreal(time) || numel(time) < 2 || ...
        any(~isfinite(time)) || any(diff(time) <= 0)
    error('scripted:ComparisonTime', ...
        '%s time must be a strictly increasing finite vector.', label)
end
end

function print_comparison(comparison)
fprintf('\n%s\n', comparison.label)
disp(comparison.time_grid)
if isempty(comparison.signal_errors)
    fprintf('No common saved signals were available for comparison.\n')
else
    disp(comparison.signal_errors)
end
disp(comparison.j_metrics)
end
