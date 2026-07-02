clear; clc

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(fileparts(root)));
addpath(fullfile(step_root,'research','specimen_mode','methods'));
addpath(root);

resdir = fullfile(root,'results');
if ~exist(resdir,'dir')
    mkdir(resdir);
end

recs = make_records(step_root);
RES = repmat(struct(),0,1);
ref_noise_scale = [];
ref_noiseD = [];

for ir = 1:numel(recs)
    rec_tic = tic;
    rec = recs(ir);
    fprintf('\n=== %s ===\n', rec.name);
    R = load_record(rec);

    fprintf('filter signals... ');
    mtic = tic;
    [xf, vf, af, Ff] = filtered_regression_signals(R.x, R.F, R.dt, 30);
    fprintf('%.1f s\n', toc(mtic));

    noise_idx = R.t <= R.t(1) + 2;
    noise_scale = calc_noise_scale(af, vf, xf, Ff, noise_idx);
    noiseD = make_D(R.t, af, vf, xf, Ff, noise_idx, R.fs, R.dt);
    if ir == 2
        ref_noise_scale = noise_scale;
        ref_noiseD = noiseD;
    end

    methods = struct();

    mtic = tic;
    methods.asflown = method_asflown(R);
    if isempty(methods.asflown.t)
        fprintf('method asflown skipped %.1f s\n', toc(mtic));
        methods = rmfield(methods,'asflown');
    else
        fprintf('method asflown done %.1f s\n', toc(mtic));
    end

    mtic = tic;
    if ir == 4
        if isempty(ref_noise_scale)
            [ref_noise_scale, ref_noiseD] = record_noise_reference(recs(2));
        end
        wtls_noise = ref_noise_scale;
        keep = true(size(R.t));
    else
        wtls_noise = noise_scale;
        keep = ~noise_idx;
    end
    methods.wtls = method_wtls(R.t, af, vf, xf, Ff, wtls_noise, keep);
    fprintf('method wtls done %.1f s\n', toc(mtic));

    mtic = tic;
    methods.wlse = method_wlse(R.t, af, vf, xf, Ff);
    fprintf('method wlse done %.1f s\n', toc(mtic));

    mtic = tic;
    methods.fable = method_fable(R, ir == 4);
    fprintf('method fable done %.1f s\n', toc(mtic));

    mtic = tic;
    trim_idx = R.t >= rec.trim(1) & R.t <= rec.trim(2);
    if ~any(trim_idx)
        warning('Trim window has no samples for %s.', rec.name);
    end
    D = make_D(R.t, af, vf, xf, Ff, trim_idx, R.fs, R.dt);
    if ir == 4 && ~isempty(ref_noiseD)
        batch_noiseD = ref_noiseD;
    else
        batch_noiseD = noiseD;
    end
    batch = compute_batch_fits(D, batch_noiseD);
    k_anchor = anchor_stiffness(R.t, R.x, R.F, R.fs, rec.trim);
    fprintf('batch/anchor done %.1f s\n', toc(mtic));

    metrics = compute_metrics(methods, rec.trim, k_anchor);
    print_metrics(rec, k_anchor, metrics);

    blocks = [];
    if ir == 4
        blocks = compute_blocks(methods);
        print_blocks(blocks);
    end

    RES(ir).name = rec.name;
    RES(ir).trim = rec.trim;
    RES(ir).k_anchor = k_anchor;
    RES(ir).official_k = rec.official_k;
    RES(ir).methods = methods;
    RES(ir).batch = batch;
    RES(ir).metrics = metrics;
    RES(ir).blocks = blocks;
    fprintf('record total %.1f s\n', toc(rec_tic));
end

save(fullfile(resdir,'compare_results.mat'), 'RES');
write_json_export(fullfile(resdir,'compare_results.js'), RES);
fprintf('\nSaved %s\n', fullfile(resdir,'compare_results.mat'));
fprintf('Saved %s\n', fullfile(resdir,'compare_results.js'));

