function info = predict_inner_margin(H_dc_dm, pid_values, dt, target_gm_db, freq_range_hz)
%PREDICT_INNER_MARGIN Inner PID+H_dc_dm loop margins and the authority a needed.
% The inner tracking loop is  T = feedback(a*C_pid*H_dc_dm, 1)  with open loop
%       L(a) = a * C_pid * H_dc_dm.
% Scaling the PID by the authority a scales L UNIFORMLY at every frequency, so the
% phase (hence the -180 deg crossover frequency, ~37 Hz) is unchanged and the gain
% margin is CLOSED FORM:
%       GM_dB(a) = GM_dB(1) - 20*log10(a)            (verified exact on the models)
% Therefore the authority needed to reach a target inner gain margin is also
% closed form and needs no search:
%       a_required = 10^((GM_dB(1) - target_gm_db)/20)
% The inner NCF margin co-moves monotonically with the inner GM (the inner loop has
% a single binding resonance at the actuator -180 deg frequency), so regulating the
% inner GM to a setpoint also regulates the inner NCF.
%
% Focus metrics: gain margin (dB) and NCF margin. No peak-|T| metric.
%
% info fields:
%   gm_db, ncf, pm_deg : inner-loop margins at a = 1 (custom_stability_margins)
%   f180_hz            : the -180 deg crossover frequency (the ~37 Hz weak point)
%   gm_db_at           : function handle, gm_db_at(a) = gm_db - 20*log10(a)
%   ncf_for_gm         : function handle, inner NCF estimated from a target inner GM
%   (if target_gm_db given) target_gm_db, a_required

if nargin < 4, target_gm_db = []; end
if nargin < 5 || isempty(freq_range_hz), freq_range_hz = [0.5 120]; end

Hd = H_dc_dm;
if get(Hd, 'Ts') == 0
    Hd = c2d(Hd, dt, 'zoh');
elseif abs(get(Hd, 'Ts')-dt) > 10*eps(dt)
    Hd = d2d(Hd, dt, 'zoh');
end
C1 = pid(pid_values(1), pid_values(2), pid_values(3), 1/pid_values(4), dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L1 = C1*Hd;
[gm_db, pm_deg, ncf] = custom_stability_margins(L1, freq_range_hz);

% -180 deg crossover frequency (informational: this is the ~37 Hz CSI weak point)
am = allmargin(L1);
if isempty(am.GMFrequency)
    f180_hz = NaN;
else
    f180_hz = min(am.GMFrequency)/(2*pi);
end

info = struct( ...
    'gm_db', gm_db, ...
    'ncf', ncf, ...
    'pm_deg', pm_deg, ...
    'f180_hz', f180_hz, ...
    'gm_db_at', @(a) gm_db - 20*log10(a), ...
    'ncf_for_gm', @(gm) gm_to_ncf_bound(gm));

if ~isempty(target_gm_db)
    info.target_gm_db = target_gm_db;
    info.a_required = 10^((gm_db - target_gm_db)/20);
end
end

function b = gm_to_ncf_bound(gm_db)
% Guaranteed lower bound the loop NCF implies for a gain margin, and vice versa:
%   GM >= (1+b)/(1-b)  <=>  b <= (g-1)/(g+1),  g = 10^(GM_dB/20).
% Returned as the NCF consistent with that gain margin (an upper bound on b). The
% inner loop's measured GM->NCF map is close to this single-resonance relation.
g = 10.^(gm_db/20);
b = (g - 1)./(g + 1);
end
