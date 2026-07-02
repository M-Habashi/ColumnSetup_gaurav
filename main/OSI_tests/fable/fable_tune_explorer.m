function out = fable_tune_explorer(record, varargin)
%FABLE_TUNE_EXPLORER Interactive tuning replay of the fable Speedgoat runtime.
%
%   fable_tune_explorer                    % pick the data file from a dialog
%   fable_tune_explorer(2)                 % record index in tests/important
%   fable_tune_explorer('C:\...\rec.mat')  % explicit file (needs dd/dm/dt)
%
%   out = fable_tune_explorer(2, ...
%       'target', 0.55, ...                % OSI level the law regulates onto
%       'osi',  struct('fast_st_h', 6), ...% fable_osi overrides  (see the
%       ...                                % PER-BRANCH TUNING GUIDE there)
%       'auth', struct('up_rate', 0.04, ...% fable_auth overrides (see the
%           'min_step', 0.05), ...         % TUNING GUIDE there)
%       'pred_enable', true, ...
%       'a_init', 1.0, 'a_min', 0.08);
%
% What it does: replays the record's dd/dm sample-by-sample through
% control_and_HS/OSI/fable_osi_runtime.m - the EXACT MATLAB Function body
% the Speedgoat executes (bitwise-equivalent to fable_osi/fable_auth, see
% test_fable_runtime_equivalence) - so any tuning you settle on here
% transfers 1:1 to the target. It then draws an interactive figure with
% linked zoom/pan:
%   subplot 1: dm
%   subplot 2: every OSI branch (slow ST, residual, fast) + the selected
%              margin + the target line
%   subplot 3: the authority factor, with fast-trip markers
% and prints replay metrics (false-low, time at full authority, trips).
%
% Typical tuning session:
%   fable_tune_explorer(3);                                  % baseline
%   fable_tune_explorer(3, 'auth', struct('min_step', 0.05));% steppier a
%   fable_tune_explorer(3, 'auth', struct('b_filt_tau_s', 1.0, ...
%       'down_settle_s', 2.5));                              % smoother
%   fable_tune_explorer(3, 'auth', struct('down_rate', 4, ...
%       'down_confirm_n', 1));                               % catch faster
%
% REPLAY CAVEAT: the authority shown did NOT act on the recorded plant, so
% it is what the law would have commanded given the observed margins.
% Closed-loop behavior is validated by fable_synthetic_suite /
% run_fable_synthetic_checks. (Consequently the runtime's authority-motion
% gate sees a "real" replayed authority that the data never felt - same
% conservative direction as on the rig.)
%
% Returns a struct with all traces (tc, b, b_st, b_res, b_fast, trip, a,
% decision, valid), the record data, and the prepared setup.

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

opt = struct('target', 0.55, 'a_min', 0.08, 'a_init', 1.0, ...
    'pred_enable', true, 'osi', struct(), 'auth', struct(), ...
    'save_png', true);
for i = 1:2:numel(varargin)
    opt.(lower(varargin{i})) = varargin{i+1};
end

% ---- pick / load the record ----------------------------------------------
recDir = fullfile(projectFolder, 'saved_results', 'tests', 'important');
if nargin < 1 || isempty(record)
    listing = dir(fullfile(recDir, '*.mat'));
    assert(~isempty(listing), 'no records found under %s', recDir)
    names = [{listing.name}, {'(browse...)'}];
    [sel, okd] = listdlg('ListString', names, 'SelectionMode', 'single', ...
        'ListSize', [520 300], 'Name', 'fable_tune_explorer', ...
        'PromptString', 'Data file to replay through the fable runtime:');
    assert(okd == 1, 'no file selected')
    if sel == numel(names)
        [f, p] = uigetfile('*.mat', 'Pick a record', recDir);
        assert(~isequal(f, 0), 'no file selected')
        recFile = fullfile(p, f);
    else
        recFile = fullfile(recDir, listing(sel).name);
    end
elseif isnumeric(record)
    listing = dir(fullfile(recDir, '*.mat'));
    assert(record >= 1 && record <= numel(listing), ...
        'record index out of range (1..%d)', numel(listing))
    recFile = fullfile(recDir, listing(record).name);