function recs = make_records(step_root)
imp = fullfile(step_root,'saved_results','tests','important');
recs(1) = struct('name','1708 healthy', ...
    'file',fullfile(imp,'20260617_1708_sp1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    'format','result','trim',[202 329],'official_k',7.2006e6);
recs(2) = struct('name','1623 healthy long', ...
    'file',fullfile(imp,'20260617_1623_sp1_ori_P30_I0_D0001_Po_015_Io_20_Do_00015.mat'), ...
    'format','result','trim',[250 700],'official_k',7.2006e6);
recs(3) = struct('name','1838 damaged', ...
    'file',fullfile(imp,'20260626_1838_sp1_dmg_P30_I30_Po_015_IO_20_DO_00015.mat'), ...
    'format','flat','trim',[88 185],'official_k',5.3808e6);
recs(4) = struct('name','play force-block stress test', ...
    'file',fullfile(step_root,'research','online_specimen_params','data','sp_1_ori_P30_I0_t430_590.mat'), ...
    'format','flat','trim',[4 32],'official_k',7.2006e6);
end

function R = load_record(rec)
S = load(rec.file);
if strcmp(rec.format,'result') && isfield(S,'result')
    r = S.result;
else
    r = S;
end
R.t = r.t(:);
R.x = r.dm(:) / 1000; % m
R.F = r.fm(:); % N
if isfield(r,'fs') && ~isempty(r.fs)
    R.fs = double(r.fs(1));
else
    R.fs = 1 / median(diff(R.t));
end
if isfield(r,'dt') && ~isempty(r.dt)
    R.dt = double(r.dt(1));
else
    R.dt = 1 / R.fs;
end
n = min([numel(R.t), numel(R.x), numel(R.F)]);
R.t = R.t(1:n); R.x = R.x(1:n); R.F = R.F(1:n);
R.k_hat = get_optional(r,'k_hat',n);
R.m_hat = get_optional(r,'m_hat',n);
R.c_hat = get_optional(r,'c_hat',n);
end

function v = get_optional(r, name, n)
if isfield(r,name) && ~isempty(r.(name))
    v = r.(name)(:);
    if numel(v) < n
        v(end+1:n,1) = NaN;
    else
        v = v(1:n);
    end
else
    v = [];
end
end

function s = calc_noise_scale(af, vf, xf, Ff, idx)
if ~any(idx)
    idx(1:min(2,numel(xf))) = true;
end
s = std([af(idx), vf(idx), xf(idx), Ff(idx)], 0, 1);
s(~isfinite(s) | s == 0) = 1;
end

function D = make_D(t, af, vf, xf, Ff, idx, fs, dt)
D = struct();
D.t = t(idx);
D.a = af(idx);
D.v = vf(idx);
D.x = xf(idx);
D.F = Ff(idx);
D.fs = fs;
D.dt = dt;
end

function M = method_asflown(R)
M = blank_method('Current online TSE (as flown)');
if isempty(R.k_hat)
    return
end
idx = (1:512:min([numel(R.t), numel(R.k_hat)]))';
k = R.k_hat(idx);
valid = k ~= 0 & isfinite(k);
if ~any(valid)
    return
end
M.t = R.t(idx);
M.k = k;
M.m = pick_logged(R.m_hat, idx);
M.c = pick_logged(R.c_hat, idx);
M.valid = valid;
end

function v = pick_logged(x, idx)
if isempty(x)
    v = NaN(size(idx));
else
    v = x(idx);
end
end

function M = method_wtls(t, af, vf, xf, Ff, noise_scale, keep)
M = blank_method('Whitened TLS + KF (official pending)');
est = windowed_noise_whitened_tls(t(keep), af(keep), vf(keep), xf(keep), Ff(keep), ...
    noise_scale, official_tls_config());
theta = est.theta_kf;
M.t = est.t(:);
M.m = theta(:,1);
M.c = theta(:,2);
M.k = theta(:,3);
M.valid = all(isfinite(theta),2);
end

function M = method_wlse(t, af, vf, xf, Ff)
M = blank_method('Windowed LSE');
n_win = 205;
stride = 64;
n = numel(t);
if n < n_win
    return
end
ends = (n_win:stride:n)';
starts = ends - n_win + 1;
X = [af(:), vf(:), xf(:)];
Y = Ff(:);
csX = [zeros(1,3); cumsum(X,1)];
csY = [0; cumsum(Y)];
csY2 = [0; cumsum(Y.^2)];
csXX = zeros(n+1,9);
csXY = zeros(n+1,3);
for j = 1:3
    for k = 1:3
        csXX(:,(j-1)*3+k) = [0; cumsum(X(:,j).*X(:,k))];
    end
    csXY(:,j) = [0; cumsum(X(:,j).*Y)];
end

theta = NaN(numel(ends),3);
prev = [NaN; NaN; NaN];
for iw = 1:numel(ends)
    a = starts(iw); b = ends(iw); w = n_win;
    sx = csX(b+1,:) - csX(a,:);
    sy = csY(b+1) - csY(a);
    sy2 = csY2(b+1) - csY2(a);
    rmsF = sqrt(max(sy2 - sy^2 / w, 0) / w); % N
    if rmsF > 20
        G = reshape(csXX(b+1,:) - csXX(a,:),3,3) - (sx(:) * sx(:)') / w;
        q = (csXY(b+1,:) - csXY(a,:))' - sx(:) * sy / w;
        th = pinv(G) * q;
        if all(isfinite(th))
            prev = th;
        end
    end
    theta(iw,:) = prev(:)';
end
M.t = t(ends);
M.m = theta(:,1);
M.c = theta(:,2);
M.k = theta(:,3);
M.valid = all(isfinite(theta),2);
end

function M = method_fable(R, is_play)
M = blank_method('fable spectral EIV (new)');
cfg = fable_kmc_config();
if is_play
    cfg.noise_s = 0;
end
out = fable_kmc(R.x, R.F, R.fs, cfg);
theta = out.theta(:,[1 2 3]);
M.t = out.t(:);
M.m = theta(:,1);
M.c = theta(:,2);
M.k = theta(:,3);
M.status = out.status(:);
M.valid = isfinite(M.k) & (M.status == 1 | M.status == 2);
M.k_direct = out.k_direct(:);
M.sigma_k = out.sigma(:,3);
M.adapted = logical(out.adapted(:));
if isfield(out,'z_change')
    M.z_change = out.z_change;
end
end

function M = blank_method(label)
M = struct('label',label,'t',[],'k',[],'m',[],'c',[],'valid',[]);
end

function [noise_scale, noiseD] = record_noise_reference(rec)
R = load_record(rec);
[xf, vf, af, Ff] = filtered_regression_signals(R.x, R.F, R.dt, 30);
idx = R.t <= R.t(1) + 2;
noise_scale = calc_noise_scale(af, vf, xf, Ff, idx);
noiseD = make_D(R.t, af, vf, xf, Ff, idx, R.fs, R.dt);
end

function batch = compute_batch_fits(D, noiseD)
batch = struct();
if isempty(D.t)
    batch.tse = struct('m',NaN,'c',NaN,'k',NaN);
    batch.lse = struct('m',NaN,'c',NaN,'k',NaN);
    return
end
batch.tse = normalize_fit(safe_call_fit(@estimate_tse, D, [], false));
batch.lse = normalize_fit(safe_call_fit(@estimate_lse, D, noiseD, true));
end

function out = safe_call_fit(fun, D, noiseD, prefer_empty)
try
    if prefer_empty
        out = fun(D, []);
    else
        out = fun(D, noiseD);
    end
catch
    try
        if prefer_empty
            out = fun(D, noiseD);
        else
            out = fun(D, []);
        end
    catch
        out = fun(D);
    end
end
end

function fit = normalize_fit(out)
fit = struct('m',NaN,'c',NaN,'k',NaN);
if isstruct(out)
    if all(isfield(out,{'m','c','k'}))
        fit.m = out.m; fit.c = out.c; fit.k = out.k;
    elseif isfield(out,'theta')
        th = out.theta(:);
        if numel(th) >= 3
            fit.m = th(1); fit.c = th(2); fit.k = th(3);
        end
    end
elseif isnumeric(out) && numel(out) >= 3
    th = out(:);
    fit.m = th(1); fit.c = th(2); fit.k = th(3);
end
end

function k_anchor = anchor_stiffness(t, x, F, fs, trim)
idx = t >= trim(1) & t <= trim(2);
if nnz(idx) < 16
    k_anchor = NaN;
    return
end
xw = detrend(x(idx));
Fw = detrend(F(idx));
nfft = 8192;
if numel(xw) < nfft
    nfft = 2^floor(log2(numel(xw)));
end
win = hann(nfft);
nov = nfft/2;
[pxx, fgrid] = pwelch(xw, win, nov, nfft, fs);
H1 = cpsd(xw, Fw, win, nov, nfft, fs) ./ pxx;
coh = mscohere(xw, Fw, win, nov, nfft, fs);
band = fgrid >= 1 & fgrid <= 8 & coh > 0.95;
if nnz(band) < 4
    band = fgrid >= 1 & fgrid <= 8 & coh > 0.85;
end
if nnz(band) < 1
    k_anchor = NaN;
else
    k_anchor = median(real(H1(band)), 'omitnan');
end
end

function rows = compute_metrics(methods, trim, k_anchor)
ids = fieldnames(methods);
rows = repmat(struct(),0,1);
for i = 1:numel(ids)
    id = ids{i};
    M = methods.(id);
    [kg, mg, cg] = method_grid(M, trim);
    k_med = median(kg, 'omitnan');
    rows(i).id = id;
    rows(i).label = M.label;
    rows(i).k_med = k_med;
    rows(i).acc_pct = 100 * abs(k_med - k_anchor) / k_anchor;
    rows(i).smooth_p95_pct = pct_metric(abs(diff(kg)), 95, k_med);
    rows(i).valid_pct = 100 * mean(isfinite(kg));
    rows(i).exc_pct = pct_metric(abs(kg - k_med), 100, k_med);
    rows(i).m_med = median(mg, 'omitnan');
    rows(i).c_med = median(cg, 'omitnan');
end
end

function [kg, mg, cg] = method_grid(M, trim)
tg = (trim(1):0.25:trim(2))';
kg = NaN(size(tg)); mg = kg; cg = kg;
if isempty(M.t)
    return
end
valid = M.valid(:) & isfinite(M.t(:)) & isfinite(M.k(:));
t = M.t(valid); k = M.k(valid); m = M.m(valid); c = M.c(valid);
if isempty(t)
    return
end
[t, ord] = sort(t);
k = k(ord); m = m(ord); c = c(ord);
[t, ia] = unique(t, 'last');
k = k(ia); m = m(ia); c = c(ia);
kg = interp1(t, k, tg, 'previous', NaN);
mg = interp1(t, m, tg, 'previous', NaN);
cg = interp1(t, c, tg, 'previous', NaN);
end

function val = pct_metric(x, pct, denom)
x = x(isfinite(x));
if isempty(x) || ~isfinite(denom) || denom == 0
    val = NaN;
elseif pct == 100
    val = 100 * max(x) / denom;
else
    val = 100 * prctile(x, pct) / denom;
end
end

function print_metrics(rec, k_anchor, rows)
fprintf('k_anchor %.6g N/m, official_k %.6g N/m\n', k_anchor, rec.official_k);
fprintf('%-36s %12s %9s %10s %9s %9s %12s %12s\n', ...
    'method','k_med','acc %','smooth %','valid %','exc %','m_med','c_med');
for i = 1:numel(rows)
    r = rows(i);
    fprintf('%-36s %12.5g %9.3f %10.3f %9.1f %9.3f %12.5g %12.5g\n', ...
        r.id, r.k_med, r.acc_pct, r.smooth_p95_pct, r.valid_pct, r.exc_pct, r.m_med, r.c_med);
end
end

function blocks = compute_blocks(methods)
edges = [0 32 64 96 128 160];
force_multiplier = [1 0.5 1 0.25 NaN];
ids = fieldnames(methods);
blocks = struct('edges',edges,'force_multiplier',force_multiplier,'rows',[]);
rows = repmat(struct(),0,1);
for i = 1:numel(ids)
    M = methods.(ids{i});
    tg = (0:0.25:160)';
    kg = grid_over(M, tg);
    vals = NaN(1,5);
    for j = 1:5
        if j == 1
            idx = tg >= edges(j) & tg <= edges(j+1);
        else
            idx = tg > edges(j) & tg <= edges(j+1);
        end
        v = kg(idx);
        last = find(isfinite(v),1,'last');
        if ~isempty(last)
            vals(j) = v(last);
        end
    end
    rows(i).id = ids{i};
    rows(i).label = M.label;
    rows(i).k_last = vals;
end
blocks.rows = rows;
end

function kg = grid_over(M, tg)
kg = NaN(size(tg));
if isempty(M.t)
    return
end
valid = M.valid(:) & isfinite(M.t(:)) & isfinite(M.k(:));
t = M.t(valid); k = M.k(valid);
if isempty(t)
    return
end
[t, ord] = sort(t); k = k(ord);
[t, ia] = unique(t, 'last'); k = k(ia);
kg = interp1(t, k, tg, 'previous', NaN);
end

function print_blocks(blocks)
fprintf('\nforce-block last valid k, N/m\n');
fprintf('%-36s %12s %12s %12s %12s %12s\n','method','0-32','32-64','64-96','96-128','128-160');
for i = 1:numel(blocks.rows)
    r = blocks.rows(i);
    fprintf('%-36s %12.5g %12.5g %12.5g %12.5g %12.5g\n', r.id, r.k_last);
end
end

function write_json_export(file, RES)
E = struct();
E.nan_sentinel = -1e30;
E.records = {};   % cell: records carry different series/blocks fields
for i = 1:numel(RES)
    R = RES(i);
    ER = struct('name',R.name,'trim',R.trim,'k_anchor',R.k_anchor, ...
        'official_k',R.official_k,'blocks',[],'series',struct(), ...
        'metrics',R.metrics,'batch',R.batch);
    if ~isempty(R.blocks)
        ER.blocks = R.blocks;
    end
    ids = fieldnames(R.methods);
    for j = 1:numel(ids)
        id = ids{j};
        M = R.methods.(id);
        idx = downsample_idx(M.t, 1200);
        S = struct();
        S.label = M.label;
        S.t = clean_num(round_sig(M.t(idx)));
        S.k = clean_num(round_sig(M.k(idx)));
        S.m = clean_num(round_sig(M.m(idx)));
        S.c = clean_num(round_sig(M.c(idx)));
        if strcmp(id,'fable')
            S.k_direct = clean_num(round_sig(M.k_direct(idx)));
            S.sigma_k = clean_num(round_sig(M.sigma_k(idx)));
            S.status = M.status(idx);
            S.adapted_t = clean_num(round_sig(M.t(M.adapted & isfinite(M.t))));
        end
        ER.series.(id) = S;
    end
    E.records{end+1} = ER;
end
E = sanitize_for_json(E, E.nan_sentinel);
txt = jsonencode(E);
fid = fopen(file,'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'window.FABLE_STIFFNESS_RESULTS = %s;', txt);
end

function idx = downsample_idx(t, nmax)
t = t(:);
if isempty(t)
    idx = [];
    return
end
if ~any(isfinite(t))
    idx = [];
    return
end
keep = isfinite(t) & t >= 0 & t <= max(t(isfinite(t)));
ii = find(keep);
if numel(ii) <= nmax
    idx = ii;
else
    idx = ii(unique(round(linspace(1,numel(ii),nmax))));
end
end

function y = round_sig(x)
y = round(x(:), 6, 'significant');
end

function x = clean_num(x)
x = x(:)';
x(~isfinite(x)) = -1e30;
end

function y = sanitize_for_json(x, sentinel)
if isnumeric(x)
    y = x;
    y(~isfinite(y)) = sentinel;
elseif isstruct(x)
    y = x;
    for i = 1:numel(x)
        f = fieldnames(x);
        for j = 1:numel(f)
            y(i).(f{j}) = sanitize_for_json(x(i).(f{j}), sentinel);
        end
    end
elseif iscell(x)
    y = x;
    for i = 1:numel(x)
        y{i} = sanitize_for_json(x{i}, sentinel);
    end
else
    y = x;
end
end
