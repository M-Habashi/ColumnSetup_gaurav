%% PROOF 5 -- Method 7 detects on BOTH files, with no stable-phase false alarm
% Run the self-contained method on both records and check:
%   1731 (broadband): detects, and detection is close to the FRF methods (~728 s);
%   1749 (low-freq) : detects (the only method that does), b drops well below 0.2;
%   neither file false-alarms during the calibrated healthy phase.
addpath(fileparts(mfilename('fullpath')));
verdict = ["FAIL","PASS"];
fprintf('\n================ PROOF 5: Method 7 detects on both files ================\n');

fig = figure('Color','w','Position',[80 80 1100 460]);
pass = true;
for wi = 1:2
    [D, M] = m7d_setup(char('A'+wi-1));
    m7 = m7_resonance(D.dm, D.t, D.fs, M.C, M.H0d, struct('t_start',D.w(1),'t_end',D.w(2)));
    range = D.w(2)-D.w(1);
    healthy = m7.tc > D.w(1)+m7.params.calib_s & m7.tc < D.w(1)+0.4*range;  % clearly pre-decline
    event   = m7.tc > D.w(1)+0.7*range;                                     % last 30%
    fa = min(m7.b(healthy));                                                % false-alarm check
    fprintf('\n%s: b_nom=%.3f Spk_ref=%.2f | healthy-phase min=%.3f (no FA if >0.4) | event min=%.3f | detect=%.1f s\n', ...
        D.label, m7.b_nom, m7.Sref, fa, min(m7.b(event)), m7.detect_time);
    if D.which=='B'
        ok = ~isnan(m7.detect_time) && min(m7.b(event))<0.2 && fa>0.40;
        fprintf('  => 1749: detects + b<0.2 at event + no false alarm: %s\n', verdict(ok+1));
    else
        ok = ~isnan(m7.detect_time) && abs(m7.detect_time-728)<40 && fa>0.40;
        fprintf('  => 1731: detects near the FRF methods (~728 s) + no false alarm: %s\n', verdict(ok+1));
    end
    pass = pass && ok;
    stable = m7.tc < D.w(1)+0.6*range;  %#ok<NASGU>  (kept for plot context)
    subplot(1,2,wi); plot(m7.tc, m7.b, 'm-','LineWidth',1.6); hold on; grid on;
    yline(m7.b_nom,'--','nominal','Color',[0 0.45 0.74]);
    yline(0.4,':','threshold','Color',[0.85 0.33 0.1]);
    if ~isnan(m7.detect_time), xline(m7.detect_time,'-.',sprintf('detect %.0f s',m7.detect_time),'Color',[0.6 0 0]); end
    xlim(D.w); ylim([0 0.8]); xlabel('time (s)'); ylabel('NCF margin'); title(D.label);
end
sgtitle('PROOF 5: Method 7 (output-only) detects the instability on both records');
saveas(fig, fullfile(fileparts(mfilename('fullpath')),'figs','proof5_method7_detects.png')); close(fig);

fprintf('\nPROOF 5 OVERALL: %s\n', verdict(pass+1));
proof_pass = pass;
