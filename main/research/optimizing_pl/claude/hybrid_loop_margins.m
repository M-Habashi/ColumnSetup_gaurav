function m = hybrid_loop_margins(num_tf, H_dc_dm, k_exp, lead_tf, pid_values, dt, extra)
%HYBRID_LOOP_MARGINS Coupled RTHS loop margins for one (plant, lead) pair.
% Builds the same loop the optimizer constrains as num_phase_lead_exp:
%   L = -num_tf * (k_exp/1000) * extra * lead * feedback(C_pid*H_dc_dm, 1)
% and returns NCF margin, gain margin [dB], and the dominant closed-loop pole
% radius. NCF is the primary robustness gate: b >= 0.30 simultaneously
% guarantees GM >= (1+b)/(1-b) = 5.4 dB and PM >= 2*asin(b) = 35 deg, whereas
% the gain margin alone is blind to phase (and can report Inf on an already
% unstable loop). max_abs_pole < 1 is the hard stability gate.
%
% extra (optional) is an extra series block on the command path, used for the
% online "stability authority" demos (a scalar < 1, or a low-pass tf).

if nargin < 7 || isempty(extra)
    extra = tf(1);
end
H_dc_dm = to_dt(H_dc_dm, dt, 'zoh');
C_pid = pid(pid_values(1), pid_values(2), pid_values(3), 1/pid_values(4), ...
    dt, 'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
pid_h = feedback(C_pid*H_dc_dm, 1);
lead_d = to_dt(lead_tf, dt, 'tustin');
extra_d = to_dt(extra, dt, 'tustin');

L = -minreal(num_tf*(k_exp/1000)*extra_d*lead_d*pid_h, [], false);
[gm_db, pm_deg, ncf] = custom_stability_margins(L, [0.1 80]);

m = struct('ncf', ncf, 'gm_db', gm_db, 'pm_deg', pm_deg, ...
    'max_abs_pole', max(abs(pole(feedback(L, 1)))));
end

function G = to_dt(G, dt, method)
if isnumeric(G)
    G = tf(G);
end
if get(G, 'Ts') == 0
    G = c2d(G, dt, method);
elseif abs(get(G, 'Ts')-dt) > 10*eps(dt)
    G = d2d(G, dt, method);
end
end
