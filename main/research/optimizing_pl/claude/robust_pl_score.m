function s = robust_pl_score(lead_tf, members, num_tf, pid_values, dt, cfg)
%ROBUST_PL_SCORE Worst-case (min-max) phase_lead criterion over a damage set.
% This is the criterion recommended for optimize_vHS_phase_lead_min_ncf.m:
% instead of scoring ONE specimen / ONE H_dc_dm, score the WORST damage case in
% a bracket (see damage_bracket.m). Returns per-member margins, the worst-case
% summary, a feasibility flag, and a scalar score (lower is better) suitable for
% fmincon / grid search.
%
% Feasibility (hard gates, evaluated on EVERY member):
%   max_i max_abs_pole_i <= 1 - pole_margin     (analytic stability)
%   min_i ncf_i          >= ncf_target          (>=0.30..0.35 recommended)
% Objective among feasible designs: maximize the worst-case NCF (equivalently
% minimize -min_i ncf_i), with a light mean term to break ties toward designs
% that are good everywhere, not just at the binding case.
%
% cfg fields (all optional): ncf_target (0.35), gm_target_db (7),
%   pole_margin (0.005), w_ncf (1e3), w_pole (1e6), w_mean (0.1).

if nargin < 6, cfg = struct(); end
d = struct('ncf_target', 0.35, 'gm_target_db', 7, 'pole_margin', 0.005, ...
    'w_ncf', 1e3, 'w_pole', 1e6, 'w_mean', 0.1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(cfg, f{i}) || isempty(cfg.(f{i})), cfg.(f{i}) = d.(f{i}); end
end

n = numel(members);
ncf = zeros(n, 1); gm = zeros(n, 1); pole_r = zeros(n, 1);
for i = 1:n
    m = hybrid_loop_margins(num_tf, members(i).Hdc, members(i).k_exp, ...
        lead_tf, pid_values, dt);
    ncf(i) = m.ncf; gm(i) = m.gm_db; pole_r(i) = m.max_abs_pole;
end

worst_ncf = min(ncf);
worst_gm = min(gm);
max_pole = max(pole_r);
mean_ncf = mean(ncf);
feasible = max_pole <= 1 - cfg.pole_margin && worst_ncf >= cfg.ncf_target;

% scalar score: lower is better. Penalize the binding (worst) case, push the
% worst-case NCF up, and add a hard barrier for any analytic instability.
score = cfg.w_ncf*max(0, cfg.ncf_target - worst_ncf)^2 ...
    + cfg.w_pole*max(0, max_pole - (1 - cfg.pole_margin)) ...
    - cfg.w_mean*worst_ncf - 0.01*mean_ncf;

s = struct('score', score, 'feasible', feasible, ...
    'worst_ncf', worst_ncf, 'worst_gm_db', worst_gm, 'max_abs_pole', max_pole, ...
    'mean_ncf', mean_ncf, 'ncf', ncf, 'gm_db', gm, 'pole_r', pole_r);
end
