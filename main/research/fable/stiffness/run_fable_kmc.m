root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(fileparts(root)));
addpath(fullfile(step_root, 'helpers', 'utils'));
addpath(root);

[S, data_file] = load_saved_result_file(step_root, 'tests', true);
t = S.t(:);
x = S.dm(:)/1000;   % m
F = S.fm(:);        % N
fs = S.fs;          % Hz

cfg = fable_kmc_config();

fig = figure('Name', 'fable k/m/c spectral tracker', ...
    'Color', 'w', 'Position', [60 40 1280 940]);

names1 = {'seg_s', 'hop_s', 'mem_s', 'noise_s', ...
    'band_lo', 'band_hi', 'coh_min', 'snr_min_db'};
labels1 = {'seg_s', 'hop_s', 'mem_s', 'noise_s', ...
    'band lo [Hz]', 'band hi [Hz]', 'coh_min', 'snr_min_db'};
vals1 = [cfg.seg_s cfg.hop_s cfg.mem_s cfg.noise_s ...
    cfg.band_hz(1) cfg.band_hz(2) cfg.coh_min cfg.snr_min_db];

names2 = {'guard_frac', 'prior_m', 'prior_c', 'prior_k', ...
    'prior_h0', 'adapt_ratio', 'smooth_s'};
labels2 = {'guard_frac', 'prior m', 'prior c', 'prior k', ...
    'prior h0', 'adapt_ratio', 'smooth_s'};
vals2 = [cfg.guard_frac cfg.prior_rel(:).' cfg.adapt_ratio cfg.smooth_s];

edits = gobjects(1, numel(names1) + numel(names2));
edit_names = [names1 names2];

y1 = 900; y2 = 866; h = 22;
for i = 1:numel(names1)
    x0 = 16 + (i - 1)*153;
    uicontrol(fig, 'Style', 'text', 'String', labels1{i}, ...
        'HorizontalAlignment', 'right', 'BackgroundColor', 'w', ...
        'Position', [x0 y1 84 h]);
    edits(i) = uicontrol(fig, 'Style', 'edit', ...
        'String', sprintf('%.6g', vals1(i)), ...
        'BackgroundColor', 'w', 'Position', [x0 + 88 y1 54 h]);
end

for i = 1:numel(names2)
    x0 = 16 + (i - 1)*125;
    uicontrol(fig, 'Style', 'text', 'String', labels2{i}, ...
        'HorizontalAlignment', 'right', 'BackgroundColor', 'w', ...
        'Position', [x0 y2 76 h]);
    edits(numel(names1) + i) = uicontrol(fig, 'Style', 'edit', ...
        'String', sprintf('%.6g', vals2(i)), ...
        'BackgroundColor', 'w', 'Position', [x0 + 80 y2 54 h]);
end

status_txt = uicontrol(fig, 'Style', 'text', 'String', '', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [1022 y2 238 h]);
calc_btn = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Calculate', ...
    'Position', [920 y2 90 h]);

tl = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
tl.Units = 'pixels';
tl.Position = [70 50 1160 790];
axs = gobjects(5, 1);
for i = 1:5
    axs(i) = nexttile(tl);
end

cb = @(src, evt) calculate_fable(edits, edit_names, status_txt, axs, ...
    t, x, F, fs, cfg, data_file);
for i = 1:numel(edits)
    edits(i).Callback = cb;
end
calc_btn.Callback = cb;

cb([], []);

function calculate_fable(edits, edit_names, status_txt, axs, t, x, F, fs, cfg, data_file)
vals = nan(size(edits));
for i = 1:numel(edits)
    vals(i) = str2double(edits(i).String);
end

if any(~isfinite(vals)) || bad_inputs(vals, fs)
    status_txt.String = 'bad input';
    return
end

for i = 1:numel(edit_names)
    switch edit_names{i}
        case 'band_lo'
            cfg.band_hz(1) = vals(i);
        case 'band_hi'
            cfg.band_hz(2) = vals(i);
        case 'prior_m'
            cfg.prior_rel(1) = vals(i);
        case 'prior_c'
            cfg.prior_rel(2) = vals(i);
        case 'prior_k'
            cfg.prior_rel(3) = vals(i);
        case 'prior_h0'
            cfg.prior_rel(4) = vals(i);
        otherwise
            cfg.(edit_names{i}) = vals(i);
    end
end

status_txt.String = 'Calculating...';
drawnow
tic
out = fable_kmc(x, F, fs, cfg);
elapsed = toc;

draw_fable(axs, t, x, F, out, data_file, cfg);
n = numel(out.t);
track_pct = 100*nnz(out.status == 1)/max(n, 1);
hold_pct = 100*nnz(out.status == 2)/max(n, 1);
status_txt.String = sprintf('%d hops, track %.0f%%, hold %.0f%%, %d adapts (%.2f s)', ...
    n, track_pct, hold_pct, nnz(out.adapted), elapsed);
end

