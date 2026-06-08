projectFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn';
cd(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))

fs = 2048;
dt = 1/fs;
f1 = 20;
n = 1000000;
rng(1)

cases = [
    1.0 2
    2.5 2
    1.0 5
    ];

b = fir1(130, 2*f1*dt);
filterEnergy = sum(b.^2);

amp = cases(:, 1);
exceed_percentile = cases(:, 2);
measured_percent = zeros(size(amp));
measured_std = zeros(size(amp));
expected_std = zeros(size(amp));

for k = 1:numel(amp)
    expected_std(k) = blwnStdFromExceedance(amp(k), exceed_percentile(k));
    x = randn(n, 1)*expected_std(k)/sqrt(filterEnergy);
    y = filter(b, 1, x);
    y = y(numel(b)+1:end);
    measured_std(k) = std(y);
    measured_percent(k) = 100*mean(abs(y) > amp(k));
end

metrics = table(amp, exceed_percentile, expected_std, measured_std, measured_percent, ...
    'VariableNames', {'Amp', 'ExceedPercentile', 'ExpectedStd', 'MeasuredStd', 'MeasuredExceedancePercent'});

disp(metrics)
save('C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\.codex\verification\blwn_exceedance\metrics.mat', 'metrics')
