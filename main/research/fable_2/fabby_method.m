function m = fabby_method(osi_override, auth_override)
%FABBY_METHOD Method struct plugging fabby into fable_synthetic_suite.
%   suite = fable_synthetic_suite('method', fabby_method());
if nargin < 1, osi_override = struct(); end
if nargin < 2, auth_override = struct(); end
m = struct('name', 'fabby', 'block_n', 256, ...
    'init', @(dt, L0, target, cm) initFabby(dt, L0, target, ...
        osi_override, auth_override), ...
    'step', @stepFabby);
end

function ctx = initFabby(dt, L0, target, osi_override, auth_override)
here = fileparts(mfilename('fullpath'));
addpath(here)
cfg = fabby_osi('config', dt, L0, osi_override);
auth_override.target = target;
auth_override.dt_update = cfg.step_s;
prm = fabby_auth('params', auth_override);
ctx = struct('cfg', cfg, 'state', fabby_osi('state', cfg), ...
    'prm', prm, 'ast', fabby_auth('state', prm));
end

function [ctx, b, a, trip, extra] = stepFabby(ctx, dd_blk, dm_blk)
[b, ctx.state, oi] = fabby_osi(dd_blk, dm_blk, ctx.cfg, ctx.state);
[a, ctx.ast] = fabby_auth(b, oi.pred, oi.agrid, oi.blind, ctx.ast, ctx.prm);
trip = 0;
extra = struct('b_st', oi.b_st, 'b_res', oi.b_q, 'b_fast', NaN, ...
    'decision', 0);
end
