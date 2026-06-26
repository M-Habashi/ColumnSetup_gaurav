%% PROOF 2 -- The 35 Hz resonance GROWS in the response dm (both files)
% Claim: even though the ratio dm/dc is pinned (Proof 1), the closed-loop
% resonance amplitude in dm grows strongly toward instability -- so the
% instability IS observable in dm alone. We show the dm amplitude at 35 Hz rises
% by a large factor from the healthy phase to the pre-instability phase.
addpath(fileparts(mfilename('fullpath')));
verdict = ["FAIL","PASS"];
fprintf('\n================ PROOF 2: the 35 Hz resonance grows in dm ================\n');

fig = figure('Color','w','Position',[80 80 1100 460]);
pass = true;
for wi = 1:2
    [D, ~] = m7d_setup(char('A'+wi-1));
    t = D.t; buf = 4; Nb = round(buf*D.fs); tend = (D.w(1)+buf):0.5:D.w(2); tc = tend.'-buf/2;
    amp = nan(numel(tend),1);
    for k = 1:numel(tend)
        i1 = find(t >= tend(k)-buf, 1); y = detrend(D.dm(i1:i1+Nb-1));
        [pp, ff] = pwelch(y, hann(2048), 1024, 4096, D.fs);
        amp(k) = sqrt(max(pp(ff>=25 & ff<=40)));      % peak dm amplitude near 35 Hz
    end
    early = median(amp(tc < D.w(1)+0.3*(D.w(2)-D.w(1))), 'omitnan');   % healthy phase
    late  = max(amp);                                                  % near instability
    growth = late/early;
    fprintf('\n%s: healthy |dm(35)|~%.2e, peak |dm(35)|~%.2e  ->  growth x%.0f\n', ...
        D.label, early, late, growth);
    ok = growth > 5;
    fprintf('  => resonance grows >5x toward instability: %s\n', verdict(ok+1));
    pass = pass && ok;
    subplot(1,2,wi); semilogy(tc, amp, 'm-','LineWidth',1.3); grid on; xlim(D.w);
    xlabel('time (s)'); ylabel('|dm(35)|'); title(D.label);
end
sgtitle('PROOF 2: the 35 Hz resonance amplitude in dm grows strongly toward instability');
saveas(fig, fullfile(fileparts(mfilename('fullpath')),'figs','proof2_resonance_grows.png')); close(fig);

fprintf('\nPROOF 2 OVERALL: %s\n', verdict(pass+1));
proof_pass = pass;