else
    recFile = record;
end
assert(isfile(recFile), 'file not found: %s', recFile)
[~, recName] = fileparts(recFile);
loaded = load(recFile);
if isfield(loaded, 'result') && isstruct(loaded.result)
    data = loaded.result;
else
    data = loaded;
end
for f = {'dd', 'dm', 'dt'}
    assert(isfield(data, f{1}), 'record must contain %s', f{1})
end
dd = data.dd(:);
dm = data.dm(:);
dt = data.dt;
if isfield(data, 't'), t = data.t(:); else, t = (1:numel(dd))'*dt; end

% ---- prepare the runtime parameter arrays ---------------------------------
hs = struct('exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'target_outer_ncf', opt.target, 'osi_gain_min', opt.a_min, ...
    'osi_gain_initial', opt.a_init, ...
    'fable_osi_override', opt.osi, 'fable_auth_override', opt.auth, ...
    'fable_pred_enable', opt.pred_enable);
setup = prepare_fable_runtime(projectFolder, dt, hs);
fbls = setup.fbls; fblw = setup.fblw; fblbins = setup.fblbins;
fblfw = setup.fblfw; fblfbins = setup.fblfbins; fblag = setup.fblag;
fbla = setup.fbla;
step_n = setup.cfg.step_n;

% ---- replay through the runtime (the exact Speedgoat code path) ----------
N = floor(min(numel(dd), numel(dm))/step_n)*step_n;
nU = N/step_n;
tc = NaN(nU, 1); b = NaN(nU, 1); bst = NaN(nU, 1); bres = NaN(nU, 1);
bfa = NaN(nU, 1); trip = zeros(nU, 1); a = NaN(nU, 1);
dec = zeros(nU, 1); vld = false(nU, 1);

clear fable_osi_runtime            % fresh persistents
fprintf('replaying %s (%.0f s) through fable_osi_runtime ...\n', ...
    recName, N*dt);
tstart = tic;
k = 0;
next_mark = 0.2;
for i = 1:N
    [ai, bi, bsti, bresi, bfi, tri, vi, di] = fable_osi_runtime( ...
        dd(i), dm(i), 1, fbls, fblw, fblbins, fblfw, fblfbins, ...
        fblag, fbla);
    if mod(i, step_n) == 0
        k = k + 1;
        tc(k) = t(i);
        b(k) = bi; bst(k) = bsti; bres(k) = bresi; bfa(k) = bfi;
        trip(k) = tri; a(k) = ai; dec(k) = di; vld(k) = vi ~= 0;
    end
    if i >= next_mark*N
        fprintf('  %.0f%% (%.1f s elapsed)\n', 100*next_mark, toc(tstart));
        next_mark = next_mark + 0.2;
    end
end
clear fable_osi_runtime
fprintf('done in %.1f s\n', toc(tstart));

% ---- metrics ---------------------------------------------------------------
tg = opt.target;
vb = b(vld);
fprintf('\n--- replay metrics (%s, target %.2f) ---\n', recName, tg);
fprintf('valid margin time        : %5.1f%%\n', 100*mean(vld));
fprintf('margin below target      : %5.1f%% of valid time\n', ...
    100*mean(vb < tg));
fprintf('time at full authority   : %5.1f%%  (a >= 0.95*a_init)\n', ...
    100*mean(a >= 0.95*opt.a_init, 'omitnan'));
fprintf('min authority            : %5.3f\n', min(a));
fprintf('fast trips               : %d\n', nnz(trip > 0));
fprintf('authority commit moves   : %d\n', nnz(abs(diff(a)) > 1e-12));

% ---- interactive figure ----------------------------------------------------
ink = [11 11 11]/255; muted = [137 135 129]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; aqua = [27 175 122]/255; violet = [74 58 167]/255;
yellow = [237 161 0]/255; gray = [165 163 156]/255;

