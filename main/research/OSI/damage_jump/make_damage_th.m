%% MAKE_DAMAGE_TH  Synthetic OSI test record: healthy -> damaged H_dc_dm jump
% Builds a 20 s closed-loop displacement record for testing the online stability
% indicators. The actuator loop tracks a recorded low-band reference while a
% broadband internal disturbance excites the binding ~35 Hz resonance from inside
% the loop. The plant H_dc_dm is the HEALTHY model for the first 10 s and the
% DAMAGED model for the last 10 s; the PID, the phase_lead and the FEM/reference
% are identical in both halves, so the only thing that changes at t = 10 s is the
% specimen damage (k:7.2e6->5.4e6 N/m), exactly as in vHS.m.
%
% Loop (per vHS hybridResponseWithPidHdcDm signal path), output-disturbance form:
%   dd      : recorded numerical-substructure reference (low band, from 1749)
%   dd_lead : phase_lead(dd)                              (G_T, same both halves)
%   dm      = T*dd_lead + S*d   with   T = C*H/(1+C*H),  S = 1/(1+C*H)
%   dc      = PID*(dd_lead - dm)
% where d is broadband output disturbance (sensor/process noise + nonlinearity),
% the channel through which the closed-loop sensitivity peak ||S||_inf shows up in
% dm ALONE -- the quantity Method 7 reads. Damage raises ||S||_inf 1.19 -> 1.86
% (loop-only NCF 0.588 -> 0.344, i.e. it crosses the 0.40 threshold).
%
% Units: displacements dm/dc/dd [mm], force fm [N], time [s], k [N/m].
% Output: data/damage_th.mat (t, dd, dd_lead, dc, dm, fm, fs, dt, switch_time,
% and a meta struct documenting every source file and parameter).

clearvars; clc; close all;

this_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(this_dir)));  % .../main (research/OSI/damage_jump -> main)
sr = fullfile(project_main, 'saved_results');

%% ---- configuration ----------------------------------------------------------
cfg.fs          = 2048;                 % Hz, hybrid sample rate (= 1/hs_sample_dt)
cfg.duration_s  = 20;                   % total record length
cfg.switch_s    = 10;                   % healthy -> damaged jump time
cfg.warmup_s    = 3;                    % discarded loop start-up (kills lsim transient)
cfg.ref_window_start_s = 100;           % start of the 20 s slice taken from the 1749 reference
cfg.disturbance_seed   = 7;             % rng seed for the broadband disturbance
cfg.disturbance_std    = [];            % [] -> use the model's identified source_noise_std
cfg.crossfade_s        = 0.1;           % raised-cosine blend at the jump (removes the splice step)

healthy_tf_file = fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat');  % healthy H_dc_dm
damaged_tf_file = fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat');   % damaged H_dc_dm
phase_lead_file = fullfile(sr, 'phase_lead', 'pl_sp1_5000.mat');               % kept same both halves
ref_record_file = fullfile(sr, 'tests', 'important', ...
    '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat');       % low-band input
healthy_specimen_file = fullfile(sr, 'specimens', 'sp1_7000.mat');            % k for force (0-10 s)
damaged_specimen_file = fullfile(sr, 'specimens', 'sp1_5000.mat');            % k for force (10-20 s)

%% ---- load models ------------------------------------------------------------
Hh_data = load(healthy_tf_file);
Hd_data = load(damaged_tf_file);
PL      = load(phase_lead_file);
S7      = load(healthy_specimen_file);
S5      = load(damaged_specimen_file);

dt = 1/cfg.fs;
pv = Hh_data.pid_values;                                  % PID identical in both halves
C  = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = Hh_data.models.H_dc_dm_d;                            % healthy discrete plant (Ts = dt)
Hd = Hd_data.models.H_dc_dm_d;                            % damaged discrete plant (Ts = dt)
GT = c2d(PL.phase_lead_tf, dt, 'tustin');                % phase_lead, discrete

% closed-loop tracking (T) and sensitivity (S) for each plant
Th = feedback(C*Hh, 1);  Sh = feedback(1, C*Hh);
Td = feedback(C*Hd, 1);  Sd = feedback(1, C*Hd);

if isempty(cfg.disturbance_std)
    cfg.disturbance_std = Hh_data.source_noise_std;       % identified disturbance level (~0.069 mm)
end

%% ---- reference input: any 20 s of the low-band (1749) record ----------------
ref = load(ref_record_file);
t_ref = ref.result.t;
i0 = find(t_ref >= cfg.ref_window_start_s - cfg.warmup_s, 1);
N_total = round((cfg.duration_s + cfg.warmup_s)*cfg.fs) + 1;
assert(i0 + N_total - 1 <= numel(ref.result.dd), 'Reference window exceeds the 1749 record.');
dd_src = ref.result.dd(i0:i0+N_total-1);
dd_src = dd_src - mean(dd_src);                           % drive about zero
t_src  = (0:N_total-1).'/cfg.fs;

%% ---- simulate both closed loops over the full (warm-up + record) span --------
dd_lead_src = lsim(GT, dd_src, t_src);
rng(cfg.disturbance_seed);
d_src = cfg.disturbance_std*randn(N_total, 1);            % broadband output disturbance

