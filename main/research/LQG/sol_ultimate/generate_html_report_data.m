function result = generate_html_report_data
%GENERATE_HTML_REPORT_DATA Export reproducible step and Bode plot data.

studyFolder = fileparts(mfilename('fullpath'));
lqgFolder = fileparts(studyFolder);
modelsData = load(fullfile(lqgFolder, 'results', ...
    'lqr_state_space_models.mat'), 'result');
designData = load(fullfile(lqgFolder, 'results', ...
    'lqr_baseline_design.mat'), 'result');
lqgiData = load(fullfile(studyFolder, 'lqgi_comparator.mat'), 'result');
models = modelsData.result;
design = designData.result;
lqgi = lqgiData.result;
dt = 1/2048;
scale = models.frequency_scale_rad_per_second;

continuous7k = ss(scale*models.system_7k.A, ...
    scale*models.system_7k.B, models.system_7k.C, 0);
continuous5k = ss(scale*models.system_5k.A, ...
    scale*models.system_5k.B, models.system_5k.C, 0);
continuousPlants = {continuous7k, continuous5k};
discretePlants = {c2d(continuous7k, dt, 'zoh'), ...
    c2d(continuous5k, dt, 'zoh')};
nominal = discretePlants{1};

refitData = load(models.system_7k.source, 'result');
source7k = load(refitData.result.source, 'H_dd_dm');
source5k = load(models.system_5k.source, 'H_dd_dm');
pidLoops = {source7k.H_dd_dm, source5k.H_dd_dm};

selected = lqgi.selected_index;
KIntegral = lqgi.state_gain(selected, :);
Ki = lqgi.integral_gain(selected);
LDiscrete = dlqe(nominal.A, nominal.B, nominal.C, ...
    lqgi.definition.estimator_q_over_r, 1);
integralLoops = cell(2, 1);
lqrLoops = cell(2, 1);
ordinaryLqgLoops = cell(2, 1);
LContinuous = lqe(continuous7k.A, continuous7k.B, ...
    continuous7k.C, 1, 1);
for i = 1:2
    integralLoops{i} = integralReferenceLoop(discretePlants{i}, ...
        nominal, KIntegral, Ki, LDiscrete, dt);
    [A, B, C] = ssdata(continuousPlants{i});
    lqrLoops{i} = ss(A-B*design.K, B*design.nbar, C, 0);
    ordinaryLqgLoops{i} = observerReferenceLoop(continuousPlants{i}, ...
        continuous7k, design.K, design.nbar, LContinuous);
end

stepTime = (0:dt:0.6).';
exportIndex = (1:2:numel(stepTime)).';
result = struct;
result.metadata = struct( ...
    'sample_time_s', dt, ...
    'frequency_band_hz', [2 80], ...
    'ordinary_lqg_q_over_r', 1, ...
    'generated_utc', char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));
result.step = struct('time_s', stepTime(exportIndex), ...
    'condition7k', responseSet(1, stepTime, exportIndex, pidLoops, ...
        lqrLoops, ordinaryLqgLoops, integralLoops), ...
    'condition5k', responseSet(2, stepTime, exportIndex, pidLoops, ...
        lqrLoops, ordinaryLqgLoops, integralLoops));

frequencyHz = logspace(log10(2), log10(80), 320).';
result.bode = struct('frequency_hz', frequencyHz, ...
    'condition7k', bodeSet(1, frequencyHz, pidLoops, lqrLoops, ...
        integralLoops), ...
    'condition5k', bodeSet(2, frequencyHz, pidLoops, lqrLoops, ...
        integralLoops));

save(fullfile(studyFolder, 'html_report_plot_data.mat'), 'result')
json = jsonencode(result);
webDataFolder = fullfile(studyFolder, 'LQG_web', 'data');
if ~isfolder(webDataFolder)
    mkdir(webDataFolder)
end
outputFile = fullfile(webDataFolder, 'report-plot-data.js');
fileId = fopen(outputFile, 'w');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'window.SOL_ULTIMATE_PLOT_DATA = %s;\n', json);
fprintf('Saved HTML report plot data to %s\n', outputFile)
end

function output = responseSet(index, time, exportIndex, pidLoops, ...
        lqrLoops, ordinaryLqgLoops, integralLoops)
output = struct( ...
    'pid', column(step(pidLoops{index}, time), exportIndex), ...
    'lqr', column(step(lqrLoops{index}, time), exportIndex), ...
    'ordinary_lqg', column(step(ordinaryLqgLoops{index}, time), ...
        exportIndex), ...
    'lqgi', column(step(integralLoops{index}, time), exportIndex));
end

function output = bodeSet(index, frequencyHz, pidLoops, lqrLoops, ...
        integralLoops)
systems = {pidLoops{index}, lqrLoops{index}, integralLoops{index}};
names = {'pid', 'lqr', 'lqgi'};
output = struct;
for i = 1:numel(systems)
    response = squeeze(freqresp(systems{i}, 2*pi*frequencyHz));
    output.(names{i}) = struct( ...
        'magnitude_db', column(mag2db(abs(response))), ...
        'phase_deg', column(rad2deg(unwrap(angle(response)))));
end
end

function system = integralReferenceLoop(plant, nominal, K, Ki, L, dt)
[Ap, Bp, Cp] = ssdata(plant);
[An, Bn, Cn] = ssdata(nominal);
stateCount = size(Ap, 1);
A = [Ap, -Bp*K, -Bp*Ki; ...
    L*Cp, An-Bn*K-L*Cn, -Bn*Ki; ...
    -dt*Cp, zeros(1, stateCount), 1];
Br = [zeros(2*stateCount, 1); dt];
Cy = [Cp, zeros(1, stateCount+1)];
system = ss(A, Br, Cy, 0, dt);
end

function system = observerReferenceLoop(plant, nominal, K, nbar, L)
[Ap, Bp, Cp] = ssdata(plant);
[An, Bn, Cn] = ssdata(nominal);
stateCount = size(Ap, 1);
A = [Ap, -Bp*K; L*Cp, An-Bn*K-L*Cn];
Br = [Bp*nbar; Bn*nbar];
Cy = [Cp, zeros(1, stateCount)];
system = ss(A, Br, Cy, 0);
end

function value = column(value, index)
value = value(:);
if nargin > 1
    value = value(index);
end
end
