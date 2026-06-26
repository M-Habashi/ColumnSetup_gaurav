function s = osi_warmup_hold(s, tc, cfg, holdval)
%OSI_WARMUP_HOLD Hold the indicator at its nominal value over the weakly-excited
% start of the window (first ~3 s), in sliding (fast) mode only. The objective's
% window opens at 620 s but strong excitation begins ~622 s, so short-window
% estimates there are unreliable; "model correct at the beginning" justifies the
% hold. No-op in non-overlapping mode.
    if strcmp(cfg.win_mode, 'sliding')
        s(tc < cfg.t_start + 3) = holdval;
    end
end
