function si = saved_result_si(raw)
%SAVED_RESULT_SI Return an SI computational copy of a saved experiment.
% Units:
%   Input raw: t [s], dd/dc/dm [mm], fm [N], am [g].
%   Output si: t [s], dd/dc/dm [m], fm [N], am [m/s^2].
%   Existing m_hat [kg], c_hat [N*s/m], and k_hat [N/m] pass through.

if isfield(raw, 'result') && isstruct(raw.result)
    raw = raw.result;
end

si = raw;
si.dd = raw.dd/1000;
si.dc = raw.dc/1000;
si.dm = raw.dm/1000;
si.am = raw.am*9.80665;
end
