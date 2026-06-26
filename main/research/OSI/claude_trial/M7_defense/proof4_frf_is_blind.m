%% PROOF 4 -- On 1749 the FRF margin is BLIND; the resonance margin SEES it
% Because of the lock (Proof 1), the FRF loop L=C*FRF(dc->dm) ~ -1 at 35 Hz for
% ALL time, so the FRF loop-only NCF over a band including 35 Hz is a spurious
% near-constant -- it cannot tell the healthy phase from the instability. The
% output-only resonance margin (Method 7) instead drops sharply at the event.
addpath(fileparts(mfilename('fullpath')));
verdict = ["FAIL","PASS"];
fprintf('\n========== PROOF 4: FRF is blind on 1749; resonance margin is not ==========\n');

[D, M] = m7d_setup('B');                       % 1749 low-frequency input
t = D.t; fs = D.fs; band = [25 45];
buf = 4; Nb = round(buf*fs); tend = (D.w(1)+buf):0.5:D.w(2); tc = tend.'-buf/2;
ndist = @(L) abs(1+L)./sqrt(2*(1+abs(L).^2));
bfrf = nan(numel(tend),1);
for k = 1:numel(tend)
    i1 = find(t>=tend(k)-buf,1); idx = i1:i1+Nb-1;
    [~, Hf, ff, P] = evalc('xfunc(D.dc(idx), D.dm(idx), fs, 2048, 1024)');
    coh = abs(P(:,3)).^2./max(P(:,1).*P(:,2),eps);
    sel = ff>=band(1) & ff<=band(2) & coh>=0.3;       % NO power gate (use 35 Hz as-is)
    if nnz(sel)>=3
        L = squeeze(freqresp(M.C, 2*pi*ff(sel))) .* Hf(sel);
        bfrf(k) = min(ndist(L));
    end
end
m7 = m7_resonance(D.dm, t, fs, M.C, M.H0d, struct('t_start',D.w(1),'t_end',D.w(2)));

% "stable phase" = first 60% of the window; "event phase" = last 30%
sb = tc < D.w(1)+0.6*(D.w(2)-D.w(1));
ev = tc > D.w(1)+0.7*(D.w(2)-D.w(1));
ev7 = m7.tc > D.w(1)+0.7*(D.w(2)-D.w(1));
sb7 = m7.tc < D.w(1)+0.6*(D.w(2)-D.w(1));
fprintf('FRF margin over [25 45]Hz: stable mean=%.3f, event min=%.3f  (no separation -> blind)\n', ...
    mean(bfrf(sb),'omitnan'), min(bfrf(ev)));
fprintf('Method 7 margin:           stable mean=%.3f, event min=%.3f  (clear drop -> sees it)\n', ...
    mean(m7.b(sb7),'omitnan'), min(m7.b(ev7)));

ok_blind = mean(bfrf(sb),'omitnan') < 0.15 && (min(bfrf(ev)) > mean(bfrf(sb),'omitnan')-0.1);  % flat & low
ok_see   = mean(m7.b(sb7),'omitnan') > 0.45 && min(m7.b(ev7)) < 0.2;                            % separates
fprintf('  => FRF is flat/near-0 (blind): %s ;  Method 7 separates stable vs event: %s\n', ...
    verdict(ok_blind+1), verdict(ok_see+1));
pass = ok_blind && ok_see;

fig=figure('Color','w','Position',[80 80 1000 430]); hold on; grid on;
plot(tc, bfrf, 'b-','LineWidth',1.3,'DisplayName','FRF margin over [25 45] Hz (blind)');
plot(m7.tc, m7.b, 'm-','LineWidth',1.7,'DisplayName','Method 7 resonance margin (sees it)');
yline(0.4,':','threshold','Color',[0.85 0.33 0.1],'HandleVisibility','off'); xlim(D.w); ylim([0 0.8]);
xlabel('time (s)'); ylabel('NCF margin'); legend('Location','west');
title('PROOF 4 (1749): FRF margin stays ~0 (tautology) while Method 7 catches the collapse');
saveas(fig, fullfile(fileparts(mfilename('fullpath')),'figs','proof4_frf_is_blind.png')); close(fig);

fprintf('\nPROOF 4 OVERALL: %s\n', verdict(pass+1));
proof_pass = pass;