fig = figure('Color', 'w', 'Position', [60 60 1180 780], ...
    'Name', ['fable tune explorer - ' recName], 'NumberTitle', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot(ax1, t(1:4:N), dm(1:4:N), '-', 'Color', blue, 'LineWidth', 0.4)
styleAxis(ax1, grid_c, muted, ink)
ylabel(ax1, 'dm (mm)')
title(ax1, sprintf('%s  -  fable runtime replay (target %.2f)', ...
    recName, tg), 'Color', ink, 'Interpreter', 'none')

ax2 = nexttile;
hold(ax2, 'on')
yline(ax2, tg, ':', 'target', 'Color', muted, 'LineWidth', 1, ...
    'HandleVisibility', 'off')
hFa = plot(ax2, tc, bfa, '-', 'Color', [gray 0.6], 'LineWidth', 0.5);
hSt = plot(ax2, tc, bst, '-', 'Color', [blue 0.85], 'LineWidth', 0.9);
cap = 1/sqrt(2);
resv = bres < cap - 1e-9;
hRe = plot(ax2, tc(resv), bres(resv), '.', 'Color', violet, ...
    'MarkerSize', 8);
hB = plot(ax2, tc, b, '-', 'Color', ink, 'LineWidth', 1.5);
styleAxis(ax2, grid_c, muted, ink)
ylabel(ax2, 'NCF margin')
ylim(ax2, [0 0.75])
hs_ = [hB hSt hFa];
lbl = {'selected OSI', 'slow ST branch', 'fast margin'};
if any(resv)
    hs_(end+1) = hRe;
    lbl{end+1} = 'residual branch (engaged)';
end
legend(ax2, hs_, lbl, 'Location', 'southwest', 'Box', 'off', 'FontSize', 8)

ax3 = nexttile;
hold(ax3, 'on')
stairs(ax3, tc, a, '-', 'Color', aqua, 'LineWidth', 1.5)
trm = trip > 0;
if any(trm)
    plot(ax3, tc(trm), a(trm), 'v', 'Color', yellow, ...
        'MarkerFaceColor', yellow, 'MarkerSize', 5)
end
styleAxis(ax3, grid_c, muted, ink)
ylabel(ax3, 'authority a')
ylim(ax3, [0 1.05])
xlabel(ax3, 'time (s)')

% tuning summary box (which knobs differ from defaults)
txt = {sprintf('target %.2f | a\\_init %.2f | a\\_min %.2f | pred %d', ...
    tg, opt.a_init, opt.a_min, double(opt.pred_enable))};
txt = [txt overrideLines('osi', opt.osi) overrideLines('auth', opt.auth)];
annotation(fig, 'textbox', [0.795 0.60 0.19 0.10], 'String', txt, ...
    'FontSize', 8, 'Color', muted, 'EdgeColor', grid_c, ...
    'BackgroundColor', 'w', 'FitBoxToText', 'on', 'Interpreter', 'tex');

linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [t(1) t(N)])
zoom(fig, 'on')

if opt.save_png
    figDir = fullfile(here, 'figures');
    if ~exist(figDir, 'dir'), mkdir(figDir), end
    png = fullfile(figDir, ['explorer_' recName '.png']);
    exportgraphics(fig, png, 'Resolution', 140)
    fprintf('figure saved: %s\n', png);
end

out = struct('record', recName, 'file', recFile, 'tc', tc, 'b', b, ...
    'b_st', bst, 'b_res', bres, 'b_fast', bfa, 'trip', trip, 'a', a, ...
    'decision', dec, 'valid', vld, 't', t(1:N), 'dm', dm(1:N), ...
    'setup', setup, 'opt', opt);
end

function lines = overrideLines(tag, s)
lines = {};
fn = fieldnames(s);
for i = 1:numel(fn)
    v = s.(fn{i});
    if isnumeric(v) && isscalar(v)
        lines{end+1} = sprintf('%s.%s = %g', tag, ...
            strrep(fn{i}, '_', '\_'), v); %#ok<AGROW>
    else
        lines{end+1} = sprintf('%s.%s = [...]', tag, ...
            strrep(fn{i}, '_', '\_')); %#ok<AGROW>
    end
end
end

function styleAxis(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9, 'Layer', 'top')
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
ax.Title.Color = ink;
end
