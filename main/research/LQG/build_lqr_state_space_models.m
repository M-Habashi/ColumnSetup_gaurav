function result = build_lqr_state_space_models
%BUILD_LQR_STATE_SPACE_MODELS Build common-coordinate 7k and 5k models.

assets = lqg_assets;
refit = load(fullfile(assets.results, ...
    'lqr_7k_six_state_refit.mat'), 'result');
source5k = load(assets.system_5k, 'H_dc_dm');
transferFunctions = {refit.result.refitted_transfer_function, ...
    source5k.H_dc_dm};
fields = {'system_7k', 'system_5k'};
labels = {'7k six-state refit', '5k'};
sources = {fullfile(assets.results, 'lqr_7k_six_state_refit.mat'), ...
    assets.system_5k};
frequencyScaleRadPerSecond = 500;
frequencyHz = linspace(0.1, 100, 2000).';
stepTimeSeconds = linspace(0, 3, 1500).';

states = zeros(2, 1);
controllabilityRank = zeros(2, 1);
observabilityRank = zeros(2, 1);
maxFrequencyRelativeError = zeros(2, 1);
maxStepAbsoluteError = zeros(2, 1);

result = struct;
for i = 1:2
    transferFunction = transferFunctions{i};
    [numerator, denominator] = tfdata(transferFunction, 'v');
    stateCount = numel(denominator) - 1;
    numerator = [zeros(1, numel(denominator) - numel(numerator)), ...
        numerator];
    powers = stateCount:-1:0;
    scaledNumerator = numerator .* ...
        frequencyScaleRadPerSecond.^powers;
    scaledDenominator = denominator .* ...
        frequencyScaleRadPerSecond.^powers;
    [A, B, C, D] = tf2ss(scaledNumerator, scaledDenominator);
    normalizedStateSpace = ss(A, B, C, D);
    physicalStateSpace = ss(frequencyScaleRadPerSecond*A, ...
        frequencyScaleRadPerSecond*B, C, D);
    physicalStateSpace.InputName = 'dc';
    physicalStateSpace.OutputName = 'dm';

    transferResponse = squeeze(freqresp(transferFunction, ...
        2*pi*frequencyHz));
    stateResponse = squeeze(freqresp(physicalStateSpace, ...
        2*pi*frequencyHz));
    transferStep = step(transferFunction, stepTimeSeconds);
    stateStep = step(physicalStateSpace, stepTimeSeconds);

    states(i) = stateCount;
    controllabilityRank(i) = rank(ctrb(A, B));
    observabilityRank(i) = rank(obsv(A, C));
    maxFrequencyRelativeError(i) = max(abs(transferResponse(:) - ...
        stateResponse(:)) ./ max(abs(transferResponse(:)), eps));
    maxStepAbsoluteError(i) = max(abs(transferStep(:) - stateStep(:)));

    result.(fields{i}) = struct( ...
        'label', labels{i}, ...
        'source', sources{i}, ...
        'transfer_function', transferFunction, ...
        'normalized_state_space', normalizedStateSpace, ...
        'physical_state_space', physicalStateSpace, ...
        'A', A, ...
        'B', B, ...
        'C', C, ...
        'D', D);
end

result.frequency_scale_rad_per_second = frequencyScaleRadPerSecond;
result.coordinate_convention = ...
    'Common normalized controllable companion realization';
result.verification = table(labels.', states, controllabilityRank, ...
    observabilityRank, maxFrequencyRelativeError, maxStepAbsoluteError, ...
    'VariableNames', {'System', 'States', 'ControllabilityRank', ...
    'ObservabilityRank', 'MaxFrequencyRelativeError', ...
    'MaxStepAbsoluteError'});

outputFile = fullfile(assets.results, 'lqr_state_space_models.mat');
save(outputFile, 'result')
disp(result.verification)
fprintf('Saved common-coordinate models to %s\n', outputFile)
end
