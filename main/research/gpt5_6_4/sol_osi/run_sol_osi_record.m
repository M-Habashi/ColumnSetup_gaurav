function metrics = run_sol_osi_record
%RUN_SOL_OSI_RECORD Replay the canonical SOL_OSI in the highlighted range.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(fileparts(here)));
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin')
cd(here)
clear functions
rehash

file = fullfile(project, 'saved_results', 'tests', 'gpt5_6_tests', ...
    '20260710_1845_plNew_authON_oscillations_unstableAtEnd.mat');
data = load(file);
if isfield(data, 'result'), data = data.result; end
first_active = find(data.dd_pause_enable_log(:) == 0, 1);
t = data.t(first_active:end);
u = data.u_osi(first_active:end);
dm = data.dm(first_active:end);
a = data.auth(first_active:end);
dt = data.dt;

model = data.dependencies.exp_tf;
p = model.pid_values;
if ~isfield(p, 'derivative_filter_N'), p.derivative_filter_N = 512; end
C = pid(p.P, p.I, p.D, 1/p.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H = model.H_dc_dm;
if get(H, 'Ts') == 0
    H = c2d(H, dt, 'zoh');
elseif abs(get(H, 'Ts')-dt) > 10*eps(dt)
    H = d2d(H, dt, 'zoh');
end

cfg = sol_osi('config', dt, C*H, struct());
state = sol_osi('state', cfg);
nstep = floor(min([numel(t), numel(u), numel(dm), numel(a)])/cfg.step_n);
tc = NaN(nstep, 1);
b = NaN(nstep, 1);
b_res = b;
for k = 1:nstep
    ii = (k-1)*cfg.step_n+(1:cfg.step_n);
    state.a_cmd = a(ii(1));
    [b(k), state, info] = sol_osi(u(ii), dm(ii), cfg, state);
    tc(k) = t(ii(end));
    b_res(k) = info.b_res;
end

highlight = tc >= 60.8924 & tc <= 67.9999;
metrics = struct( ...
    'selected_mean', mean(b(highlight)), ...
    'selected_min', min(b(highlight)), ...
    'selected_max', max(b(highlight)), ...
    'fraction_below_035', mean(b(highlight) < 0.35), ...
    'quiet_mean', mean(b_res(highlight)));
fprintf(['SOL_OSI selected mean/min/max %.6f / %.6f / %.6f, ' ...
    'quiet %.6f, below 0.35 %.1f%%\n'], metrics.selected_mean, ...
    metrics.selected_min, metrics.selected_max, metrics.quiet_mean, ...
    100*metrics.fraction_below_035)
end
