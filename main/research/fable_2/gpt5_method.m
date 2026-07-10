function m = gpt5_method(osi_override, auth_override)
%GPT5_METHOD Method struct plugging research/gpt5_6 (gpt_osi + gpt_auth)
% into the canonical fable_synthetic_suite, for a like-for-like comparison
% with fabby. Nothing in research/gpt5_6 is modified.
if nargin < 1, osi_override = struct(); end
if nargin < 2, auth_override = struct(); end
m = struct('name', 'gpt5', 'block_n', 256, ...
    'init', @(dt, L0, target, cm) initGpt(dt, L0, target, ...
        osi_override, auth_override), ...
    'step', @stepGpt);
end

function ctx = initGpt(dt, L0, target, osi_override, auth_override)
here = fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(here), 'gpt5_6'))
cfg = gpt_osi('config', dt, L0, osi_override);
auth_override.target = target;
auth_override.dt_update = cfg.step_s;
prm = gpt_auth('params', auth_override);
ctx = struct('cfg', cfg, 'ost', gpt_osi('state', cfg), ...
    'prm', prm, 'ast', gpt_auth('state', prm), 'a_last', prm.a_init);
end

function [ctx, b, a, trip, extra] = stepGpt(ctx, dd_blk, dm_blk)
ctx.ost.a_cmd = ctx.a_last;    % authority applied during this block
[b, ctx.ost, oi] = gpt_osi(dd_blk, dm_blk, ctx.cfg, ctx.ost);
[a, ctx.ast] = gpt_auth(b, oi.full_margin, oi.residual_weight, ...
    ctx.ast, ctx.prm);
ctx.a_last = a;
trip = 0;
extra = struct('b_st', oi.b_st, 'b_res', oi.b_res, 'b_fast', NaN, ...
    'decision', 0);
end
