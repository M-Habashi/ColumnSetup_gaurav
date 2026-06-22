function [D, noiseD] = prep_specimen_data(file_name, noise_duration, filter_hz)
% Units:
%   Input file stores t [s], dm/dc/dd [mm], fm [N], am [g].
%   Output D uses t [s], x/xc [m], v/vc [m/s], a/ac [m/s^2], F [N].
%   Velocity and acceleration are derived from displacement; am is not used.
S = load(file_name);
S = saved_result_si(S);
if nargin < 3
    filter_hz = 30;
end

D.file = file_name;
D.t = S.t(:);
D.dt = S.dt;
D.fs = S.fs;
[D.x, D.v, D.a, D.F] = filtered_regression_signals(S.dm, S.fm, D.dt, filter_hz);

if isfield(S, 'dc')
    D.xc = S.dc(:);
elseif isfield(S, 'dd')
    D.xc = S.dd(:);
else
    D.xc = D.x;
end

[D.xc, D.vc, D.ac] = filtered_regression_signals(D.xc, zeros(size(D.xc)), D.dt, filter_hz);

noiseD = [];
if nargin > 1
    noise_idx = D.t <= D.t(1) + noise_duration;
    noiseD = D;
    fields = {'t', 'x', 'F', 'v', 'a', 'xc', 'vc', 'ac'};
    for i = 1:numel(fields)
        noiseD.(fields{i}) = D.(fields{i})(noise_idx);
        D.(fields{i}) = D.(fields{i})(~noise_idx);
    end
end
end
