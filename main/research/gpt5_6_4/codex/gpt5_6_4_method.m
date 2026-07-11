function m = gpt5_6_4_method(osi_override, auth_override)
%GPT5_6_4_METHOD Adapter for the canonical FABLE synthetic suite.
if nargin < 1, osi_override = struct(); end
if nargin < 2, auth_override = struct(); end
m = struct('name', 'gpt5_6_4_codex', 'block_n', 256, ...
    'init', @(dt, L0, target, cm) initMethod(dt, L0, target, ...
        osi_override, auth_override), ...
    'step', @stepMethod);
end

function ctx = initMethod(dt, L0, target, osi_override, auth_override)
cfg = gpt5_6_4_osi('config', dt, L0, osi_override);
auth_override.target = target;
auth_override.dt_update = cfg.step_s;
prm = gpt5_6_4_auth('params', auth_override);
ctx = struct('cfg', cfg, 'ost', gpt5_6_4_osi('state', cfg), ...
    'prm', prm, 'ast', gpt5_6_4_auth('state', prm), ...
    'a_last', prm.a_init);
end

function [ctx, b, a, trip, extra] = stepMethod(ctx, dd, dm)
ctx.ost.a_cmd = ctx.a_last;
[b, ctx.ost, oi] = gpt5_6_4_osi(dd, dm, ctx.cfg, ctx.ost);
a0 = ctx.a_last;
[a, ctx.ast] = gpt5_6_4_auth(b, oi.full_margin, ...
    oi.residual_weight, ctx.ast, ctx.prm);
ctx.a_last = a;
trip = 0;
extra = struct('b_st', oi.b_st, 'b_res', oi.b_res, 'b_fast', NaN, ...
    'decision', sign(a-a0), 'ready', oi.ready, ...
    'a_target', a, 'confidence', oi.confidence);
end
