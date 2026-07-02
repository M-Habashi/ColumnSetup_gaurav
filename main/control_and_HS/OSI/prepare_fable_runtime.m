function setup = prepare_fable_runtime(projectFolder, dt, hs)
%PREPARE_FABLE_RUNTIME Prepare workspace parameter arrays for fable_osi_runtime.
% Mirror of prepare_osi_gain_runtime for the fable OSI + authority law:
% builds the fable config (fable_osi) and authority parameters (fable_auth)
% from the hs struct + exp_tf file, flattens everything into FIXED-SIZE
% numeric arrays and assigns them into the caller workspace so the Simulink
% MATLAB Function block (body: fable_osi_runtime) can read them as
% Parameter-scoped symbols.
%
%   setup = prepare_fable_runtime(projectFolder, dt, hs)
%
% hs fields used (all optional except exp_tf_file):
%   exp_tf_file          exp_tf .mat with H_dc_dm (+ pid_values) - the
%                        prior loop model (nominal margin curve + pred)
%   target_outer_ncf     OSI level the authority law regulates onto
%                        (default 0.55). Also the OSI detection threshold.
%   osi_gain_min         authority floor  (default 0.08)
%   osi_gain_initial     startup authority (default 1.0 - the fable law
%                        defends the margin; starting detuned is not needed)
%   fable_osi_override   struct of fable_osi config overrides (see the
%                        PER-BRANCH TUNING GUIDE in fable_osi.m)
%   fable_auth_override  struct of fable_auth parameter overrides (see the
%                        TUNING GUIDE in fable_auth.m)
%
% Workspace arrays produced (all fixed-size doubles):
%   fbls     scalar OSI config vector      (indices documented below)
%   fblw     slow segment Hann window      (segment_n x 1)
%   fblbins  per-slow-bin table            (nf x 5)
%            [freq_hz, fft_bin, keep, res_keep, nominal_curve]
%   fblfw    fast segment Hann window      (fast_segment_n x 1)
%   fblfbins per-fast-bin table            (nf_fast x 6)
%            [freq_hz, fft_bin, keep, cell_lo, cell_hi, band_id]
%   fblag    authority-prediction gain grid (n_alpha x 1)
%   fbla     authority-law parameter vector (indices documented below)
%
% The equivalence of fable_osi_runtime against fable_osi/fable_auth is
% asserted by OSI_tests/fable/test_fable_runtime_equivalence.m - run it
% after ANY change to either side.

defaults = struct( ...
    'target_outer_ncf', 0.55, ...
    'osi_gain_min', 0.08, ...
    'osi_gain_initial', 1.0);

target_outer_ncf = defaults.target_outer_ncf;
if isfield(hs, 'target_outer_ncf') && ~isempty(hs.target_outer_ncf)
    target_outer_ncf = hs.target_outer_ncf;
end
a_min = defaults.osi_gain_min;
if isfield(hs, 'osi_gain_min') && ~isempty(hs.osi_gain_min)
    a_min = hs.osi_gain_min;
end
a_init = defaults.osi_gain_initial;
if isfield(hs, 'osi_gain_initial') && ~isempty(hs.osi_gain_initial)
    a_init = hs.osi_gain_initial;
end
osi_override = struct();
if isfield(hs, 'fable_osi_override') && ~isempty(hs.fable_osi_override)
    osi_override = hs.fable_osi_override;
end
auth_override = struct();
if isfield(hs, 'fable_auth_override') && ~isempty(hs.fable_auth_override)
    auth_override = hs.fable_auth_override;
end

% ---- prior loop model ----------------------------------------------------
[exp_tf_data, exp_tf_file, exp_tf_name] = ...
    load_saved_result_file(projectFolder, 'exp_tf', false, hs.exp_tf_file);
assert(isfield(exp_tf_data, 'H_dc_dm'), ...
    ['The selected exp_tf file must contain H_dc_dm. Run ' ...
     'control_and_HS\b_system_id\sys_id.m first.'])