function tf = bad_inputs(v, fs)
tf = ~(v(1) > 0 && v(2) > 0 && v(3) > 0 && v(4) >= 0 && ...
    v(5) > 0 && v(6) > v(5) && v(6) < fs/2 && ...
    v(7) >= 0 && v(7) <= 1 && isfinite(v(8)) && ...
    v(9) >= 0 && v(9) < 1 && all(v(10:13) > 0) && ...
    v(14) > 0 && v(15) >= 0);
end

function draw_fable(axs, t, x, F, out, data_file, cfg)
blue = '#2a78d6';
force_purple = '#74058A';
green = '#1baf7a';
damp_purple = '#4a3aa7';
hold_orange = '#eda100';
adapt_red = '#e34948';
grid_color = '#e1e0d9';
axis_color = '#52514e';

for i = 1:numel(axs)
    cla(axs(i));
end

[~, base, ext] = fileparts(data_file);
plot(axs(1), t, x*1000, 'Color', blue);
ylabel(axs(1), 'x (mm)');
title(axs(1), sprintf('%s%s   mem %.3g s, band %.3g-%.3g Hz', ...
    base, ext, cfg.mem_s, cfg.band_hz(1), cfg.band_hz(2)), ...
    'Interpreter', 'none');

plot(axs(2), t, F, 'Color', force_purple);
ylabel(axs(2), 'F (N)');

tt = out.t(:);
status = out.status(:);
k = out.theta(:, 3)/1e6;
sk = out.sigma(:, 3)/1e6;
shade_band(axs(3), tt, k - 1.96*sk, k + 1.96*sk, [0.55 0.75 0.95]);
hold(axs(3), 'on');
plot(axs(3), tt, k, 'Color', blue, 'LineWidth', 1.6);
plot(axs(3), tt, out.k_direct(:)/1e6, '.', ...
    'Color', [0.65 0.65 0.65], 'MarkerSize', 6);
k_hold = k;
k_hold(status ~= 2) = NaN;
plot(axs(3), tt, k_hold, 'Color', hold_orange, 'LineWidth', 1.8);
add_adapt_lines(axs(3), tt, out.adapted(:), adapt_red);
ylabel(axs(3), 'k (MN/m)');
ylim(axs(3), robust_ylim([k - 1.96*sk; k + 1.96*sk]));

m = out.theta(:, 1);
sm = out.sigma(:, 1);
shade_band(axs(4), tt, m - 1.96*sm, m + 1.96*sm, [0.55 0.82 0.70]);
hold(axs(4), 'on');
plot(axs(4), tt, m, 'Color', green, 'LineWidth', 1.6);
ylabel(axs(4), 'm (kg)');
ylim(axs(4), robust_ylim([m - 1.96*sm; m + 1.96*sm]));

c = out.theta(:, 2);
sc = out.sigma(:, 2);
shade_band(axs(5), tt, c - 1.96*sc, c + 1.96*sc, [0.70 0.66 0.88]);
hold(axs(5), 'on');
plot(axs(5), tt, c, 'Color', damp_purple, 'LineWidth', 1.4);
ylabel(axs(5), 'c (N s/m)');
xlabel(axs(5), 'Time (s)');
tracking = status == 1;
title(axs(5), sprintf('median eta = %.3f (h0 median %.3g N/m)', ...
    finite_median(out.eta(tracking)), finite_median(out.theta(tracking, 4))));

for i = 1:numel(axs)
    grid(axs(i), 'on');
    axs(i).GridColor = grid_color;
    axs(i).XColor = axis_color;
    axs(i).YColor = axis_color;
    axs(i).FontSize = 10;
end
linkaxes(axs, 'x');
xlim(axs(1), [0 t(end)]);
end

function shade_band(ax, tt, lo, hi, rgb)
good = isfinite(tt) & isfinite(lo) & isfinite(hi);
d = diff([false; good; false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
hold(ax, 'on');
for i = 1:numel(starts)
    idx = starts(i):stops(i);
    fill(ax, [tt(idx); flipud(tt(idx))], [lo(idx); flipud(hi(idx))], rgb, ...
        'FaceAlpha', 0.25, 'EdgeColor', 'none');
end
end

function add_adapt_lines(ax, tt, adapted, color)
adapt_t = tt(adapted(:) & isfinite(tt));
for i = 1:numel(adapt_t)
    xline(ax, adapt_t(i), '--', 'Color', color);
end
end

function yl = robust_ylim(v)
v = v(isfinite(v));
if isempty(v)
    yl = [0 1];
    return
end
lo = pct(v, 1);
hi = pct(v, 99);
if lo == hi
    pad = max(1, 0.08*abs(lo));
else
    pad = 0.08*(hi - lo);
end
yl = [lo - pad hi + pad];
end

function y = pct(v, p)
v = sort(v(:));
q = 1 + (numel(v) - 1)*p/100;
lo = floor(q);
hi = ceil(q);
if lo == hi
    y = v(lo);
else
    y = v(lo) + (q - lo)*(v(hi) - v(lo));
end
end

function y = finite_median(v)
v = v(isfinite(v));
if isempty(v)
    y = NaN;
else
    y = median(v);
end
end
