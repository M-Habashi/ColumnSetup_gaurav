%% Trial 5 -- Method 5: Recursive online tracking (RLS / Kalman)
% A recursive-least-squares ARX tracker (na=nb=5, forgetting factor lambda)
% runs continuously on DECIMATED (2048->256 Hz) dc->dm data -- the dynamics are
% < 60 Hz, so decimation conditions the estimation and is O(1) per sample. At
% each non-overlapping window boundary the parameter vector is snapshotted into
% Hhat(z) = B(z)/A(z); Lhat = C*Hhat is evaluated on the physical-frequency grid
% and the loop-only NCF margin is taken. The RLS recursion is itself a Kalman
% filter on a random-walk parameter model. Output: NCF margin (620-770.1 s).

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

% --- decimate the command/response over the (padded) analysis span ---
r   = cfg.dec_factor;  fsd = ctx.fs / r;
dcd = decimate(ctx.dc, r);
dmd = decimate(ctx.dm, r);
td  = ctx.t(1) + (0:numel(dmd)-1).' / fsd;

% --- recursive least squares (ARX) with exponential forgetting ---
na = cfg.rls_na; nb = cfg.rls_nb; nk = cfg.rls_nk; lam = cfg.rls_lambda;
nth = na + nb;  th = zeros(nth, 1);  Pm = cfg.rls_P0 * eye(nth);
thHist = zeros(numel(td), nth);
k0 = max(na, nb + nk) + 1;
for kk = 1:numel(td)
    if kk >= k0
        phi = [ -dmd(kk-1:-1:kk-na); dcd(kk-nk:-1:kk-nk-nb+1) ];
        K   = Pm*phi / (lam + phi.'*Pm*phi);
        th  = th + K*(dmd(kk) - phi.'*th);
        Pm  = (Pm - K*phi.'*Pm) / lam;
    end
    thHist(kk, :) = th.';
end

% --- snapshot at each window boundary, compute loop-only NCF ---
ncf = nan(ctx.nW, 1);
for k = 1:ctx.nW
    ke  = find(td <= ctx.edges(k+1), 1, 'last');
    thk = thHist(ke, :).';
    A = [1, thk(1:na).'];
    B = [zeros(1, nk), thk(na+1:end).'];
    H5 = freqz(B, A, cfg.fgrid, fsd);                 % Hhat on physical Hz grid
    ncf(k) = osi_ncf_looponly(ctx.Cf .* H5(:));       % Lhat = C(jw) * Hhat(jw)
end

result = struct('tag', 'trial_5', ...
    'method', sprintf('Method 5 - Recursive RLS tracker (256 Hz, lambda=%.3f)', lam), ...
    'tc', ctx.tc, 'ncf', ncf, 'nominal', ctx.nom_ncf);
osi_report_series(result, cfg);
