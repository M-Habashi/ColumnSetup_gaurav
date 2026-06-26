%% PROOF 1 -- The closed-loop LOCK and the dm/dc TAUTOLOGY at 35 Hz
% Claim: when dd has no 35 Hz energy, the controller forces dc = -C*dm there, so
%   (a) coherence(dc,dm) ~ 1  (perfectly locked),
%   (b) -dc/dm ~ C(35Hz)      (the implied "controller" equals the real one),
%   (c) |dm/dc| ~ 1/|C(35)|   (pinned), NOT the true |H0(35)|, and constant in time.
% On 1731 (broadband) the lock is BROKEN (independent 35 Hz excitation), proving
% the effect is specific to the low-frequency input.
addpath(fileparts(mfilename('fullpath')));
verdict = ["FAIL","PASS"];
fprintf('\n================ PROOF 1: closed-loop lock / tautology ================\n');

[~, M] = m7d_setup('A');
C35  = squeeze(freqresp(M.C, 2*pi*35));
H035 = abs(squeeze(freqresp(M.H0d, 2*pi*35)));
fprintf('MODEL @35Hz: |C|=%.3f, angle(C)=%.1f deg, 1/|C|=%.3f, true |H0(35)|=%.3f\n', ...
    abs(C35), angle(C35)*180/pi, 1/abs(C35), H035);

fig = figure('Color','w','Position',[80 80 1100 460]);
pass = true;  HEMP = cell(1,2); TC = cell(1,2);
for wi = 1:2
    [D, M] = m7d_setup(char('A'+wi-1));
    t = D.t; buf = 8; Nb = round(buf*D.fs); tend = (D.w(1)+buf):2:D.w(2); tc = tend.'-buf/2;
    Hemp = nan(numel(tend),1); coh = nan(numel(tend),1); Cimp = nan(numel(tend),1);
    for k = 1:numel(tend)
        i1 = find(t >= tend(k)-buf, 1); idx = i1:i1+Nb-1;
        [~, Hf, ff, P] = evalc('xfunc(D.dc(idx), D.dm(idx), D.fs, 8192, 4096)');
        [~, j] = min(abs(ff-35));
        Hemp(k) = Hf(j);                                   % dm/dc at 35 Hz (complex)
        coh(k)  = abs(P(j,3)).^2 / max(P(j,1)*P(j,2), eps);% coherence(dc,dm) at 35 Hz
        Cimp(k) = -1/Hf(j);                                % implied controller -dc/dm
    end
    HEMP{wi}=abs(Hemp); TC{wi}=tc;
    cohm   = median(coh,'omitnan');
    ratiom = median(abs(Hemp),'omitnan');
    reldC  = median(abs(Cimp-C35)./abs(C35),'omitnan');
    fprintf('\n%s\n  median coherence(dc,dm)@35 = %.3f\n', D.label, cohm);
    fprintf('  median |dm/dc|@35          = %.3f   (1/|C| = %.3f, true |H0| = %.3f)\n', ratiom, 1/abs(C35), H035);
    fprintf('  median |(-dc/dm) - C|/|C|  = %.3f\n', reldC);
    if D.which=='B'      % low-frequency: MUST be locked
        ok = cohm>0.97 && reldC<0.10 && abs(ratiom-1/abs(C35))/(1/abs(C35))<0.10;
        fprintf('  => LOCKED & pinned at 1/|C| (tautology): %s\n', verdict(ok+1));
    else                 % broadband: MUST NOT be locked
        ok = cohm<0.95 && std(abs(Hemp),'omitnan')>0.15;
        fprintf('  => NOT locked; |dm/dc| varies (real plant info): %s\n', verdict(ok+1));
    end
    pass = pass && ok;
    subplot(1,2,wi); plot(tc, abs(Hemp), 'b-','LineWidth',1.3); hold on; grid on;
    yline(1/abs(C35),'r--','1/|C| (tautology)','LineWidth',1.2);
    yline(H035,'g--','true |H0(35)|','LineWidth',1.2);
    ylim([0 max(4,1.2/abs(C35))]); xlim(D.w);
    xlabel('time (s)'); ylabel('|dm/dc| at 35 Hz'); title(D.label);
end
sgtitle('PROOF 1: |dm/dc|@35 pinned at 1/|C| for 1749 (locked); varies for 1731 (broadband)');
saveas(fig, fullfile(fileparts(mfilename('fullpath')),'figs','proof1_lock_tautology.png')); close(fig);

fprintf('\nPROOF 1 OVERALL: %s\n', verdict(pass+1));
proof_pass = pass;
