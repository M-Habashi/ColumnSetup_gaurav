function [out, state, info, seeds] = m91_adaptive_margin(varargin)
%M91_ADAPTIVE_MARGIN Method 9.1 online NCF margin estimator.
%
% MATLAB setup from the initial nominal loop transfer function:
%   addpath(genpath(fullfile(project_root, 'control_and_HS', 'OSI')))
%   cfg = m91_adaptive_margin('config', dt, initial_loop_tf);
%   state = m91_adaptive_margin('state', cfg);
%   result = m91_adaptive_margin('run', dd_lead, dm, dt, initial_loop_tf);
%
% Simulink/Speedgoat runtime call:
%   [margin, state, info] = m91_adaptive_margin(dd_window, dm_window, cfg, state);
%
% Inputs:
%   initial_loop_tf - nominal open-loop transfer function L0, required when
%       building cfg. It is not used on the target.
%   dd_window - command displacement entering the loop, cfg.window_n samples.
%   dm_window - measured displacement in the same units, cfg.window_n samples.
%   cfg - numeric setup returned by the 'config' command. Set
%       override.update_interval_s to choose the OSI update interval. The
%       default is 0.005 s.
%   state - online state returned by the 'state' command or prior step.
%
% Outputs:
%   margin - current normalized-coprime-factor margin estimate.
%   info - branch diagnostics: branch margins, binding frequencies, detection.
%   seeds - optional per-frequency spectra/coherence/residual data for plots.
%
% Math summary:
%   The nominal margin is computed from L0 as
%     b0(w) = |1 + L0(w)|/sqrt(2*(1 + |L0(w)|^2)).
%   M9.1 keeps two branches because the command may or may not excite the
%   critical frequency. Branch 2 is best when dd_lead has enough power and
%   coherence; it estimates T = dm/dd_lead, S = 1 - T, then
%     b_ST = 1/(sqrt(2)*max sqrt(|S|^2 + |T|^2)).
%   This is phase-aware. Branch 3 is best when the input is quiet near the
%   critical frequency; it tracks residual output power after removing the
%   command-correlated part by coherence and compares it to the healthy
%   calibration. The reported margin is min(b_ST, b_res). Branch 1 is not
%   used.

if ischar(varargin{1})
    [out, state, info, seeds] = commandMode(varargin{:});
else
    if nargout >= 4
        [out, state, info, seeds] = stepMode(varargin{1}, varargin{2}, ...
            varargin{3}, varargin{4}, true);
    else
        [out, state, info] = stepMode(varargin{1}, varargin{2}, ...
            varargin{3}, varargin{4}, false);
        seeds = [];
    end
end
end

function [out, state, info, seeds] = commandMode(command, varargin)
state = [];
info = [];
seeds = [];
switch lower(command)
    case 'config'
        override = struct();
        if numel(varargin) >= 3
            override = varargin{3};
        end
        out = makeConfig(varargin{1}, varargin{2}, override);
    case 'state'
        out = makeState(varargin{1});
    case 'run'
        override = struct();
        if numel(varargin) >= 5
            override = varargin{5};
        end
        [out, seeds] = runRecord(varargin{1}, varargin{2}, varargin{3}, ...
            varargin{4}, override);
    otherwise
        error('m91_adaptive_margin:UnknownCommand', ...
            'Use ''config'', ''state'', ''run'', or the numeric step call.')
end
end

function cfg = makeConfig(dt, initial_loop_tf, override)
cfg = struct( ...
    'dt', dt, ...
    'fs', 1/dt, ...
    't_start', 0, ...
    'band_hz', [2 100], ...
    'df_hz', 1, ...
    'window_s', 5, ...
    'update_interval_s', 0.005, ...
    'segment_s', 512/2048, ...
    'segment_hop_s', 256/2048, ...
    'bootstrap_strength', 0, ...
    'input_power_range_db', 30, ...
    'gamma_min', 0.47, ...
    'min_bins', 3, ...
    'warm_windows', 5, ...
    'margin_filter_n', 3, ...
    'detect_consecutive', 1, ...
    'calibration_s', 7.5, ...
    'cap', 0.70, ...
    'threshold', 0.40, ...
    'residual_floor', 0.03, ...
    'residual_prctile', 99, ...
    'residual_early_all_bins', true, ...
    'residual_early_match_hz', 4, ...
    'residual_early_st_floor_frac', 0.80, ...
    'residual_early_st_gate_frac', 0.80, ...
    'st_prctile', 100, ...
    'st_power', 1.15, ...
    'freq_medfilt_n', 3, ...
    'line_reject_hz', [58 62]);

