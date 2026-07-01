function [osi_gain_out, ncf_m91, ncf_filtered] = ...
        osi_gain_runtime(dd, dm, enable, m91s, m91f, m91b, m91seg, ...
        m91w, m91keep, m91buf0, m91res0, m91base0, m91hist0, ...
        m91below0, osigs)
%OSI_GAIN_RUNTIME Simulink runtime wrapper for M9.1-driven OSI gain.
% Uses workspace setup prepared by main_ColumnSetup.m at compile time, then
% calls the production M9.1 estimator and OSI gain law during target runtime.

%#codegen

persistent dd_buffer dm_buffer sample_count hop_count m91_state ...
    osi_gain_state last_margin margin_filtered_state margin_guarded_state ...
    above_count below_count cfg update_active update_segment ...
    dd_work dm_work Suu_acc Syy_acc Suy_acc

if isempty(sample_count)
    dd_buffer = m91buf0;
    dm_buffer = m91buf0;
    sample_count = 0;
    hop_count = 0;
    m91_state = struct('window_count', 0, ...
        'cal_count', 0, ...
        'ready', false, ...
        'residual_cal', m91res0, ...
        'residual_baseline', m91base0, ...
        'q_ref', 1, ...
        'margin_history', m91hist0, ...
        'below_history', m91below0 ~= 0, ...
        'detected', false, ...
        'detect_window', NaN);
    osi_gain_state = osigs(1);
    last_margin = m91s(40);
    margin_filtered_state = osigs(2);
    margin_guarded_state = osigs(2);
    above_count = 0;
    below_count = 0;
    cfg = m91Config(m91s, m91f, m91b, m91seg, m91w, m91keep);
    update_active = false;
    update_segment = 1;
    dd_work = m91buf0;
    dm_work = m91buf0;
    Suu_acc = zeros(numel(m91f), 1);
    Syy_acc = zeros(numel(m91f), 1);
    Suy_acc = complex(zeros(numel(m91f), 1));
end

pause_enable = enable >= 2;
if pause_enable
    enable = enable - 2;
end

if pause_enable ~= 0
    dd_buffer = m91buf0;
    dm_buffer = m91buf0;
    sample_count = 0;
    hop_count = 0;
    update_active = false;
    update_segment = 1;
    dd_work = m91buf0;
    dm_work = m91buf0;
    Suu_acc(:) = 0;
    Syy_acc(:) = 0;
    Suy_acc(:) = complex(0);
    if ~m91_state.ready
        m91_state.cal_count = 0;
        m91_state.residual_cal = m91res0;
        m91_state.margin_history = m91hist0;
        m91_state.below_history = m91below0 ~= 0;
        m91_state.detected = false;
        m91_state.detect_window = NaN;
        last_margin = m91s(40);
        margin_filtered_state = osigs(2);
        margin_guarded_state = osigs(2);
        above_count = 0;
        below_count = 0;
    end
    if enable ~= 0
        osi_gain_out = osi_gain_state;
    else
        osi_gain_out = osigs(1);
    end
    ncf_m91 = last_margin;
    ncf_filtered = margin_filtered_state;
    return
end

dd_buffer(1:end-1) = dd_buffer(2:end);
dd_buffer(end) = dd;
dm_buffer(1:end-1) = dm_buffer(2:end);
dm_buffer(end) = dm;
sample_count = sample_count + 1;

if sample_count >= m91s(32)
    hop_count = hop_count + 1;
    if ~update_active && hop_count >= m91s(35)
        hop_count = 0;
        update_active = true;
        update_segment = 1;
        dd_work = dd_buffer;
        dm_work = dm_buffer;
        Suu_acc(:) = 0;
        Syy_acc(:) = 0;
        Suy_acc(:) = complex(0);
    end
end

