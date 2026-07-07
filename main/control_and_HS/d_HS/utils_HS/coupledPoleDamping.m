function damping = coupledPoleDamping(closed_loop_poles, sample_dt, band_hz)
%COUPLEDPOLEDAMPING Minimum damping ratio of coupled poles in a band.
%
%   damping = coupledPoleDamping(closed_loop_poles, sample_dt, band_hz)
%
% Maps the discrete coupled RTHS closed-loop poles z to continuous
% equivalents s = log(z)/dt and reports the minimum damping ratio
% zeta = -Re(s)/|s| among poles whose natural frequency |s|/(2*pi) falls
% inside band_hz = [lo hi]. This is the "no infinite oscillation"
% quantity: a coupled pole pair with zeta ~ 0 rings forever on the rig
% even though |z| < 1 says "stable" (seen on 2026-07-06: pl_5k had
% max|z| = 0.9998, i.e. zeta ~ 0 at the hybrid modes, and the post-quake
% response never decayed).
%
% Returns a struct:
%   min_damping     smallest in-band zeta (Inf when no pole is in band;
%                   negative when an in-band pole is unstable)
%   min_damping_hz  natural frequency of that pole [Hz]
%   zeta, fn_hz     per-pole damping ratios and natural frequencies
%
% Edge cases: z = 0 (Newmark deadbeat poles) and negative-real poles map
% to fn at/above Nyquist and are excluded by any physical band; z = 1
% (rigid-body) maps to fn = 0 and is excluded when band_hz(1) > 0.

s = log(closed_loop_poles(:))/sample_dt;
wn = abs(s);
fn_hz = wn/(2*pi);
zeta = -real(s)./max(wn, eps);
in_band = fn_hz >= band_hz(1) & fn_hz <= band_hz(2);
if any(in_band)
    zeta_band = zeta(in_band);
    fn_band = fn_hz(in_band);
    [min_damping, min_index] = min(zeta_band);
    min_damping_hz = fn_band(min_index);
else
    min_damping = Inf;
    min_damping_hz = NaN;
end
damping = struct('min_damping', min_damping, ...
    'min_damping_hz', min_damping_hz, 'zeta', zeta, 'fn_hz', fn_hz);
end