names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i})
        error('m91_adaptive_margin:UnknownConfigField', ...
            'Unknown M9.1 config field: %s', names{i})
    end
    cfg.(names{i}) = override.(names{i});
end

if ~isscalar(cfg.update_interval_s) || ~isnumeric(cfg.update_interval_s) ...
        || ~isfinite(cfg.update_interval_s) || cfg.update_interval_s <= 0
    error('m91_adaptive_margin:InvalidUpdateInterval', ...
        'update_interval_s must be a positive finite scalar in seconds.')
end

cfg.freq_hz = (cfg.band_hz(1):cfg.df_hz:cfg.band_hz(2)).';
cfg.window_n = round(cfg.window_s*cfg.fs);
cfg.segment_n = round(cfg.segment_s*cfg.fs);
cfg.segment_hop_n = round(cfg.segment_hop_s*cfg.fs);
cfg.update_interval_n = max(1, round(cfg.update_interval_s*cfg.fs));
cfg.update_interval_actual_s = cfg.update_interval_n/cfg.fs;
cal_tc = cfg.window_s:cfg.update_interval_actual_s:cfg.calibration_s;
cfg.calibration_windows = nnz(cal_tc < cfg.calibration_s);
if cfg.calibration_windows == 0
    cfg.calibration_windows = cfg.warm_windows;
end
cfg.nfft = 2^nextpow2(max(cfg.segment_n, round(cfg.fs/cfg.df_hz)));
cfg.bin = round(cfg.freq_hz*cfg.nfft/cfg.fs) + 1;
cfg.segment_start = (1:cfg.segment_hop_n:cfg.window_n-cfg.segment_n+1).';
cfg.n_segment = numel(cfg.segment_start);

n = (0:cfg.segment_n-1).';
cfg.window = 0.5 - 0.5*cos(2*pi*n/(cfg.segment_n - 1));
cfg.freq_keep = cfg.freq_hz >= cfg.band_hz(1) ...
    & cfg.freq_hz <= cfg.band_hz(2) ...
    & ~(cfg.freq_hz >= cfg.line_reject_hz(1) ...
    & cfg.freq_hz <= cfg.line_reject_hz(2));

L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
dist = abs(1 + L0(:))./sqrt(2*(1 + abs(L0(:)).^2));
[cfg.nominal, cfg.nominal_index] = min(dist);
cfg.nominal_hz = cfg.freq_hz(cfg.nominal_index);
end

function state = makeState(cfg)
nf = numel(cfg.freq_hz);
state = struct( ...
    'window_count', 0, ...
    'cal_count', 0, ...
    'ready', false, ...
    'residual_cal', NaN(nf, cfg.calibration_windows), ...
    'residual_baseline', ones(nf, 1), ...
    'q_ref', 1, ...
    'margin_history', cfg.nominal*ones(cfg.margin_filter_n, 1), ...
    'below_history', false(cfg.detect_consecutive, 1), ...
    'detected', false, ...
    'detect_window', NaN);
end

function [result, seeds] = runRecord(dd_lead, dm, dt, initial_loop_tf, override)
cfg = makeConfig(dt, initial_loop_tf, override);
dd_lead = dd_lead(:);
dm = dm(:);
hop_n = cfg.update_interval_n;
n_window = floor((min(numel(dd_lead), numel(dm)) - cfg.window_n)/hop_n) + 1;

