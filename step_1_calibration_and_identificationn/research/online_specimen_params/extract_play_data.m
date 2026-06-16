clear; clc

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
fm_noise = S.fm(noise_idx);
fm(end - n_part + 1:end) = fm_noise;
am = S.am(idx);
dt = S.dt;
fs = S.fs;
source = source_file;

save(data_file, 't', 't_abs', 'dd', 'dc', 'dm', 'fm', 'fm_raw', 'fm_noise', 'am', ...
    'dt', 'fs', 'time_window', 'force_multiplier', 'source')
fprintf('Saved %s (%d samples, %.3f s)\\n', data_file, numel(t), t(end));
