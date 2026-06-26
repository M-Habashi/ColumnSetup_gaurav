%% PROOF 3 -- Spk ~ ||S||_inf, and the resonance margin tracks the true FRF margin
% Validated on 1731 (broadband), where the open-loop FRF IS identifiable so we
% have a trustworthy reference. We compare, per window:
%   (i)  ||S||_frf = 1/min|1+L| over the resonance band, from L=C*FRF(dc->dm);
%   (ii) Spk = sqrt(peak/floor PSD of dm)         -- the output-only estimate.
% Claim: Spk and ||S||_frf are strongly correlated (Spk reads the peak
% sensitivity), and the resonance margin b=b_nom*Sref/Spk tracks the FRF
% loop-only NCF margin (similar decline & detection time).
addpath(fileparts(mfilename('fullpath')));
verdict = ["FAIL","PASS"];
fprintf('\n========== PROOF 3: Spk ~ ||S||_inf and tracks the FRF margin (1731) ==========\n');

[D, M] = m7d_setup('A');                       % broadband -> FRF is valid
t = D.t; fs = D.fs; band = [25 45];
buf = 4; Nb = round(buf*fs); tend = (D.w(1)+buf):0.5:D.w(2); tc = tend.'-buf/2;
ndist = @(L) abs(1+L)./sqrt(2*(1+abs(L).^2));
Sfrf = nan(numel(tend),1); bfrf = nan(numel(tend),1); Spk = nan(numel(tend),1);
for k = 1:numel(tend)
    i1 = find(t>=tend(k)-buf,1); idx = i1:i1+Nb-1;
    [~, Hf, ff, P] = evalc('xfunc(D.dc(idx), D.dm(idx), fs, 2048, 1024)');
    coh = abs(P(:,3)).^2./max(P(:,1).*P(:,2),eps);
    sel = ff>=band(1) & ff<=band(2) & coh>=0.5;
    if nnz(sel) >= 3
        L = squeeze(freqresp(M.C, 2*pi*ff(sel))) .* Hf(sel);
        Sfrf(k) = 1/min(abs(1+L));               % peak sensitivity from FRF
        bfrf(k) = min(ndist(L));                  % FRF loop-only NCF (resonance band)
    end
    [pp, fp] = pwelch(detrend(D.dm(idx)), hann(2048), 1024, 4096, fs);
    Spk(k) = sqrt(max(pp(fp>=25&fp<=40)) / median(pp(fp>=42&fp<=58)));
end
Spk = medfilt1(Spk,9); Sfrf = medfilt1(Sfrf,9); bfrf = medfilt1(bfrf,9);

g = ~isnan(Sfrf) & ~isnan(Spk);
rho = corr(log(Sfrf(g)), log(Spk(g)));           % both are amplification ratios -> log
fprintf('corr( log||S||_frf , log Spk ) = %.2f   (Spk reads the peak sensitivity)\n', rho);

% resonance margin vs FRF margin
fb = logspace(log10(10),log10(58),2000)'; L0=squeeze(freqresp(M.C*M.H0d,2*pi*fb));
b_nom = min(ndist(L0)); Sref = median(Spk(tc<D.w(1)+20),'omitnan');
b_spk = min(b_nom*Sref./Spk, 0.7);
dfrf = tc(find(movsum(bfrf<0.4,[4 0])>=5,1)); dspk = tc(find(movsum(b_spk<0.4,[6 0])>=7,1));
if isempty(dfrf), dfrf=NaN; end; if isempty(dspk), dspk=NaN; end
fprintf('detection: FRF margin = %.1f s ,  resonance margin = %.1f s\n', dfrf, dspk);

ok1 = rho > 0.5;
ok2 = ~isnan(dfrf) && ~isnan(dspk) && abs(dfrf-dspk) < 30;
fprintf('  => Spk correlates with ||S||_frf: %s ;  margins detect within 30 s: %s\n', ...
    verdict(ok1+1), verdict(ok2+1));
pass = ok1 && ok2;

fig=figure('Color','w','Position',[80 80 1100 440]);
subplot(1,2,1); loglog(Sfrf(g),Spk(g),'.','MarkerSize',8); grid on;
xlabel('||S||_{inf} from FRF'); ylabel('Spk (output-only)'); title(sprintf('Spk vs ||S|| (corr=%.2f)',rho));
subplot(1,2,2); plot(tc,bfrf,'b-','LineWidth',1.3); hold on; plot(tc,b_spk,'m-','LineWidth',1.6); grid on;
yline(0.4,':','threshold'); xlim(D.w); ylim([0 0.8]);
legend('FRF loop-only NCF','resonance margin (M7)','Location','southwest');
xlabel('time (s)'); ylabel('NCF margin'); title('1731: resonance margin tracks the FRF margin');
sgtitle('PROOF 3: output-only Spk reads the peak sensitivity and reproduces the FRF margin (1731)');
saveas(fig, fullfile(fileparts(mfilename('fullpath')),'figs','proof3_spk_tracks_margin.png')); close(fig);

fprintf('\nPROOF 3 OVERALL: %s\n', verdict(pass+1));
proof_pass = pass;
