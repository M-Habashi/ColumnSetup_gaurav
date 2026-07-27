%% Run Habashi Parameters On The 10 Fable Synthetic Cases
% Runs the fable synthetic suite once with the editable "new" parameters
% and once with the current implementation parameters. Both run the
% historical SOL-OSI V1 implementation (control_and_HS/OSI/sol_osi_v1.m
% + gpt5_6_4_auth.m).

clear; close all; clc

script_root = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(script_root)));
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
addpath(fullfile(projectFolder, 'OSI_tests', 'fable'))

[new_params, current_params] = habashi_osi_parameter_sets(projectFolder);

case_ids = 1:10;
new_method = localGptMethod('habashi_new');
current_method = localGptMethod('habashi_current');

fprintf('\nRunning 10 fable synthetic cases with NEW parameters...\n')
new_suite = fable_synthetic_suite( ...
    'scenarios', case_ids, ...
    'method', new_method, ...
    'target', new_params.target_outer_ncf, ...
    'osi_override', new_params.osi_override, ...
    'auth_override', localAuthForSuite(new_params), ...
    'plot', false);

fprintf('\nRunning 10 fable synthetic cases with CURRENT parameters...\n')
current_suite = fable_synthetic_suite( ...
    'scenarios', case_ids, ...
    'method', current_method, ...
    'target', current_params.target_outer_ncf, ...
    'osi_override', current_params.osi_override, ...
    'auth_override', localAuthForSuite(current_params), ...
    'plot', false);

habashi_fable_10_cases = struct('new', new_suite, ...
    'current', current_suite, ...
    'new_params', new_params, ...
    'current_params', current_params);
assignin('base', 'habashi_fable_10_cases', habashi_fable_10_cases)

localPrintComparison(new_suite, current_suite)
comparison_figures = localPlotSuiteComparisons(new_suite, current_suite, ...
    script_root);
habashi_fable_10_cases.comparison_figures = comparison_figures;

results_dir = fullfile(script_root, 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir)
end
save(fullfile(results_dir, 'habashi_fable_10_cases.mat'), ...
    'habashi_fable_10_cases', '-v7.3')
fprintf('\nSaved: %s\n', fullfile(results_dir, ...
    'habashi_fable_10_cases.mat'))

function method = localGptMethod(name)
method = struct('name', name, 'block_n', 256, ...
    'init', @localInitGpt, 'step', @localStepGpt);
end

function ctx = localInitGpt(dt, L0, target, cm)
cfg = sol_osi_v1('config', dt, L0, cm.osi_override);
aovr = cm.auth_override;
aovr.target = target;
aovr.dt_update = cfg.step_s;
prm = gpt5_6_4_auth('params', aovr);
ctx = struct('cfg', cfg, ...
    'state', sol_osi_v1('state', cfg), ...
    'prm', prm, ...
    'ast', gpt5_6_4_auth('state', prm), ...
    'a_last', prm.a_init);
end

function [ctx, b, a, trip, extra] = localStepGpt(ctx, dd_blk, dm_blk)
ctx.state.a_cmd = ctx.a_last;
[b, ctx.state, info] = sol_osi_v1(dd_blk, dm_blk, ctx.cfg, ctx.state);
[a, ctx.ast] = gpt5_6_4_auth(b, info.full_margin, ...
    info.residual_weight, ctx.ast, ctx.prm);
ctx.a_last = a;
trip = 0;
extra = struct('b_st', info.b_st, ...
    'b_res', info.b_res, ...
    'b_fast', NaN, ...
    'decision', 0);
end

function auth_override = localAuthForSuite(params)
auth_override = params.auth_override;
auth_override.a_min = params.osi_gain_min;
auth_override.a_init = params.osi_gain_initial;
end

function localPrintComparison(new_suite, current_suite)
fprintf('\n================ HABASHI 10-CASE COMPARISON ================\n')
fprintf('%-28s %-10s %-10s\n', 'Case', 'new', 'current')
for i = 1:numel(new_suite.cases)
    fprintf('%-28s %-10s %-10s\n', new_suite.cases(i).name, ...
        localPassText(new_suite.cases(i).pass), ...
        localPassText(current_suite.cases(i).pass))
end
end

function txt = localPassText(tf)
if tf
    txt = 'PASS';
else
    txt = 'FAIL';
end
end

function files = localPlotSuiteComparisons(new_suite, current_suite, script_root)
fig_dir = fullfile(script_root, 'figures');
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir)
end
fig = figure('Color', 'w', 'Position', [60 60 1280 860], ...
    'Name', 'Habashi fable 10 cases - new vs current', ...
    'NumberTitle', 'off');
