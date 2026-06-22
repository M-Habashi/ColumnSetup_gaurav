clear; clc

%% Units
% Source/output raw channels: t [s], dd/dc/dm [mm], fm [N], am [g].
% Force multipliers are dimensionless and force_offset is [N].

% Build a play-data file from one saved physical run.
% The displacement/velocity/acceleration channels are kept unchanged, while
% the force channel is modified in five equal time blocks. Some blocks use a
% reduced force multiplier while the force center moves linearly between zero
% and 40% of the original maximum force. This separates force level from local
% force slope: absolute/windowed LSE should lean toward secant stiffness,
% while the incremental/demeaned window estimator should better recover the
% local tangent stiffness. The final block is replaced by measured force
% noise from the end of the source run.

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(root));
addpath(fullfile(step_root, 'helpers', 'utils'))

[S, source_file, source_name] = load_saved_result_file(step_root, 'tests', true);
output_dir = fullfile(step_root, 'saved_results', 'tests', 'play');
if ~exist(output_dir, 'dir')
    mkdir(output_dir)
end
[~, source_name] = fileparts(source_name);
data_file = fullfile(output_dir, ['play_' source_name '.mat']);
time_window = [430 590];

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
force_offset = 0.40 * max(fm_raw);
force_center = interp1(linspace(1, n, 5), ...
    force_offset*[0 1 0 1 0], (1:n)', 'linear');
fm = fm_raw .* force_multiplier + force_center;
fm_noise = S.fm(noise_idx);
fm(end - n_part + 1:end) = fm_noise + force_center(end - n_part + 1:end);
am = S.am(idx);
dt = S.dt;
fs = S.fs;
source = source_file;
units = struct('t', 's', 't_abs', 's', 'dd', 'mm', 'dc', 'mm', ...
    'dm', 'mm', 'fm', 'N', 'fm_raw', 'N', 'fm_noise', 'N', ...
    'am', 'g', 'force_multiplier', 'dimensionless', 'force_offset', 'N', ...
    'force_center', 'N');

save(data_file, 't', 't_abs', 'dd', 'dc', 'dm', 'fm', 'fm_raw', 'fm_noise', 'am', ...
    'dt', 'fs', 'time_window', 'force_multiplier', 'force_offset', ...
    'force_center', 'source', 'units')
fprintf('Saved %s (%d samples, %.3f s)\\n', data_file, numel(t), t(end));
