function D = prep_specimen_data(file_name)
% Units:
%   Input file stores t [s], dm/dc/dd [mm], fm [N], am [g].
%   Output D uses t [s], x/xc [m], v/vc [m/s], a/ac [m/s^2], F [N].
S = load(file_name);
S = saved_result_si(S);

D.file = file_name;
D.t = S.t(:);
D.dt = S.dt;
D.fs = S.fs;
D.x = S.dm(:);
D.F = S.fm(:);
D.v = gradient(D.x, D.dt);
D.a = gradient(D.v, D.dt);

if isfield(S, 'dc')
    D.xc = S.dc(:);
elseif isfield(S, 'dd')
    D.xc = S.dd(:);
else
    D.xc = D.x;
end

D.vc = gradient(D.xc, D.dt);
D.ac = gradient(D.vc, D.dt);
end
