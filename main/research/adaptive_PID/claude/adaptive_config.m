function cfg = adaptive_config(overrides)
%ADAPTIVE_CONFIG Single place to tune the adaptive-PID study (the "parametric file").
% Everything the experiment depends on lives here so it can be changed in one spot:
% the margin target, the asymmetric penalty, how fast/aggressively the controller
% adapts, the per-method actuation bounds, the damage scenario, and the M9.1 setup.
%
%   cfg = adaptive_config();                       % defaults
%   cfg = adaptive_config(struct('b_target',0.55)) % override any field
%
% THE TARGET:  keep the M9.1 NCF margin >= cfg.b_target (default 0.5).
% THE PENALTY: asymmetric. Being BELOW the target is corrected fast and hard
%              (k_down); being above is given back slowly and only once safely
%              above target+relax_band. This encodes "I accept being higher, but
%              I highly penalize being lower than the target."

cfg = struct();

% ---- margin target & asymmetric penalty -------------------------------------
cfg.b_target      = 0.50;   % keep the (M9.1-indicated) NCF margin at/above this
cfg.relax_band    = 0.12;   % only relax (give back authority) when margin > target+this
                            % (>0.62): park safely ABOVE the floor, hold; do not hunt at 0.5
cfg.deadband      = 0.005;  % no action inside +/- this of the target

% ---- adaptation law (asymmetric integral on a normalized knob) --------------
cfg.k_down        = 1.8;    % gain when BELOW target (fast, strong) -- the penalty
cfg.k_up          = 0.03;   % gain when comfortably ABOVE target (slow, cautious give-back)
cfg.rate_limit    = 0.06;   % max |change| of the knob per M9.1 window (knob units)
cfg.knob_min      = 0.0;    % 0 = no intervention (nominal controller)
cfg.fallback_dwell= 6;      % ladder methods (M4,M5): hold at the cheap-knob cap this many
                            % windows before escalating to the authority fallback, so the
                            % cheap knob's (lagged) effect on M9.1 can register first

% ---- per-method actuation bounds (knob in [0,1] maps to these) --------------
cfg.a_min         = 0.12;   % authority: a = 1 -> a_min  (uniform PID gain scale)
cfg.gI_min        = 0.20;   % integral detune: gI = 1 -> gI_min (stay in monotone region)
cfg.alpha_min     = 0.045;  % low-pass: one-pole alpha 1(off) -> alpha_min (~14 Hz cutoff)
cfg.depth_max     = 0.80;   % notch: depth 0(off) -> depth_max at the binding frequency
cfg.f_split_hz    = 25;     % schedule/gate split: >= -> high-band (authority), < -> low-band
cfg.f_low_obs_hz  = 8;      % schedule: below this the dip is too low-freq for integral to
                            % be M9.1-observable (pure delay) -> use authority instead
cfg.notch_halfbw  = 0.35;   % notch band-pass half-width as a fraction of the binding freq

% ---- damage scenario (healthy -> case JUMP, same convention as the OSI work) -
cfg.switch_s      = 13;     % time of the healthy->damaged jump (after M9.1 calibrates)
cfg.dur_s         = 48;     % total record length (35 s of damaged adaptation)
cfg.crossfade_s   = 0.10;   % raised-cosine blend at the jump (state-continuous splice)
cfg.cmd_band_hz   = [2 100];% broadband command band so M9.1's S,T branch is excited
cfg.cmd_std_mm    = 1.0;    % command (dd_lead) amplitude [mm]
cfg.meas_noise_fr = 0.01;   % sensor noise as a fraction of dm std
cfg.seed          = 11;     % rng seed for command + disturbance (shared by all methods)

% ---- M9.1 (canonical OSI function) overrides --------------------------------
% Passed straight to m91_adaptive_margin('config', dt, L0, cfg.m91). Defaults of
% the OSI function are used for anything not set here.
cfg.m91 = struct('window_s',5, 'window_hop_s',0.5, 'threshold',0.40, 'cap',0.70);

% ---- project paths (self-locating) ------------------------------------------
here       = fileparts(mfilename('fullpath'));
cfg.dir    = here;
cfg.main   = fileparts(fileparts(fileparts(here)));   % .../main
cfg.osi    = fullfile(cfg.main,'control_and_HS','OSI');
cfg.optdir = fullfile(cfg.main,'research','optimizing_pl','claude');  % osi_test_cases
cfg.results= fullfile(here,'results');

if nargin >= 1 && ~isempty(overrides)
    f = fieldnames(overrides);
    for i = 1:numel(f), cfg.(f{i}) = overrides.(f{i}); end
end
end
