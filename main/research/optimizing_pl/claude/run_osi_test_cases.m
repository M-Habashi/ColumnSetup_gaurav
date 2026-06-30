%% RUN_OSI_TEST_CASES  Score output-only margin indicators on the canonical 5 cases.
% For each case (osi_test_cases.m): the TRUE loop-only NCF and its binding frequency
% (ground truth), then the two output-only indicators -- M7 (fixed 25-42/55-75 band)
% and PP-wide (sharp absolute peak found anywhere over 1.5-90 Hz, floor from the
% healthy quiet shelf). Both calibrated once on case C1 (healthy). Output-only
% regime: dm = S * internal disturbance.
clearvars; clc;
this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);
main = fileparts(fileparts(fileparts(this_dir)));
addpath(fullfile(main,'control_and_HS','b_system_id','id_utils'));
[cases, ctx] = osi_test_cases();
dt = ctx.dt; fs = round(1/dt); sigma = ctx.sigma;

w = 2*pi*logspace(log10(1.5),log10(120),9000).';
ncf = @(L) min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
bnom = ncf(squeeze(freqresp(cases(1).C*cases(1).H, w)));

% windowing / spectra
buf=4; Nb=round(buf*fs); nfft=4096; win=hann(2048); ov=1024; nseed=6;
[~,ff]=pwelch(randn(Nb,1),win,ov,nfft,fs);
ppb = ff>=1.5 & ff<=90 & ~(ff>=58 & ff<=62);
s_m7 = @(P) sqrt(max(P(ff>=25&ff<=42))/median(P(ff>=55&ff<=75)));

% --- calibrate on C1 (healthy): baseline floor + refs ---
xh = sim_dm(cases(1), 1, sigma, dt);
P0 = avgpsd(xh, Nb, win, ov, nfft, fs);
floormask = ppb & (P0 < prctile(P0(ppb),40));
s_pp = @(P) sqrt(max(movmedian(P,3).*ppb)/median(P(floormask)));
[refM, refP] = calib(xh, Nb, fs, win, ov, nfft, s_m7, s_pp);

alarm = 0.8*bnom;   % project relative-alarm rule (~0.47); "unsafe truth" = b_true<0.40
fprintf('\n=================  OSI 5-CASE BATTERY  =================\n');
fprintf(['bnom=%.3f, detect if b<%.2f (0.8*bnom rule), truth unsafe if b_true<0.40,\n' ...
    'M7 band 25-42/55-75, PP band 1.5-90 Hz\n\n'], bnom, alarm);
fprintf('%-3s %-26s %7s %6s %6s | %12s | %12s\n', ...
    'id','case','b_true','fHz','band','M7','PP-wide');
for i=1:numel(cases)
    c=cases(i);
    Hd = c.H; if c.delay_samples>0, Hd = c.H*tf(1,[1 zeros(1,c.delay_samples)],dt); end
    L = squeeze(freqresp(c.C*Hd, w)); bt = ncf(L);
    [~,kk]=min(abs(1+L)./sqrt(2*(1+abs(L).^2))); fb = w(kk)/(2*pi);
    bM=[]; bP=[];
    for s=1:nseed
        x = sim_dm(c, s, sigma, dt);
        [vM,vP] = winb(x, Nb, fs, win, ov, nfft, s_m7, s_pp, refM, refP, bnom);
        bM=[bM vM]; bP=[bP vP]; %#ok<AGROW>
    end
    mM=mean(bM); mP=mean(bP); should = bt<0.40;
    band = ternary(fb>=25 && fb<=42, 'IN', 'OUT');
    fprintf('%-3s %-26s %7.3f %6.1f %6s | %5.2f %-6s | %5.2f %-6s\n', ...
        c.id, c.name, bt, fb, band, mM, verdict(mM,should,alarm), mP, verdict(mP,should,alarm));
end
fprintf(['\nverdicts: detect / MISS (should alarm) , ok / FALSE (healthy).\n' ...
    'C1-C3 in band: M7 handles. C4-C5 out of band: M7 misses; PP catches in this\n' ...
    'output-only/steady regime (but see run_osi_ncf_direct_compare for the broadband-\n' ...
    'input contamination that limits PP under real excitation).\n']);

%% ---- helpers ----
function dm = sim_dm(c, seed, sigma, dt)
    fs=round(1/dt); N=round(30*fs);
    Hd = c.H; if c.delay_samples>0, Hd = c.H*tf(1,[1 zeros(1,c.delay_samples)],dt); end
    S = feedback(1, c.C*Hd); rng(seed);
    dm = lsim(S, sigma*randn(N,1)); dm = dm + 0.01*std(dm)*randn(N,1);
end
function starts = win_starts(x, Nb, fs)
    starts = 1:round(0.5*fs):(numel(x)-Nb+1);   % successive backward windows of Nb samples
end
function P = avgpsd(x, Nb, win, ov, nfft, fs)
    P = 0; st = win_starts(x, Nb, fs);
    for i1 = st
        P = P + pwelch(detrend(x(i1:i1+Nb-1)), win, ov, nfft, fs);
    end
    P = P/numel(st);
end
function [rM,rP] = calib(x, Nb, fs, win, ov, nfft, sM, sP)
    st = win_starts(x, Nb, fs); vM = zeros(numel(st),1); vP = vM;
    for j = 1:numel(st)
        P = pwelch(detrend(x(st(j):st(j)+Nb-1)), win, ov, nfft, fs);
        vM(j) = sM(P); vP(j) = sP(P);
    end
    rM = median(vM); rP = median(vP);
end
function [vM,vP] = winb(x, Nb, fs, win, ov, nfft, sM, sP, rM, rP, bnom)
    st = win_starts(x, Nb, fs); vM = zeros(numel(st),1); vP = vM;
    for j = 1:numel(st)
        P = pwelch(detrend(x(st(j):st(j)+Nb-1)), win, ov, nfft, fs);
        vM(j) = min(bnom*rM/sM(P), 1/sqrt(2));
        vP(j) = min(bnom*rP/sP(P), 1/sqrt(2));
    end
end
function v = verdict(b, should, alarm)
    alarmed = b < alarm;
    if should && alarmed
        v = 'detect';
    elseif should
        v = 'MISS';
    elseif alarmed
        v = 'FALSE';
    else
        v = 'ok';
    end
end
function s = ternary(c,a,b), if c, s=a; else, s=b; end, end
