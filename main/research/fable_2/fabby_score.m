function out = fabby_score(suite, projectFolder)
%FABBY_SCORE Margin-tracking score for a fable_synthetic_suite run.
%
%   out = fabby_score(suite)                % suite struct from the harness
%   out = fabby_score(suite, projectFolder) % explicit project root
%
% THE QUESTION IT SCORES: how well does the true margin that RESULTS from
% the commanded authority track the best-achievable margin?
%
% At every update the ground truth (plant blend lambda(t), known to the
% suite) defines the IDEAL authority
%     a*(t) = 1                        if b_true(1, lam) >= target
%           = the a where b_true(a, lam) = target   otherwise
% i.e. never detune a loop that is healthy at full authority, and regulate
% a damaged one exactly onto the target. The ideal margin is
%     b*(t) = b_true(a*(t), lam(t)) = max(target, b_true(1, lam)).
%
% The per-sample tracking error e(t) = b_true(t) - b*(t) is signed:
%   e > 0  -> over-conservative: authority lower than needed, performance
%             (J4) thrown away while the plant could take more;
%   e < 0  -> under-protective: the loop is carrying less margin than the
%             target demands - weighted w_unsafe (3x) heavier.
%
% Score per case (first warm_skip_s seconds excluded):
%     fabby_score = 100 * max(0, 1 - mean(w.*|e|) / err_scale)
% with err_scale = 0.10: a score of 100 means perfect tracking; 0 means an
% average weighted error of a tenth of margin - e.g. spending the whole
% run 0.10 above target (deeply over-shed) or 0.033 below it.
%
% Returns a struct array with per-case scores plus the aggregate mean, and
% prints a table. Fields: name, score, mean_over (J4 loss side),
% mean_under (safety side), pct_over_10 (% of time more than 0.10 margin
% above ideal - the "authority never came back" signature).

if nargin < 2
    here = fileparts(mfilename('fullpath'));
    projectFolder = fileparts(fileparts(here));
end

w_unsafe   = 3.0;    % weight of unsafe (below-ideal) margin error
err_scale  = 0.10;   % weighted mean error that maps to score 0
warm_skip_s = 4.0;   % settling grace at record start

% ---- true-margin surface b(a, lam) from the identified models -------------
dt = 1/2048;
E7 = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat'));
E5 = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
fgrid = (1:100)';
L7 = squeeze(freqresp(C*ss(c2d(E7.H_dc_dm, dt, 'zoh')), 2*pi*fgrid));
L5 = squeeze(freqresp(C*ss(c2d(E5.H_dc_dm, dt, 'zoh')), 2*pi*fgrid));

% full-authority margin vs plant blend (the only surface row the ideal
% needs: b*(lam) = max(target, b_full(lam)))
lam_grid = linspace(0, 1, 41);
Bfull = zeros(1, numel(lam_grid));
for j = 1:numel(lam_grid)
    Lb = (1 - lam_grid(j))*L7 + lam_grid(j)*L5;
    Bfull(j) = min(abs(1 + Lb)./sqrt(2*(1 + abs(Lb).^2)));
end

% scenario plant-blend definitions (mirrors fable_synthetic_suite)
lamdef = struct( ...
    'healthy_broadband',       {{[], []}}, ...
    'intensity_step',          {{[], []}}, ...
    'damage_step_broadband',   {{[45 45], [0 1]}}, ...
    'damage_step_lowband',     {{[50 50], [0 1]}}, ...
    'silent',                  {{[], []}}, ...
    'gradual_softening',       {{[60 100], [0 1]}}, ...
    'damage_then_repair',      {{[50 50 100 100], [0 1 1 0]}}, ...
    'starts_damaged_improves', {{[0 80 80], [1 1 0]}}, ...
    'regime_change_healthy',   {{[], []}}, ...
    'transient_pulse',         {{[], []}});

tg = suite.target;
out = struct('cases', struct('name', {}, 'score', {}, 'mean_over', {}, ...
    'mean_under', {}, 'pct_over_10', {}, 'b_star', {}), ...
    'mean_score', NaN, ...
    'target', tg, 'w_unsafe', w_unsafe, 'err_scale', err_scale);

for ci = 1:numel(suite.cases)
    c = suite.cases(ci);
    def = lamdef.(c.name);
    tc = c.sim.tc;
    a = min(max(c.sim.a, 0), 1);
    lam = arrayfun(@(t) lamAt(def{1}, def{2}, t), tc);

    % ideal margin: never detune a healthy loop, regulate a damaged one
    b_full = interp1(lam_grid, Bfull, lam);              % margin at a = 1
    b_star = max(tg, b_full);
    b_true = c.sim.b_true;

    e = b_true - b_star;
    w = ones(size(e));
    w(e < 0) = w_unsafe;
    m = tc > tc(1) + warm_skip_s & isfinite(e);

    werr = mean(w(m).*abs(e(m)));
    sc = 100*max(0, 1 - werr/err_scale);
    oc = struct('name', c.name, 'score', sc, ...
        'mean_over', mean(max(e(m), 0)), ...
        'mean_under', mean(max(-e(m), 0)), ...
        'pct_over_10', 100*mean(e(m) > 0.10), ...
        'b_star', b_star(:));
    out.cases(end+1) = oc;
end
out.mean_score = mean([out.cases.score]);

fprintf('\n---- fabby score (target %.2f, unsafe x%.0f, scale %.2f) ----\n', ...
    tg, w_unsafe, err_scale);
fprintf('%-26s %6s %8s %8s %10s\n', 'case', 'score', 'over', 'under', ...
    '%t over+.1');
for i = 1:numel(out.cases)
    oc = out.cases(i);
    fprintf('%-26s %6.1f %8.4f %8.4f %9.1f%%\n', oc.name, oc.score, ...
        oc.mean_over, oc.mean_under, oc.pct_over_10);
end
fprintf('%-26s %6.1f\n', 'MEAN', out.mean_score);
end

function lam = lamAt(xt, xv, t)
if isempty(xt)
    lam = 0;
    return
end
if t <= xt(1), lam = xv(1); return, end
if t >= xt(end), lam = xv(end); return, end
lam = xv(1);
for i = numel(xt)-1:-1:1
    if t >= xt(i)
        if xt(i+1) > xt(i)
            lam = xv(i) + (xv(i+1) - xv(i))*(t - xt(i))/(xt(i+1) - xt(i));
        else
            lam = xv(i+1);
        end
        return
    end
end
end