tc = ((0:n_window-1)'*hop_n + cfg.window_n)*dt;
nf = numel(cfg.freq_hz);
seg_idx = (0:cfg.segment_n-1).' + cfg.segment_start.';
That = NaN(nf, n_window);
gam2 = NaN(nf, n_window);
pin = NaN(nf, n_window);
pres = NaN(nf, n_window);
seeds = cell(n_window, 1);

for k = 1:n_window
    idx = (k-1)*hop_n + (1:cfg.window_n);
    u = dd_lead(idx);
    y = dm(idx);
    U = fft(cfg.window.*detrend(u(seg_idx)), cfg.nfft, 1);
    Y = fft(cfg.window.*detrend(y(seg_idx)), cfg.nfft, 1);
    U = U(cfg.bin, :);
    Y = Y(cfg.bin, :);
    wseg = segmentWeights(cfg.n_segment, cfg.bootstrap_strength);
    Suu = abs(U).^2*wseg;
    Syy = abs(Y).^2*wseg;
    Suy = (Y.*conj(U))*wseg;
    That(:, k) = Suy./max(Suu, eps);
    g2 = min(abs(Suy).^2./max(Suu.*Syy, eps), 1);
    gam2(:, k) = max(0, (cfg.n_segment*g2 - 1)/(cfg.n_segment - 1));
    pin(:, k) = 10*log10(Suu + eps);
    pres(:, k) = Syy.*max(1 - gam2(:, k), cfg.residual_floor);
    seeds{k} = seedStruct(cfg, That(:, k), gam2(:, k), pin(:, k), ...
        pres(:, k), NaN(nf, 1));
end

cal_mask = tc < cfg.t_start + cfg.calibration_s;
if ~any(cal_mask)
    cal_mask(1:min(cfg.warm_windows, n_window)) = true;
end
pres0 = median(pres(:, cal_mask), 2, 'omitnan');
pres0 = max(pres0, median(pres0(isfinite(pres0) & pres0 > 0), ...
    'omitnan')*1e-6);

ratio = pres./pres0;
ratio(~cfg.freq_keep, :) = NaN;
for k = 1:n_window
    ratio(:, k) = osi_moving_median(ratio(:, k), cfg.freq_medfilt_n);
    seeds{k}.residual_ratio = ratio(:, k);
end

q_ref = median(localPrctileColumns(ratio(:, cal_mask), ...
    cfg.residual_prctile), 'omitnan');
if ~isfinite(q_ref) || q_ref <= 0
    q_ref = 1;
end

ncf_res = NaN(n_window, 1);
ncf_res_early = NaN(n_window, 1);
ncf_st = NaN(n_window, 1);
f_res = NaN(n_window, 1);
f_res_early = NaN(n_window, 1);
f_st = NaN(n_window, 1);
n_excited = zeros(n_window, 1);
n_quiet = zeros(n_window, 1);

for k = 1:n_window
    excited = pin(:, k) >= max(pin(:, k), [], 'omitnan') ...
        - cfg.input_power_range_db;
    keep = excited & gam2(:, k) >= cfg.gamma_min & cfg.freq_keep;
    n_excited(k) = nnz(keep);
    quiet_keep = cfg.freq_keep & ~keep;
    n_quiet(k) = nnz(quiet_keep);

    [ncf_res(k), f_res(k)] = residualBranch(ratio(:, k), ...
        quiet_keep, cfg, q_ref);

    if cfg.residual_early_all_bins
        [ncf_res_early(k), f_res_early(k)] = residualBranch( ...
            ratio(:, k), cfg.freq_keep, cfg, q_ref);
    end

    [ncf_st(k), f_st(k)] = stBranch(That(:, k), keep, cfg, k);

    if isfinite(f_st(k)) ...
            && ncf_st(k) > cfg.residual_early_st_gate_frac*cfg.nominal ...
            && ncf_st(k) < cfg.nominal
        ncf_floor = cfg.residual_early_st_floor_frac*ncf_st(k);
        if isfinite(f_res(k)) ...
                && abs(f_st(k) - f_res(k)) <= cfg.residual_early_match_hz
            ncf_res(k) = max(ncf_res(k), ncf_floor);
        end
        if cfg.residual_early_all_bins && isfinite(f_res_early(k)) ...
                && abs(f_st(k) - f_res_early(k)) ...
                <= cfg.residual_early_match_hz
            ncf_early = max(ncf_res_early(k), ncf_floor);
            if ncf_early < ncf_res(k)
                ncf_res(k) = ncf_early;
                f_res(k) = f_res_early(k);
            end
        end
    end
end

ncf_raw = min([ncf_st, ncf_res], [], 2, 'omitnan');
ncf = movmedian(ncf_raw, [cfg.margin_filter_n-1 0], 'omitnan');
ncf(1:min(cfg.warm_windows, n_window)) = cfg.nominal;

below = ncf < cfg.threshold;
below(isnan(below)) = false;
hit = find(movsum(below, [cfg.detect_consecutive-1, 0]) ...
    >= cfg.detect_consecutive, 1);
detect_time = NaN;
if ~isempty(hit)
    detect_time = tc(hit);
end

result = struct('tc', tc, 'ncf', ncf, 'ncf_raw', ncf_raw, ...
    'ncf_residual', ncf_res, 'ncf_residual_early', ncf_res_early, ...
    'ncf_st', ncf_st, 'nominal', cfg.nominal, ...
    'threshold', cfg.threshold, 'detect_time', detect_time, ...
    'f9', cfg.freq_hz, 'f_residual', f_res, ...
    'f_residual_early', f_res_early, 'f_st', f_st, ...
    'n_excited', n_excited, 'n_quiet', n_quiet, ...
    'q_ref', q_ref, 'nominal_hz', cfg.nominal_hz);
end

function [margin, state, info, seeds] = stepMode(dd, dm, cfg, state, want_seeds)
dd = dd(:);
dm = dm(:);
[T, gamma2, pin, residual] = spectra(dd, dm, cfg);
[margin, state, info] = m91_step_from_spectra( ...
    T, gamma2, pin, residual, cfg, state);
if want_seeds
    ratio = NaN(size(residual));
    if state.ready
        ratio = residual./state.residual_baseline;
        ratio(~cfg.freq_keep | ratio <= 0) = NaN;
        ratio = osi_moving_median(ratio, cfg.freq_medfilt_n);
    end
    seeds = seedStruct(cfg, T, gamma2, pin, residual, ratio);
else
    seeds = [];
end
end

function [T, gamma2, pin, residual] = spectra(dd, dm, cfg)
nf = numel(cfg.freq_hz);
Suu = zeros(nf, 1);
Syy = zeros(nf, 1);
Suy = complex(zeros(nf, 1));

for k = 1:cfg.n_segment
    idx = cfg.segment_start(k) + (0:cfg.segment_n-1);
    U = fft(cfg.window.*osi_detrend_linear(dd(idx)), cfg.nfft);
    Y = fft(cfg.window.*osi_detrend_linear(dm(idx)), cfg.nfft);
    U = U(cfg.bin);
    Y = Y(cfg.bin);
    Suu = Suu + abs(U).^2;
    Syy = Syy + abs(Y).^2;
    Suy = Suy + Y.*conj(U);
end

Suu = Suu/cfg.n_segment;
Syy = Syy/cfg.n_segment;
Suy = Suy/cfg.n_segment;
T = Suy./max(Suu, eps);
g2 = min(abs(Suy).^2./max(Suu.*Syy, eps), 1);
gamma2 = max(0, (cfg.n_segment*g2 - 1)/(cfg.n_segment - 1));
pin = 10*log10(Suu + eps);
residual = Syy.*max(1 - gamma2, cfg.residual_floor);
end

function [ncf, freq_hz] = residualBranch(ratio, keep, cfg, q_ref)
scan = ratio;
scan(~keep) = NaN;
[q_now, idx] = max(scan, [], 'omitnan');
if isempty(q_now) || ~isfinite(q_now)
    q_now = q_ref;
    idx = cfg.nominal_index;
end
freq_hz = cfg.freq_hz(idx);
ncf = min(cfg.cap, cfg.nominal*sqrt(q_ref/max(q_now, q_ref)));
end

function y = localPrctileColumns(x, pct)
y = NaN(1, size(x, 2));
for k = 1:size(x, 2)
    y(k) = osi_prctile_finite(x(:, k), pct);
end
end

function w = segmentWeights(n, strength)
if strength <= 0
    w = ones(n, 1);
else
    w = -log(max(rand(n, 1), realmin));
    w = 1 + strength*(w/mean(w) - 1);
    w = max(w, 0);
    w = n*w/sum(w);
end
end

function [ncf, freq_hz] = stBranch(T, keep, cfg, window_count)
ncf = cfg.cap;
freq_hz = NaN;
if window_count <= cfg.warm_windows || nnz(keep) < cfg.min_bins
    return
end
S = 1 - T(keep);
T = T(keep);
st = sqrt(abs(S).^2 + abs(T).^2);
st_hi = prctile(st, cfg.st_prctile);
[~, idx] = min(abs(st - st_hi));
freq = cfg.freq_hz(keep);
freq_hz = freq(idx);
ncf = 1/(sqrt(2)*max(st_hi, eps));
if ncf < cfg.nominal
    ncf = cfg.nominal*(ncf/cfg.nominal)^cfg.st_power;
end
ncf = min(cfg.cap, ncf);
end

function seeds = seedStruct(cfg, T, gamma2, pin, residual, ratio)
seeds = struct('freq_hz', cfg.freq_hz, 'T_hat', T, ...
    'coherence', gamma2, 'input_power_db', pin, ...
    'residual_power', residual, 'residual_ratio', ratio);
end
