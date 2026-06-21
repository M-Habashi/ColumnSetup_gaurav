clear; clc

%% Units
% Source/output raw channels: t [s], dd/dc/dm [mm], fm [N], am [g].
% Force multipliers are dimensionless and force_offset is [N].

% Build a play-data file from one saved physical run.
% The displacement/velocity/acceleration channels are kept unchanged, while
% the force channel is modified in five equal time blocks. Some blocks use a
% reduced force multiplier and receive a constant offset equal to 40% of the
% original maximum force. This intentionally separates force level from local
% force slope: absolute/windowed LSE should lean toward secant stiffness,
% while the incremental/demeaned window estimator should better recover the
% local tangent stiffness. The final block is replaced by measured force
% noise from the end of the source run.

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(root));

source_file = fullfile(step_root, 'saved_results', 'tests', ...
    'sp_1_ori_P30_i0_Pd015_Id_20_Dd_0015', ...
    '20260615_1823_sp_1_ori_P30_I0.mat');
data_file = fullfile(root, 'data', 'sp_1_ori_P30_I0_t430_590.mat');
time_window = [430 590];

S = load(source_file);
idx = S.t >= time_window(1) & S.t <= time_window(2);

n = nnz(idx);
n_part = floor(n / 5);
n = 5 * n_part;
idx = find(idx, n, 'first');
noise_idx = (numel(S.fm) - n_part + 1):numel(S.fm);

t_abs = S.t(idx);
t = t_abs - t_abs(1);
dd = S.dd(idx);
dc = S.dc(idx);
dm = S.dm(idx);
fm_raw = S.fm(idx);
force_multiplier = repelem([1; 0.5; 1; 0.25; 0], n_part);
fm = fm_raw .* force_multiplier;
force_offset = 0.40 * max(fm_raw);
force_offset_idx = force_multiplier > 0 & force_multiplier < 1;
fm(force_offset_idx) = fm(force_offset_idx) + force_offset;
fm_noise = S.fm(noise_idx);
fm(end - n_part + 1:end) = fm_noise;
am = S.am(idx);
dt = S.dt;
fs = S.fs;
source = source_file;
units = struct('t', 's', 't_abs', 's', 'dd', 'mm', 'dc', 'mm', ...
    'dm', 'mm', 'fm', 'N', 'fm_raw', 'N', 'fm_noise', 'N', ...
    'am', 'g', 'force_multiplier', 'dimensionless', 'force_offset', 'N');

save(data_file, 't', 't_abs', 'dd', 'dc', 'dm', 'fm', 'fm_raw', 'fm_noise', 'am', ...
    'dt', 'fs', 'time_window', 'force_multiplier', 'force_offset', ...
    'force_offset_idx', 'source', 'units')
fprintf('Saved %s (%d samples, %.3f s)\\n', data_file, numel(t), t(end));
