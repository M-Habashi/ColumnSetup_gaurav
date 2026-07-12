function replay = analyze_osi(test_file, exp_tf_file)
%% Analyze GPT-5.6.4 OSI replay from a saved test result.
% Selects saved_results/tests with the standard numbered picker when a test
% path is not supplied. The actuator model is read from the test's embedded
% dependencies unless an explicit model is supplied. Edit the parameters
% below, then rerun this function to compare tuning choices.

script_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(script_folder);
addpath(fullfile(project_folder, 'helpers', 'utils'))
addpath(genpath(fullfile(project_folder, 'control_and_HS', 'OSI')))

%% Tunable parameters
% OSI: step_s is the output/update spacing (shorter responds sooner but is
% noisier); segment_s is the spectrum length (longer is smoother but slower).
% memory_s, margin_s, and residual_s are exponential memories: increasing
% them smooths their respective terms and delays their response.
% quiet_rms is the command activity threshold: increasing it makes quiet
% data less influential; residual_band_hz chooses the quiet-band model fit.
% detector_max caps the fast drive-ratio kick on rho (needs 2 consecutive
% hot updates); rho_leak_s is the idle decay time of the damage memory —
% shorter recovers authority faster after quiet but forgets real faults
% equally fast.
osi_override = struct( ...
    'step_s', 0.125, ...
    'segment_s', 0.5, ...
    'memory_s', 0.25, ...
    'margin_s', 0.15, ...
    'residual_s', 0.50, ...
    'quiet_rms', 0.06, ...
    'fit_floor', 0.175, ...
    'detector_max', 2.0, ...
    'rho_leak_s', 2.0, ...
    'band_hz', [2 100], ...
    'residual_band_hz', [28 44]);

% Authority: target is read from the saved test when available; this fallback
% is used only for legacy results. guard/deadband add safety
% margin and suppress small adjustments. rate controls the log-integral
% response; max_step caps each update; a_min/a_max bound the authority range.
auth_override = struct( ...
    'target', 0.55, ...
    'guard', 0.02, ...
    'deadband', 0.008, ...
    'rate', 5.0, ...
    'max_step', 0.05, ...
    'a_min', 0.20, ...
    'a_max', 1.00, ...
    'a_init', 1.00);

if nargin < 1 || isempty(test_file)
    [data, test_file, test_name] = load_saved_result_file( ...
        project_folder, 'tests', false, '', false);
elseif isstruct(test_file)
    data = test_file;
    test_file = '';
    test_name = fieldOr(data, 'file', 'In-memory result');
else
    data = load(test_file);
    [~, test_name, ext] = fileparts(test_file);
    test_name = [test_name ext];
end
result = unwrapResult(data);
if isfield(result, 'hs') && isfield(result.hs, 'target_outer_ncf')
    auth_override.target = result.hs.target_outer_ncf;
end
if nargin < 2 || isempty(exp_tf_file)
    assert(isfield(result, 'dependencies') ...
        && isfield(result.dependencies, 'exp_tf'), ...
        ['The selected test does not contain an embedded experimental ' ...
        'transfer function.'])
    model_data = result.dependencies.exp_tf;
    exp_tf_file = '<embedded actuator model>';
elseif isstruct(exp_tf_file)
    model_data = exp_tf_file;
    exp_tf_file = '<embedded actuator model>';
else
    model_data = load(exp_tf_file);
end
assert(isfield(model_data, 'H_dc_dm'), ...
    'The selected system-ID file must contain H_dc_dm.')

[t, u_osi, dm, dt] = replaySignals(result);
loop_tf = makeLoop(model_data, dt);
a_acted = loggedAuthority(result, numel(t));
replay = gpt5_6('run', t, u_osi, dm, dt, loop_tf, ...
    struct('osi', osi_override, 'auth', auth_override), a_acted);
replay.test_file = test_file;
replay.exp_tf_file = exp_tf_file;

plotReplay(test_name, t, dm, result, replay, a_acted, diagnosticGain(result, t));
fprintf('GPT-5.6.4 replay: %s | %d updates | target %.3f\n', ...
    test_name, numel(replay.tc), replay.cfg.auth.target)
end

function result = unwrapResult(data)
if isfield(data, 'result') && isstruct(data.result)
    result = data.result;
else
    result = data;
end
end

function [t, u, dm, dt] = replaySignals(result)
assert(isfield(result, 't') && isfield(result, 'dm'), ...
    'The selected test must contain t and dm.')
if isfield(result, 'u_osi')
    u = result.u_osi(:);
elseif isfield(result, 'dd')
    u = result.dd(:);
else
    error('analyze_osi:MissingInput', 'The selected test must contain u_osi or dd.')
end
t = result.t(:); dm = result.dm(:);
if isfield(result, 'dt')
    dt = result.dt;
else
    dt = median(diff(t));
end
end

function loop_tf = makeLoop(model_data, dt)
pid_values = fieldOr(model_data, 'pid_values', ...
    struct('P', 0.15, 'I', 20, 'D', 0.0015, 'derivative_filter_N', 512));
if ~isfield(pid_values, 'derivative_filter_N')
    pid_values.derivative_filter_N = 512;
