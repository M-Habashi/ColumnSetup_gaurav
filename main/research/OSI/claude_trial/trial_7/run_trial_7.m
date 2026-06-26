%% Trial 7 -- Method 7: Output-only closed-loop resonance / sensitivity-peak NCF
% Catches the 35 Hz instability from the response dm ALONE, so it works even when
% the input does not excite 35 Hz (the 1749 low-frequency-input case, where the
% open-loop FRF at 35 Hz is a tautology and Methods 1-6 are blind to it). The
% closed-loop resonance amplification ~ ||S||_inf is mapped to the loop-only NCF,
% calibrated to the model's nominal margin at the start. See
% common/osi_method7_resonance.m. Output: NCF-margin time series, both data files.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

t0 = tic;
m7 = osi_method7_resonance(ctx, cfg);
runtime = toc(t0);

result = struct('tag', 'trial_7', ...
    'method', sprintf('Method 7 - Output resonance / sensitivity-peak (%.0fs buf)', cfg.m7_buf), ...
    'tc', m7.tc, 'ncf', m7.ncf, 'nominal', m7.nominal, 'threshold', m7.threshold, ...
    'runtime', runtime, 'detect_time', m7.detect_time);
osi_report_series(result, cfg);
fprintf('binding nominal NCF=%.3f | Spk_ref=%.2f | detect=%.1f s\n', ...
    m7.nominal, m7.Sref, m7.detect_time);