H_dc_dm = exp_tf_data.H_dc_dm;
if get(H_dc_dm, 'Ts') == 0
    H_dc_dm = c2d(H_dc_dm, dt, 'zoh');
elseif abs(get(H_dc_dm, 'Ts') - dt) > 10*eps(dt)
    H_dc_dm = d2d(H_dc_dm, dt, 'zoh');
end
if isfield(exp_tf_data, 'pid_values')
    pid_values = exp_tf_data.pid_values;
else
    pid_values = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
        'derivative_filter_N', 512);
end
if ~isfield(pid_values, 'derivative_filter_N')
    pid_values.derivative_filter_N = 512;
end
C = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

% ---- fable config + authority params ------------------------------------
if ~isfield(osi_override, 'threshold')
    osi_override.threshold = target_outer_ncf;
end
cfg = fable_osi('config', dt, C*H_dc_dm, osi_override);

auth_override.target = target_outer_ncf;
auth_override.a_min = a_min;
auth_override.a_init = a_init;
if ~isfield(auth_override, 'dt_update')
    auth_override.dt_update = cfg.step_s;
end
prm = fable_auth('params', auth_override);

% the runtime's hand-coded median filters assume odd, centered windows
assert(mod(cfg.freq_medfilt_n, 2) == 1, ...
    'freq_medfilt_n must be odd for the runtime median filters.')

pred_enable = 1;   % set 0 to skip the prediction grid (TET reduction; the
                   % authority law then regulates by power law alone)
if isfield(hs, 'fable_pred_enable') && ~isempty(hs.fable_pred_enable)
    pred_enable = double(hs.fable_pred_enable ~= 0);
end

% ---- fbls: scalar OSI config vector --------------------------------------
% Index map (KEEP IN SYNC with fable_osi_runtime unpackConfig):
%  1 dt                  2 fs                  3 step_n
%  4 steps_per_hop       5 segment_n(=nfft)    6 n_segment
%  7 k_eff               8 gamma_gate          9 gamma_quiet
% 10 input_power_range_db 11 sidelobe_db      12 min_bins
% 13 freq_medfilt_n      14 margin_filter_n   15 slow_filt_alpha
% 16 cap                 17 threshold         18 residual_floor
% 19 cal_skip_s          20 cal_windows       21 cal_reject_factor
% 22 cal_restart_rejects 23 cal_timeout_hops  24 cal_min_windows
% 25 z_on                26 z_off             27 res_on_n
% 28 res_hold_hops       29 res_min_growth_db 30 res_match_hz
% 31 sigma0_floor        32 bl_alpha          33 bl_adapt_max_db
% 34 regime_hops         35 warm_updates      36 fast_segment_n(=fast_nfft)
% 37 fast_ring_n         38 fast_min_bins     39 fast_st_nu
% 40 fast_st_h           41 fast_burst_nu     42 fast_burst_h
% 43 fast_babs_offset    44 fast_pin_lo       45 fast_pin_hi
% 46 fast_pin_alpha      47 fast_sig_floor    48 fast_d_sig_floor
% 49 n_burst_bands       50 n_alpha           51 pred_denom_floor
% 52 hop_s               53 nf                54 nf_fast
% 55 pred_enable         56 fast_amove_frac   57 amove_hold
fbls = [cfg.dt; cfg.fs; cfg.step_n; ...
    cfg.steps_per_hop; cfg.segment_n; cfg.n_segment; ...
    cfg.k_eff; cfg.gamma_gate; cfg.gamma_quiet; ...
    cfg.input_power_range_db; cfg.sidelobe_db; cfg.min_bins; ...
    cfg.freq_medfilt_n; cfg.margin_filter_n; cfg.slow_filt_alpha; ...
    cfg.cap; cfg.threshold; cfg.residual_floor; ...
    cfg.cal_skip_s; cfg.cal_windows; cfg.cal_reject_factor; ...
    cfg.cal_restart_rejects; cfg.cal_timeout_hops; cfg.cal_min_windows; ...
    cfg.z_on; cfg.z_off; cfg.res_on_n; ...
    cfg.res_hold_hops; cfg.res_min_growth_db; cfg.res_match_hz; ...
    cfg.sigma0_floor; cfg.bl_alpha; cfg.bl_adapt_max_db; ...
    cfg.regime_hops; cfg.warm_updates; cfg.fast_segment_n; ...
    cfg.fast_ring_n; cfg.fast_min_bins; cfg.fast_st_nu; ...
    cfg.fast_st_h; cfg.fast_burst_nu; cfg.fast_burst_h; ...
    cfg.fast_babs_offset; cfg.fast_pin_lo; cfg.fast_pin_hi; ...
    cfg.fast_pin_alpha; cfg.fast_sig_floor; cfg.fast_d_sig_floor; ...
    cfg.n_burst_bands; cfg.n_alpha; cfg.pred_denom_floor; ...
    cfg.hop_s; cfg.nf; cfg.nf_fast; ...
    pred_enable; cfg.fast_amove_frac; cfg.amove_hold];

