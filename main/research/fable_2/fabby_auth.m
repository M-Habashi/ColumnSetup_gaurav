function [a_next, ast] = fabby_auth(b, ast, prm)
%FABBY_AUTH Minimal margin-tracking authority law for fabby_osi.
%
%   prm = fabby_auth('params', override)
%   ast = fabby_auth('state', prm)
%   [a, ast] = fabby_auth(b, ast, prm)       % one step, cadence prm.dt_update
%
% One state (the authority itself), one rule: a multiplicative integrator
% that regulates the reported margin b onto prm.target,
%
%   dln(a)/dt = ( -k_dn*max(target - db_dn - b, 0)      deficit: shed
%                 +k_up*max(b - target - db_up, 0)      surplus: creep up
%                 +k_hi*max(b - b_hi, 0) ) / target     ceiling: sprint up
%
% clipped to [a_min, a_max]. Properties:
%   * shed speed is proportional to the deficit: a grazing dip barely
%     moves a, a collapse sheds at several ln-units/s - there is no
%     separate "severe" branch because the proportional law IS one;
%   * recovery is two-sloped: in the AMBIGUOUS zone just above the target
%     (where a degraded loop at reduced authority reads exactly like a
%     healthy one) authority creeps, so the estimator's lag can never be
%     outrun into bad territory; at the ceiling b > b_hi (only an
%     unambiguously healthy or idle loop reads there) it sprints, giving
%     full recovery within ~2 s;
%   * the deadband [target-db_dn, target+db_up] is where a rests: any b
%     inside it moves nothing, which is the entire anti-flicker story.
%
% Because fabby_osi always reports a finite margin, there is no NaN hold
% state: silence reads as the healthy ceiling, so authority quietly
% recovers to a_max on its own (what GDBqFpKb's stuck 0.2 needed).

if ischar(b)
    switch lower(b)
        case 'params'
            if nargin >= 2, ovr = ast; else, ovr = struct(); end
            a_next = makeParams(ovr);
        case 'state'
            a_next = struct('a', ast.a_init);
        otherwise
            error('fabby_auth:UnknownCommand', ...
                'Use ''params'', ''state'', or the numeric step call.')
    end
    ast = [];
    return
end

d = max(prm.target - prm.db_dn - b, 0);
u = max(b - prm.target - prm.db_up, 0);
h = max(b - prm.b_hi, 0);
rate = (-prm.k_dn*d + prm.k_up*u + prm.k_hi*h)/prm.target;
ast.a = min(max(ast.a*exp(rate*prm.dt_update), prm.a_min), prm.a_max);
a_next = ast.a;
end

function prm = makeParams(override)
prm = struct( ...
    'target', 0.55, ...    % margin level to regulate onto
    'db_dn', 0.00, ...     % deficit deadband below target (the
    ...                    % proportional law already ignores grazes)
    'db_up', 0.025, ...    % recovery deadband above target
    'k_dn', 7.0, ...       % shed gain (ln-authority per unit relative deficit)
    'k_up', 0.32, ...      % linear recovery gain (ambiguous zone: creep)
    'k_hi', 60.0, ...      % ceiling-recovery gain above b_hi (sprint)
    'b_hi', 0.695, ...     % unambiguously-healthy margin level
    'a_min', 0.08, ...
    'a_max', 1.0, ...
    'a_init', 1.0, ...
    'dt_update', 0.125);
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('fabby_auth:UnknownParam', 'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
end
