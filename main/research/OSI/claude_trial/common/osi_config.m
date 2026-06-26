function cfg = osi_config()
%OSI_CONFIG Shared configuration for all OSI online-stability-indicator trials.
% Units: times are s, frequencies Hz, gains/margins dimensionless.

    % --- locate the repository "main" folder relative to this file ---
    common_dir  = fileparts(mfilename('fullpath'));          % .../claude_trial/common
    project_main = fileparts(fileparts(fileparts(fileparts(common_dir)))); % .../main

    cfg.project_main = project_main;
    cfg.id_utils_dir = fullfile(project_main, ...
        'control_and_HS', 'b_system_id', 'id_utils');        % xfunc, custom_stability_margins
    cfg.results_dir  = fullfile(fileparts(common_dir), 'results');

    % --- data sources ---
    cfg.ref_file = fullfile(project_main, 'saved_results', 'exp_tf', ...
        '20260617_1708_sp_1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015_20260623_174918.mat');
    test_dir = fullfile(project_main, 'saved_results', 'tests', 'important');
    cfg.test_files = { ...   % the data files compared (broadband vs low-frequency input)
        fullfile(test_dir, '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'); ...
        fullfile(test_dir, '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat')};

    % The active data file is overridable via setappdata(0,'osi_data_file',path)
    % so one set of trial scripts can run on either record.
    df = getappdata(0, 'osi_data_file');
    if isempty(df), df = cfg.test_files{1}; end
    cfg.test_file = df;
    [~, base] = fileparts(df);
    tok = regexp(base, '\d{8}_(\d{4})', 'tokens', 'once');
    if isempty(tok), cfg.data_id = 'data'; else, cfg.data_id = tok{1}; end

    % --- per-file analysis window & excitation character ---
    switch cfg.data_id
        case '1749'   % LOW-FREQUENCY input (dd median ~3 Hz); active window 100-286 s
            cfg.t_start = 100;  cfg.t_end = 286;  cfg.low_freq_input = true;
        otherwise     % 1731 broadband input; objective window 620-770.1 s
            cfg.t_start = 620;  cfg.t_end = 770.1; cfg.low_freq_input = false;
    end

    % --- WINDOWING MODE (shared by Methods 1-5) -------------------------------
    % 'sliding'   : fast mode -- update every win_hop s on a win_buf s sliding
    %               buffer (same window as Method 6). Gives 0.5 s detection but
    %               consecutive samples overlap (not independent).
    % 'nonoverlap': original objective-compliant mode -- non-overlapping W s
    %               windows (15 independent samples for the downstream KF).
    cfg.win_mode = 'sliding';
    cfg.win_hop  = 0.5;       % s, indicator update period (sliding mode)
    cfg.win_buf  = 1.5;       % s, sliding analysis buffer (== Method 6 buffer)
    cfg.W        = 10;        % s, non-overlapping window length (nonoverlap mode)

    if strcmp(cfg.win_mode, 'sliding')
        band_default = [10 58];   % brackets the binding ~35 Hz resonance
        cfg.fft_len = 1024;   % 0.5 s sub-segment -> ~2 Hz, ~5 averages in 1.5 s
        cfg.fft_ov  = 512;
        cfg.kf_q    = 1.0e-4; % indicator-KF retuned for the 0.5 s cadence
        cfg.kf_r    = 5.0e-3;
        cfg.detect_consec = 5;  % 5 x 0.5 s = 2.5 s sustained -> declare detection
    else
        band_default = [1 60];
        cfg.fft_len = 2^13;   % ~4 s sub-segment -> 0.25 Hz resolution
        cfg.fft_ov  = 2^12;
        cfg.kf_q    = 4.0e-4;
        cfg.kf_r    = 2.5e-3;
        cfg.detect_consec = 1;  % single 10 s window crossing
    end
    % The margin band must lie where the input actually excites the loop. A
    % low-frequency input (1749) only probes ~1-6 Hz, so the binding 35 Hz mode
    % is unobservable -> evaluate the loop over the excited low band instead.
    if cfg.low_freq_input, cfg.band = [1 8]; else, cfg.band = band_default; end
    cfg.fgrid   = logspace(log10(cfg.band(1)), log10(cfg.band(2)), 3000).';

    % Global input-power gate: keep only FRF bins within this many dB of the
    % in-band peak. This rejects unexcited bins whose FRF is leakage-corrupted
    % (the failure that makes a low-frequency input fake a near-zero margin).
    cfg.input_power_range_db = 30;
    cfg.coh_min = 0.3;        % coherence gate for kept FRF bins

    % --- parametric ID (Methods 2 & 4) ---
    cfg.tf_np = 5;            % plant poles  (matches exp_tf 5p/3z structure)
    cfg.tf_nz = 3;            % plant zeros

    % --- recursive tracker (Method 5) ---
    cfg.dec_factor = 8;       % decimate 2048 -> 256 Hz (dynamics are < 60 Hz)
    cfg.rls_na = 5;
    cfg.rls_nb = 5;
    cfg.rls_nk = 1;
    cfg.rls_lambda = 0.99;    % forgetting factor
    cfg.rls_P0 = 1e3;         % covariance init

    % --- decision threshold (KF q/r and detect_consec set per mode above) ---
    cfg.ncf_threshold = 0.40; % project-standard "acceptable" NCF (cf. ncf04 designs)

    % --- Method 6: recursive frequency-point Kalman filter (fast, small window) ---
    % One complex Kalman state per discrete TF point; coherence sets adaptive R.
    % Update every m6_hop s using an m6_buf s sliding analysis buffer.
    cfg.m6_band   = cfg.band;     % Hz: follows the active (excited) margin band
    cfg.m6_df     = 1;            % Hz: grid spacing  -> e.g. 10:1:58 (49 points)
    cfg.m6_hop    = 0.5;          % s: indicator update period (time resolution)
    cfg.m6_buf    = 1.5;          % s: sliding analysis buffer (freq resolution)
    cfg.m6_Lsub   = 512;          % within-buffer sub-segment length (samples)
    cfg.m6_hsub   = 256;          % sub-segment hop (samples) -> ~11 averages
    cfg.m6_q_rel  = 0.02;         % process noise Q_i = q_rel*|H_i|^2 (tracking speed)
    cfg.m6_R_floor_rel = 2e-3;    % measurement-noise floor, relative to |H_i|^2
    cfg.m6_gamma_min   = 0.5;     % coherence gate: only update confident points
    cfg.m6_P0_rel = 0.05;         % initial std of each point, relative to |H0_i|
    cfg.m6_nwarm  = 6;            % snapshots held at nominal while excitation ramps
    cfg.m6_prctile = 5;           % robust margin = p-th percentile of point distances
    cfg.m6_medfilt = 3;           % median pre-filter on the reported indicator
    cfg.m6_detect_consec = 5;     % snapshots below threshold to declare detection

    % --- Method 7: output-only closed-loop resonance / sensitivity-peak margin ---
    % The binding 35 Hz mode is excited from inside the loop (its growth is the
    % instability), so it is observable in dm ALONE even when the input does not
    % probe 35 Hz (the 1749 case, where the open-loop FRF there is a tautology).
    % Estimate the closed-loop resonance amplification Spk = sqrt(peak/floor PSD)
    % ~ ||S||_inf, then map to the loop-only NCF, calibrated to nominal at start.
    cfg.m7_buf = 4;               % s, analysis buffer (resonance PSD needs averaging)
    cfg.m7_hop = 0.5;             % s, update period
    cfg.m7_peak_band  = [25 40];  % Hz, closed-loop resonance search band
    cfg.m7_floor_band = [42 58];  % Hz, off-resonance noise floor (avoid 60 Hz line)
    cfg.m7_binding_band = [10 58];% Hz, band whose nominal NCF calibrates the map
    cfg.m7_calib_s  = 20;         % s, "model correct at start" calibration window
    cfg.m7_medfilt  = 9;          % median taps on the amplification estimate
    cfg.m7_cap = 0.70;            % cap on the reported margin
    cfg.m7_detect_consec = 7;     % 7 x 0.5 s = 3.5 s sustained -> detection
end
