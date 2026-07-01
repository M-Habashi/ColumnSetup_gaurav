function [margin, state, info] = m91_step_from_spectra( ...
        T, gamma2, pin, residual, cfg, state)
%M91_STEP_FROM_SPECTRA Update M9.1 state from precomputed window spectra.
% Shared by the batch M9.1 step and the target runtime's time-sliced FFT.

%#codegen

state.window_count = state.window_count + 1;

if ~state.ready
    state.cal_count = state.cal_count + 1;
    state.residual_cal(:, state.cal_count) = residual;
    if state.cal_count >= cfg.calibration_windows
        [state.residual_baseline, state.q_ref] = ...
            residualReference(residual, state.residual_cal, cfg);
        state.ready = true;
    end
    margin = cfg.nominal;
    info = infoStruct(cfg, state, margin, cfg.cap, cfg.nominal, ...
        NaN, NaN, cfg.nominal_hz, 0, nnz(cfg.freq_keep));
    return
end

excited = pin >= branchPowerReference(pin, cfg) ...
    - cfg.input_power_range_db;
keep_st = excited & gamma2 >= cfg.gamma_min & cfg.st_freq_keep;
ratio = residual./state.residual_baseline;
ratio(~cfg.residual_freq_keep | ratio <= 0) = NaN;
ratio = osi_moving_median(ratio, cfg.freq_medfilt_n);

[ncf_res, f_res] = residualBranch(ratio, ...
    cfg.residual_freq_keep & ~keep_st, cfg, state.q_ref);
[ncf_res_early, f_res_early] = residualBranch(ratio, ...
    cfg.residual_freq_keep, cfg, state.q_ref);
[ncf_st, f_st] = stBranch(T, keep_st, cfg, state.window_count);

if cfg.residual_early_all_bins && isfinite(f_st) ...
        && ncf_st > cfg.residual_early_st_gate_frac*cfg.nominal ...
        && ncf_st < cfg.nominal ...
        && abs(f_st - f_res_early) <= cfg.residual_early_match_hz
    ncf_res = min(ncf_res, max(ncf_res_early, ...
        cfg.residual_early_st_floor_frac*ncf_st));
    f_res = f_res_early;
end

branch_margin = combineBranches(ncf_st, ncf_res, nnz(keep_st), cfg, state);
state.margin_history = [state.margin_history(2:end); branch_margin];
margin = osi_prctile_finite(state.margin_history, 50);
if state.window_count <= cfg.warm_windows
    margin = cfg.nominal;
end

below = margin < cfg.threshold;
state.below_history = [state.below_history(2:end); below];
if ~state.detected && nnz(state.below_history) >= cfg.detect_consecutive
    state.detected = true;
    state.detect_window = state.window_count;
end

info = infoStruct(cfg, state, margin, ncf_st, ncf_res, ...
    f_st, f_res, f_res_early, nnz(keep_st), ...
    nnz(cfg.residual_freq_keep & ~keep_st));
end

function power_db = branchPowerReference(pin, cfg)
if any(cfg.st_freq_keep)
    power_db = max(pin(cfg.st_freq_keep));
else
    power_db = max(pin(cfg.freq_keep));
end
end

function branch_margin = combineBranches(ncf_st, ncf_res, n_excited, ...
        cfg, state)
if cfg.use_residual_branch
    branch_margin = min(ncf_st, ncf_res);
elseif n_excited >= cfg.min_bins && isfinite(ncf_st)
    branch_margin = ncf_st;
else
    branch_margin = state.margin_history(end);
    if ~isfinite(branch_margin)
        branch_margin = cfg.nominal;
    end
end
end

function [baseline, q_ref] = residualReference(residual, residual_cal, cfg)
if coder.target('MATLAB')
    baseline = median(residual_cal, 2, 'omitnan');
    baseline = max(baseline, median(baseline, 'omitnan')*1e-6);
    ratio_cal = bsxfun(@rdivide, residual_cal, baseline);
    ratio_cal(~cfg.residual_freq_keep, :) = NaN;
    for k = 1:size(ratio_cal, 2)
        ratio_cal(:, k) = osi_moving_median(ratio_cal(:, k), ...
            cfg.freq_medfilt_n);
    end
    q_ref = median(prctile(ratio_cal, cfg.residual_prctile, 1), 'omitnan');
else
    baseline = sum(residual_cal, 2)/cfg.calibration_windows;
    q_ref = 1;
end
if ~isfinite(q_ref) || q_ref <= 0
    q_ref = 1;
end

if any(~isfinite(baseline))
    if coder.target('MATLAB')
        fallback = median(residual(isfinite(residual) & residual > 0), ...
            'omitnan');
    else
        finite_residual = residual(isfinite(residual) & residual > 0);
        if isempty(finite_residual)
            fallback = 1;
        else
            fallback = sum(finite_residual)/numel(finite_residual);
        end
    end
    if ~isfinite(fallback) || fallback <= 0
        fallback = 1;
    end
    baseline(~isfinite(baseline)) = fallback;
end
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
ncf0 = cfg.nominal_curve(idx);
ncf = min(cfg.cap, ncf0*sqrt(q_ref/max(q_now, q_ref)));
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

function info = infoStruct(cfg, state, margin, ncf_st, ncf_res, ...
        f_st, f_res, f_res_early, n_excited, n_quiet)
info = struct('margin', margin, 'ncf_st', ncf_st, ...
    'ncf_residual', ncf_res, 'f_st_hz', f_st, ...
    'f_residual_hz', f_res, 'f_residual_early_hz', f_res_early, ...
    'n_excited', n_excited, 'n_quiet', n_quiet, ...
    'nominal', cfg.nominal, 'threshold', cfg.threshold, ...
    'q_ref', state.q_ref, 'baseline_ready', state.ready, ...
    'detected', state.detected, 'detect_window', state.detect_window);
end