if update_active
    [Suu_acc, Syy_acc, Suy_acc] = accumulateSpectraSegment( ...
        dd_work, dm_work, cfg, update_segment, Suu_acc, Syy_acc, Suy_acc);
    update_segment = update_segment + 1;
    if update_segment > cfg.n_segment
        Suu = Suu_acc/cfg.n_segment;
        Syy = Syy_acc/cfg.n_segment;
        Suy = Suy_acc/cfg.n_segment;
        T = Suy./max(Suu, eps);
        g2 = min(abs(Suy).^2./max(Suu.*Syy, eps), 1);
        gamma2 = max(0, (cfg.n_segment*g2 - 1)/(cfg.n_segment - 1));
        pin = 10*log10(Suu + eps);
        residual = Syy.*max(1 - gamma2, cfg.residual_floor);
        [last_margin, m91_state] = m91_step_from_spectra( ...
            T, gamma2, pin, residual, cfg, m91_state);
        [candidate_gain, margin_filtered_state, margin_guarded_state, ...
                above_count, below_count] = auth_stability_gain( ...
            last_margin, osi_gain_state, margin_filtered_state, ...
            margin_guarded_state, above_count, below_count, ...
            osigs(2), m91s(36), osigs(3), osigs(4), ...
            osigs(5), osigs(6), osigs(7), osigs(8), ...
            osigs(9), osigs(10), osigs(11), osigs(12), ...
            osigs(13), osigs(14), osigs(15), osigs(16));
        if enable ~= 0
            osi_gain_state = candidate_gain;
        else
            osi_gain_state = osigs(1);
        end
        update_active = false;
    end
end

if enable ~= 0
    osi_gain_out = osi_gain_state;
else
    osi_gain_out = osigs(1);
end
ncf_m91 = last_margin;
ncf_filtered = margin_filtered_state;
end

function cfg = m91Config(m91s, m91f, m91b, m91seg, m91w, m91keep)
cfg = struct('dt', m91s(1), ...
    'fs', m91s(2), ...
    't_start', m91s(3), ...
    'band_hz', [m91s(4) m91s(5)], ...
    'df_hz', m91s(6), ...
    'window_s', m91s(7), ...
    'update_interval_s', m91s(8), ...
    'segment_s', m91s(9), ...
    'segment_hop_s', m91s(10), ...
    'bootstrap_strength', m91s(11), ...
    'input_power_range_db', m91s(12), ...
    'gamma_min', m91s(13), ...
    'min_bins', m91s(14), ...
    'warm_windows', m91s(15), ...
    'margin_filter_n', m91s(16), ...
    'detect_consecutive', m91s(17), ...
    'calibration_s', m91s(18), ...
    'cap', m91s(19), ...
    'threshold', m91s(20), ...
    'residual_floor', m91s(21), ...
    'residual_prctile', m91s(22), ...
    'residual_early_all_bins', m91s(23) ~= 0, ...
    'residual_early_match_hz', m91s(24), ...
    'residual_early_st_floor_frac', m91s(25), ...
    'residual_early_st_gate_frac', m91s(26), ...
    'st_prctile', m91s(27), ...
    'st_power', m91s(28), ...
    'freq_medfilt_n', m91s(29), ...
    'line_reject_hz', [m91s(30) m91s(31)], ...
    'use_residual_branch', m91s(43) ~= 0, ...
    'st_branch_hz', [m91s(44) m91s(45)], ...
    'residual_branch_hz', [m91s(46) m91s(47)], ...
    'st_freq_keep', false(size(m91f)), ...
    'residual_freq_keep', false(size(m91f)));
cfg.freq_hz = m91f;
cfg.window_n = m91s(32);
cfg.segment_n = m91s(33);
cfg.segment_hop_n = m91s(34);
cfg.update_interval_n = m91s(35);
cfg.update_interval_actual_s = m91s(36);
cfg.calibration_windows = m91s(37);
cfg.nfft = m91s(38);
cfg.bin = m91b;
cfg.segment_start = m91seg;
cfg.n_segment = m91s(39);
cfg.window = m91w;
cfg.freq_keep = m91keep ~= 0;
cfg.nominal = m91s(40);
cfg.nominal_index = m91s(41);
cfg.nominal_hz = m91s(42);
cfg.st_freq_keep = cfg.freq_keep ...
    & cfg.freq_hz >= cfg.st_branch_hz(1) ...
    & cfg.freq_hz <= cfg.st_branch_hz(2);
cfg.residual_freq_keep = cfg.freq_keep ...
    & cfg.freq_hz >= cfg.residual_branch_hz(1) ...
    & cfg.freq_hz <= cfg.residual_branch_hz(2);
end

function [Suu, Syy, Suy] = accumulateSpectraSegment( ...
        dd, dm, cfg, segment_index, Suu, Syy, Suy)
idx = cfg.segment_start(segment_index) + (0:cfg.segment_n-1);
U = fft(cfg.window.*osi_detrend_linear(dd(idx)), cfg.nfft);
Y = fft(cfg.window.*osi_detrend_linear(dm(idx)), cfg.nfft);
U = U(cfg.bin);
Y = Y(cfg.bin);
Suu = Suu + abs(U).^2;
Syy = Syy + abs(Y).^2;
Suy = Suy + Y.*conj(U);
end
