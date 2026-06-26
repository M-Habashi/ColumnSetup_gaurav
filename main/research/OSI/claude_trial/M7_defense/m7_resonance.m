function out = m7_resonance(dm, t, fs, C, H0d, p)
%M7_RESONANCE Self-contained Method 7 (output-only resonance / sensitivity-peak
% NCF margin). Uses ONLY the measured response dm (not dc or dd). See M7.md.
%
%   out = m7_resonance(dm, t, fs, C, H0d, p)
%   p (optional) overrides defaults below.
%
% Per window: Spk = sqrt(peak PSD / floor PSD of dm) ~ ||S||_inf ; the loop-only
% NCF near the binding mode is b ~ b_nom * Spk_ref/Spk, with b_nom the model's
% NCF over the binding band and Spk_ref calibrated on the first calib_s seconds.

    d = struct('buf',4, 'hop',0.5, 'peak_band',[25 40], 'floor_band',[42 58], ...
        'binding_band',[10 58], 't_start',t(1), 't_end',t(end), 'calib_s',20, ...
        'medfilt',9, 'cap',0.70, 'thr',0.40, 'detect_consec',7);
    if nargin >= 6 && ~isempty(p)
        f = fieldnames(p); for i=1:numel(f), d.(f{i}) = p.(f{i}); end
    end
    p = d;

    % nominal binding NCF from the MODEL (calibration target b_nom ~ 0.588)
    fb = logspace(log10(p.binding_band(1)), log10(p.binding_band(2)), 2000).';
    L0 = squeeze(freqresp(C*H0d, 2*pi*fb));
    b_nom = min(abs(1+L0) ./ sqrt(2*(1+abs(L0).^2)));

    Nbuf = round(p.buf*fs);
    nfft = 2^nextpow2(round(2*fs));  seg = min(2048, Nbuf);  ov = round(seg/2);
    win = hann(seg);
    tend = (p.t_start + p.buf) : p.hop : p.t_end;
    nW = numel(tend);  tc = tend.' - p.buf/2;

    Spk = nan(nW,1);
    for k = 1:nW
        i1 = find(t >= tend(k) - p.buf, 1);
        y  = detrend(dm(i1:i1+Nbuf-1));               % OUTPUT ONLY
        [pp, ff] = pwelch(y, win, ov, nfft, fs);
        peak = max(   pp(ff>=p.peak_band(1)  & ff<=p.peak_band(2)));
        flr  = median(pp(ff>=p.floor_band(1) & ff<=p.floor_band(2)));
        Spk(k) = sqrt(peak / max(flr, eps));          % ~ ||S||_inf
    end
    Spk  = medfilt1(Spk, p.medfilt);
    Sref = median(Spk(tc < p.t_start + p.calib_s), 'omitnan');
    b    = min(b_nom * Sref ./ Spk, p.cap);

    below = b < p.thr;
    hit = find(movsum(below, [p.detect_consec-1, 0]) >= p.detect_consec, 1);
    detect_time = NaN; if ~isempty(hit), detect_time = tc(hit); end

    out = struct('tc', tc, 'b', b, 'Spk', Spk, 'Sref', Sref, 'b_nom', b_nom, ...
        'detect_time', detect_time, 'thr', p.thr, 'params', p);
end