tabs = uitabgroup(fig);
for i = 1:numel(new_suite.cases)
    tab = uitab(tabs, 'Title', strrep(new_suite.cases(i).name, '_', ' '));
    localPlotCaseComparison(tab, new_suite.cases(i), current_suite.cases(i));
end
figfile = fullfile(fig_dir, 'habashi_fable_10_cases_new_vs_current.fig');
savefig(fig, figfile)
files = string(figfile);
end

function localPlotCaseComparison(parent, new_case, current_case)
blue = [0 124 168]/255;
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;
purple = [116 5 138]/255;
black = [0 0 0];
gray = [0.45 0.45 0.45];

sn = new_case.sim;
sc = current_case.sim;
tl = tiledlayout(parent, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl);
hold(ax1, 'on')
plot(ax1, sn.t, sn.dm, '-', 'Color', blue, 'LineWidth', 1, ...
    'DisplayName', 'dm new')
plot(ax1, sc.t, sc.dm, '--', 'Color', blue, 'LineWidth', 2, ...
    'DisplayName', 'dm current')
grid(ax1, 'on')
ylabel(ax1, 'dm (mm)', 'Interpreter', 'none')
title(ax1, new_case.name, 'Interpreter', 'none')
lg1 = legend(ax1, 'Location', 'best', 'Interpreter', 'none');
lg1.ItemHitFcn = @localToggleLegendItem;

ax2 = nexttile(tl);
hold(ax2, 'on')
localPlotTrueNcf(ax2, sn, sc)
localPlotPair(ax2, sn.tc, sn.b_est, sc.tc, sc.b_est, ...
    'b_osi', black, false)
localPlotPair(ax2, sn.tc, sn.b_st, sc.tc, sc.b_st, ...
    'b_st', green, false)
localPlotPair(ax2, sn.tc, sn.b_res, sc.tc, sc.b_res, ...
    'b_res', red, false)
localPlotPair(ax2, sn.tc, sn.b_fast, sc.tc, sc.b_fast, ...
    'b_fast', copper, false)
grid(ax2, 'on')
ylabel(ax2, 'OSI margin', 'Interpreter', 'none')
lg2 = legend(ax2, 'Location', 'best', 'Interpreter', 'none');
lg2.ItemHitFcn = @localToggleLegendItem;

ax3 = nexttile(tl);
hold(ax3, 'on')
localPlotPair(ax3, sn.tc, sn.a, sc.tc, sc.a, ...
    'authority factor', purple, true)
plot(ax3, sn.tc(sn.trip > 0), sn.a(sn.trip > 0), 'v', ...
    'Color', gray, 'MarkerFaceColor', gray, 'MarkerSize', 5, ...
    'DisplayName', 'fast trip new')
plot(ax3, sc.tc(sc.trip > 0), sc.a(sc.trip > 0), 'x', ...
    'Color', gray, 'LineWidth', 1.5, ...
    'DisplayName', 'fast trip current')
grid(ax3, 'on')
ylabel(ax3, 'factor', 'Interpreter', 'none')
xlabel(ax3, 'time (s)', 'Interpreter', 'none')
lg3 = legend(ax3, 'Location', 'best', 'Interpreter', 'none');
lg3.ItemHitFcn = @localToggleLegendItem;

linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [sn.t(1) sn.t(end)])
end

function localPlotTrueNcf(ax, sn, sc)
if isfield(sn, 'b_true') && ~isempty(sn.b_true)
    plot(ax, sn.tc, sn.b_true, ':', 'Color', [0.25 0.25 0.25], ...
        'LineWidth', 2, 'DisplayName', 'true NCF')
elseif isfield(sc, 'b_true') && ~isempty(sc.b_true)
    plot(ax, sc.tc, sc.b_true, ':', 'Color', [0.25 0.25 0.25], ...
        'LineWidth', 2, 'DisplayName', 'true NCF')
end
end

function localPlotPair(ax, t_new, y_new, t_current, y_current, ...
        label, color, use_stairs)
if use_stairs
    stairs(ax, t_new, y_new, '-', 'Color', color, 'LineWidth', 1, ...
        'DisplayName', [label ' new'])
    stairs(ax, t_current, y_current, '--', 'Color', color, ...
        'LineWidth', 2, 'DisplayName', [label ' current'])
else
    plot(ax, t_new, y_new, '-', 'Color', color, 'LineWidth', 1, ...
        'DisplayName', [label ' new'])
    plot(ax, t_current, y_current, '--', 'Color', color, ...
        'LineWidth', 2, 'DisplayName', [label ' current'])
end
end

function localToggleLegendItem(~, evt)
if strcmp(evt.Peer.Visible, 'on')
    evt.Peer.Visible = 'off';
else
    evt.Peer.Visible = 'on';
end
end
