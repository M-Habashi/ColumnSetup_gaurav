function [t, major, half] = blk_ground_acceleration(p)
%BLK_GROUND_ACCELERATION From File, selector, and scaling blocks.

lastTick = floor(p.tend / p.dt_rths);
t = (0:lastTick).' * p.dt_rths;
halfTime = t(1:end-1) + p.dt_rths / 2;

if p.E_sw <= 3
    recordTime = p.ground_record(1, :);
    recordValue = p.ground_record(2, :);
    major = interp1(recordTime, recordValue, t, 'linear', 'extrap');
    half = interp1(recordTime, recordValue, halfTime, 'linear', 'extrap');
else
    major = blk_chirp_signal(t, p.f_ini, p.f_end, p.tend);
    half = blk_chirp_signal(halfTime, p.f_ini, p.f_end, p.tend);
end
major = p.eq_intensity * major(:);
half = p.eq_intensity * half(:);
end