fblw = cfg.window;
fblbins = [cfg.freq_hz, cfg.bin, double(cfg.keep), double(cfg.res_keep), ...
    cfg.nominal_curve];
fblfw = cfg.fast_window;
fblfbins = [cfg.fast_freq_hz, cfg.fast_bin, double(cfg.fast_keep), ...
    cfg.fast_cell_lo, cfg.fast_cell_hi, cfg.fast_band_id];
fblag = cfg.alpha_grid;

% ---- fbla: authority-law parameter vector --------------------------------
% Index map (KEEP IN SYNC with fable_osi_runtime fableAuthStep):
%  1 target          2 a_min           3 a_max           4 a_init
%  5 dt_update       6 filt_alpha      7 down_deadband   8 down_confirm_n
%  9 down_power     10 down_rate      11 sev_frac       12 sev_down_rate
% 13 up_deadband    14 up_hold_s      15 up_rate        16 up_rate_blind
% 17 up_prop        18 min_step       19 use_pred       20 pred_guard
% 21 pred_floor_frac 22 trip_drop     23 trip_power     24 trip_cool_s
% 25 trip_undo_s    26 latch_relax    27 latch_decay_tau_s
% 28 down_settle_s  29 re_shed_delta  30 self_move_gate_s 31 self_move_frac
fbla = [prm.target; prm.a_min; prm.a_max; prm.a_init; ...
    prm.dt_update; prm.filt_alpha; prm.down_deadband; ...
    prm.down_confirm_n; prm.down_power; prm.down_rate; ...
    prm.sev_frac; prm.sev_down_rate; prm.up_deadband; prm.up_hold_s; ...
    prm.up_rate; prm.up_rate_blind; prm.up_prop; prm.min_step; ...
    prm.use_pred; prm.pred_guard; prm.pred_floor_frac; prm.trip_drop; ...
    prm.trip_power; prm.trip_cool_s; prm.trip_undo_s; prm.latch_relax; ...
    prm.latch_decay_tau_s; prm.down_settle_s; prm.re_shed_delta; ...
    prm.self_move_gate_s; prm.self_move_frac];

assignin('caller', 'fbls', fbls);
assignin('caller', 'fblw', fblw);
assignin('caller', 'fblbins', fblbins);
assignin('caller', 'fblfw', fblfw);
assignin('caller', 'fblfbins', fblfbins);
assignin('caller', 'fblag', fblag);
assignin('caller', 'fbla', fbla);

setup = struct('exp_tf_file', exp_tf_file, ...
    'exp_tf_name', exp_tf_name, ...
    'cfg', cfg, 'prm', prm, ...
    'fbls', fbls, 'fblw', fblw, 'fblbins', fblbins, ...
    'fblfw', fblfw, 'fblfbins', fblfbins, 'fblag', fblag, ...
    'fbla', fbla, ...
    'target_outer_ncf', target_outer_ncf, ...
    'gain_initial', a_init, 'gain_min', a_min);
end