dm_healthy = lsim(Th, dd_lead_src, t_src) + lsim(Sh, d_src, t_src);
dm_damaged = lsim(Td, dd_lead_src, t_src) + lsim(Sd, d_src, t_src);

%% ---- discard warm-up, splice healthy | damaged at the switch time -----------
keep = t_src >= cfg.warmup_s - 1e-9;                      % drop the start-up transient
t  = t_src(keep) - cfg.warmup_s;                          % relabel so the record starts at 0
dd      = dd_src(keep);
dd_lead = dd_lead_src(keep);
dm_h = dm_healthy(keep);
dm_d = dm_damaged(keep);

% raised-cosine crossfade healthy->damaged so the state is continuous at the jump
w = double(t >= cfg.switch_s);                            % 0 = healthy, 1 = damaged weight
ramp = abs(t - cfg.switch_s) <= cfg.crossfade_s/2;
w(ramp) = 0.5*(1 + sin(pi*(t(ramp) - cfg.switch_s)/cfg.crossfade_s));
dm = (1 - w).*dm_h + w.*dm_d;
is_damaged = t >= cfg.switch_s;                           % half labels for the summary stats

% rebuild the consistent command from the spliced response: dc = PID*(dd_lead-dm)
dc = lsim(C, dd_lead - dm, t);
k_mm = ((1 - w)*S7.k + w*S5.k)/1000;                     % N/mm, specimen k also 7000->5000
fm = k_mm.*dm;                                            % measured force [N]

%% ---- save -------------------------------------------------------------------
meta = struct( ...
    'description', 'Synthetic OSI record: healthy H_dc_dm (0-10 s) then damaged H_dc_dm (10-20 s).', ...
    'healthy_tf_file', healthy_tf_file, 'damaged_tf_file', damaged_tf_file, ...
    'phase_lead_file', phase_lead_file, 'reference_record_file', ref_record_file, ...
    'healthy_specimen_file', healthy_specimen_file, 'damaged_specimen_file', damaged_specimen_file, ...
    'k_healthy', S7.k, 'k_damaged', S5.k, ...
    'pid_values', pv, 'cfg', cfg, ...
    'inner_ncf_healthy', osi_inner_ncf(C, Hh), 'inner_ncf_damaged', osi_inner_ncf(C, Hd), ...
    'raw_jump_mm', dm_d(find(is_damaged,1)) - dm_h(find(is_damaged,1)-1));  % step removed by the crossfade

out_dir = fullfile(this_dir, 'data');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fs = cfg.fs; switch_time = cfg.switch_s;
save(fullfile(out_dir, 'damage_th.mat'), ...
    't', 'dd', 'dd_lead', 'dc', 'dm', 'fm', 'fs', 'dt', 'switch_time', 'meta');

fprintf('Saved %s\n', fullfile(out_dir, 'damage_th.mat'));
fprintf('Inner loop-only NCF: healthy=%.3f  damaged=%.3f  (threshold 0.40)\n', ...
    meta.inner_ncf_healthy, meta.inner_ncf_damaged);
fprintf('dm rms: healthy half=%.4f mm, damaged half=%.4f mm\n', ...
    rms(dm(~is_damaged)), rms(dm(is_damaged)));
fprintf('Raw jump smoothed by crossfade: %.4f mm over %.0f ms\n', ...
    meta.raw_jump_mm, 1000*cfg.crossfade_s);

%% ---- quick look -------------------------------------------------------------
figure('Color', 'w', 'Name', 'damage_th record', 'Position', [80 80 900 520]);
tl = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile;
plot(ax1, t, dm, 'Color', [0.20 0.30 0.55]); hold(ax1, 'on');
plot(ax1, t, dd, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.0);
xline(ax1, cfg.switch_s, '--', 'damage', 'Color', [0.6 0 0]);
grid(ax1, 'on'); ylabel(ax1, 'mm'); legend(ax1, {'dm (measured)', 'dd (reference)'}, 'Location', 'best');
title(tl, 'Synthetic healthy \rightarrow damaged H_{dc,dm} record (low-band input)');

ax2 = nexttile;                                          % spectrogram shows the resonance growing
[~, fS, tS, ps] = spectrogram(detrend(dm), hann(round(2*fs)), round(1.5*fs), 4096, fs);
band = fS >= 10 & fS <= 70;
imagesc(ax2, tS, fS(band), 10*log10(ps(band, :))); axis(ax2, 'xy');
hold(ax2, 'on'); xline(ax2, cfg.switch_s, '--w', 'damage');
ylabel(ax2, 'Hz'); xlabel(ax2, 'time (s)'); title(ax2, 'dm spectrogram (dB)'); colorbar(ax2);
saveas(gcf, fullfile(out_dir, 'damage_th_record.png'));

function b = osi_inner_ncf(C, H)
% Loop-only NCF of the inner actuator loop C*H over the binding band [1,58] Hz.
    f = logspace(0, log10(58), 3000).';
    L = squeeze(freqresp(C*H, 2*pi*f));
    b = min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
end
