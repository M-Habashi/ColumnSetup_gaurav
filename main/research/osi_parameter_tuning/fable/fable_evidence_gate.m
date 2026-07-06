function varargout = fable_evidence_gate(varargin)
%FABLE_EVIDENCE_GATE Excitation-evidence arming for the fable OSI margin.
%
%   prm = fable_evidence_gate('params', override)
%   gst = fable_evidence_gate('state', prm)
%   [b_out, valid_out, armed, gst] = fable_evidence_gate(u_step, b, ...
%       valid_up, prm, gst)                                       % per step
%
% WHY: the slow OSI margin is only meaningful while the command tap carries
% genuine exogenous excitation. At RTHS start (EQ ramp-in), during lulls,
% after the earthquake dies, or in a closed loop idling without input, the
% analysis window is dominated by circulating noise: the estimator then
% reports a biased LOW margin with no real evidence behind it, and the
% authority law sheds on it. fable_auth already has the correct "no
% evidence -> HOLD authority" path for b = NaN (fable_auth.m line ~308).
% This gate decides, from the OSI's own input signal, when that path should
% be taken:
%
%   present  <- trailing exc_win_s RMS of u_osi > theta_mm
%   armed    <- present has held for arm_s (one full slow analysis window
%               + margin-median span, so everything the estimator remembers
%               was produced under real excitation)
%   dropout  <- present false for longer than drop_s disarms
%   fade     <- 1 s RMS < fade_frac x 6 s RMS blanks the margin for
%               fade_hold_s WITHOUT disarming: an abruptly ENDING
%               excitation phase leaves the analysis window full of stale
%               strong segments ~1 s before the absolute threshold reacts,
%               and the margin dips spuriously right there (seen at t=72
%               in RHTS_no_inst_butindicators_jump). A temporary blank
%               kills that shed; if the lull is real the ordinary dropout
%               path disarms right behind it, and if it was just an EQ
%               lull the gate returns without paying the full re-arm
%               time. Only FALLING excitation blanks - a rising level
%               (e.g. a genuine divergence growing the response) never
%               blanks itself.
%
% While NOT armed the slow margin is passed as NaN (law holds authority).
% FAST trips are deliberately NOT gated: fable_auth processes trips before
% the NaN hold ("act immediately, regardless of margin validity"), so the
% burst/FRF guards keep protecting against a genuine divergence even while
% the slow margin is blanked - including a divergence that starts from an
% idle loop, which raises the excitation measure itself and arms the gate
% within arm_s anyway.
%
% Simulink realization (no algorithm change): RMS block (2 s) -> compare
% (theta) -> TON on-delay (arm_s) with TOF drop (drop_s) -> switch that
% replaces the runtime's published margin with NaN while unarmed (or gates
% the enable of the authority update). All constants are plain parameters.
%
% Defaults calibrated on RTHS_02 (see run_evidence_gate_validation):
%   theta_mm 0.05 - ramp-in/idle sit at 0.002-0.04 mm, strong motion at
%                   0.26-0.79 mm, post-EQ force-feedback response at
%                   0.075-0.083 mm (stays armed), disengaged < 0.02 mm.
%   arm_s    6    - window_s (5 s) + margin median span + pad.
%   drop_s   0.75 - EQ lulls shorter than this do not disarm.

if ischar(varargin{1})
    switch lower(varargin{1})
        case 'params'
            prm = struct('dt_step', 0.125, 'exc_win_s', 2.0, ...
                'theta_mm', 0.05, 'arm_s', 6.0, 'drop_s', 0.75, ...
                'fade_short_s', 1.0, 'fade_long_s', 6.0, ...
                'fade_frac', 0.5, 'fade_hold_s', 4.0);
            if nargin >= 2
                fn = fieldnames(varargin{2});
                for i = 1:numel(fn)
                    assert(isfield(prm, fn{i}), ...
                        'fable_evidence_gate: unknown param %s', fn{i})
                    prm.(fn{i}) = varargin{2}.(fn{i});
                end
            end
            prm.n_ring = max(1, round(prm.fade_long_s/prm.dt_step));
            prm.n_pres = max(1, round(prm.exc_win_s/prm.dt_step));
            prm.n_short = max(1, round(prm.fade_short_s/prm.dt_step));
            varargout = {prm};
        case 'state'
            prm = varargin{2};
            gst = struct('ms_ring', zeros(prm.n_ring, 1), ...
                'ring_pos', 0, 'ring_n', 0, ...
                'arm_t', 0, 'drop_t', 0, 'blank_t', 0, 'armed', false);
            varargout = {gst};
        otherwise
            error('fable_evidence_gate: unknown command %s', varargin{1})
    end
    return
end

% ---- per-step call --------------------------------------------------------
[u_step, b, valid_up, prm, gst] = deal(varargin{1:5});

% trailing-window RMS from per-step mean squares (exact, O(1) memory).
% The ring holds fade_long_s of per-step mean squares; the presence and
% fade-short measures are sums over the newest n_pres / n_short entries.
gst.ring_pos = mod(gst.ring_pos, prm.n_ring) + 1;
gst.ms_ring(gst.ring_pos) = mean(u_step.^2);
gst.ring_n = min(gst.ring_n + 1, prm.n_ring);
idx = mod(gst.ring_pos - (0:prm.n_ring-1) - 1, prm.n_ring) + 1;  % newest first
np = min(prm.n_pres, gst.ring_n);
ns = min(prm.n_short, gst.ring_n);
exc_pres = sqrt(sum(gst.ms_ring(idx(1:np)))/np);
exc_short = sqrt(sum(gst.ms_ring(idx(1:ns)))/ns);
exc_long = sqrt(sum(gst.ms_ring)/gst.ring_n);

present = gst.ring_n >= prm.n_pres && exc_pres > prm.theta_mm;
fade_stale = gst.ring_n >= prm.n_ring ...
    && exc_short < prm.fade_frac*exc_long && exc_long > prm.theta_mm;
if fade_stale
    gst.blank_t = prm.fade_hold_s;     % stale NOW: blank, don't disarm
else
    gst.blank_t = max(0, gst.blank_t - prm.dt_step);
end
if present
    gst.arm_t = gst.arm_t + prm.dt_step;
    gst.drop_t = 0;
else
    gst.drop_t = gst.drop_t + prm.dt_step;
    if gst.drop_t >= prm.drop_s
        gst.arm_t = 0;                 % stale: disarm, re-arm from scratch
        gst.blank_t = 0;
    end
end
gst.armed = gst.arm_t >= prm.arm_s && gst.blank_t <= 0;

if gst.armed
    b_out = b;
    valid_out = valid_up;
else
    b_out = NaN;                       % fable_auth: "no evidence -> hold"
    valid_out = false;
end
varargout = {b_out, valid_out, gst.armed, gst};
end