end
controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, dt, 'IFormula', 'ForwardEuler', ...
    'DFormula', 'ForwardEuler');
plant = model_data.H_dc_dm;
if get(plant, 'Ts') == 0
    plant = c2d(plant, dt, 'zoh');
elseif abs(get(plant, 'Ts')-dt) > 10*eps(dt)
    plant = d2d(plant, dt, 'zoh');
end
loop_tf = controller*plant;
end

function a = loggedAuthority(result, n)
a = [];
for name = {'auth', 'osi_gain', 'auth_factor'}
    if isfield(result, name{1}) && numel(result.(name{1})) >= n
        a = result.(name{1})(1:n);
        return
    end
end
end

function diag = diagnosticGain(result, t)
diag = struct('t', [], 'value', []);
if isfield(result, 'Results') && size(result.Results, 2) >= 21
    n = min(numel(t), size(result.Results, 1));
    diag.t = t(1:n); diag.value = result.Results(1:n, 21);
elseif isfield(result, 'diag_gain')
    n = min(numel(t), numel(result.diag_gain));
    diag.t = t(1:n); diag.value = result.diag_gain(1:n);
end
end

function plotReplay(name, t, dm, result, replay, a_acted, diag)
colors = struct('black', [0 0 0], 'blue', [0 124 168]/255, ...
    'purple', [116 5 138]/255, 'copper', [172 100 32]/255, ...
    'green', [57 191 94]/255, 'red', [144 21 0]/255);
fig = figure('Name', [name ' - GPT-5.6.4 OSI'], 'Color', 'w', ...
    'Position', [80 80 1200 820]);
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

ax(1) = nexttile; hold on
h_disp = gobjects(0);
if isfield(result, 'dd')
    n = min(numel(t), numel(result.dd));
    h_disp(end+1) = plot(t(1:n), result.dd(1:n), '--', 'Color', colors.black, ...
        'LineWidth', 1.8, 'DisplayName', 'dd');
end
if isfield(result, 'dc')
    n = min(numel(t), numel(result.dc));
    h_disp(end+1) = plot(t(1:n), result.dc(1:n), 'Color', colors.copper, ...
        'LineWidth', 1, 'DisplayName', 'dc');
end
h_disp(end+1) = plot(t, dm, 'Color', colors.blue, 'LineWidth', 1, ...
    'DisplayName', 'dm');
styleAxis(gca); ylabel('Displacement (mm)'); title([name ' — GPT-5.6.4 OSI replay'], 'Interpreter', 'none')
makeLegend(gca, h_disp)

ax(2) = nexttile; hold on
h_st = plot(replay.tc, replay.b_st, 'Color', colors.blue, 'LineWidth', 1, ...
    'DisplayName', 'coherent term');
h_res = plot(replay.tc, replay.b_res, 'Color', colors.purple, 'LineWidth', 1, ...
    'DisplayName', 'quiet-band term');
h_sel = plot(replay.tc, replay.b, 'Color', colors.black, 'LineWidth', 1.6, ...
    'DisplayName', 'selected OSI');
h_target = yline(replay.cfg.auth.target, '--', 'Color', colors.black, ...
    'LineWidth', 1.2, 'DisplayName', 'target');
styleAxis(gca); ylabel('NCF margin'); title('OSI indicators')
makeLegend(gca, [h_st h_res h_sel h_target])

ax(3) = nexttile; hold on
h = gobjects(0);
h(end+1) = plot(replay.tc, replay.auth_factor, 'Color', colors.copper, ...
    'LineWidth', 1.5, 'DisplayName', 'GPT auth factor');
if ~isempty(a_acted)
    h(end+1) = plot(t(1:numel(a_acted)), a_acted, 'Color', colors.purple, ...
        'LineWidth', 1.0, 'DisplayName', 'logged auth factor');
end
ylabel('Authority factor'); ylim([0 1.05])
if ~isempty(diag.value)
    yyaxis right
    h(end+1) = plot(diag.t, diag.value, 'Color', colors.black, 'LineWidth', 1, ...
        'DisplayName', 'diagnostic gain');
    ylabel('Diagnostic gain')
    yyaxis left
end
styleAxis(gca); xlabel('Time (s)'); title('Authority and diagnostic gain')
makeLegend(gca, h)
linkaxes(ax, 'x')
end

function styleAxis(ax)
grid(ax, 'on'); box(ax, 'on'); ax.GridColor = [0.84 0.84 0.84];
ax.GridAlpha = 0.8; ax.Color = 'w'; ax.FontName = 'Arial';
end

function makeLegend(ax, handles)
if nargin < 2, handles = findobj(ax, '-property', 'DisplayName'); end
lgd = legend(ax, handles, 'Location', 'best', 'Interpreter', 'none');
lgd.ItemHitFcn = @toggleVisibility;
end

function toggleVisibility(~, event)
if strcmp(event.Peer.Visible, 'on')
    event.Peer.Visible = 'off';
else
    event.Peer.Visible = 'on';
end
end

function value = fieldOr(s, name, default)
if isfield(s, name), value = s.(name); else, value = default; end
end
