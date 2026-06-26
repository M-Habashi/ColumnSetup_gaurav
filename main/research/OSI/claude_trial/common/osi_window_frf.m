function [H, f, coh, P] = osi_window_frf(x, y, fs, cfg)
%OSI_WINDOW_FRF Welch H1 transfer estimate x->y with coherence, via repo xfunc.
% Returns the full positive-frequency vectors plus the ordinary coherence.
% Units: x,y same displacement units; H = y/x dimensionless; f, fs Hz.
    % xfunc prints an averaging line; suppress it for clean trial output.
    [~, H, f, P] = evalc('xfunc(x, y, fs, cfg.fft_len, cfg.fft_ov)');
    coh = abs(P(:,3)).^2 ./ max(P(:,1).*P(:,2), eps);
end
