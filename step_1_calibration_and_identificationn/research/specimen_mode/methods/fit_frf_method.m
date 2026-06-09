function fit = fit_frf_method(D, estimator, use_coherence_weight)
x = D.x - mean(D.x);
F = D.F - mean(D.F);

nfft = min(8192, 2^floor(log2(numel(x) / 4)));
window = hann(nfft);
noverlap = floor(nfft / 2);

[Pxx, f] = pwelch(x, window, noverlap, nfft, D.fs);
Pff = pwelch(F, window, noverlap, nfft, D.fs);
Pxf = cpsd(x, F, window, noverlap, nfft, D.fs);
Pfx = cpsd(F, x, window, noverlap, nfft, D.fs);
coh = mscohere(x, F, window, noverlap, nfft, D.fs);

switch estimator
    case 'H1'
        H = Pxf ./ Pxx;
    case 'H2'
        H = Pff ./ Pfx;
    case 'Hv'
        H = (Pff - Pxx + sqrt((Pff - Pxx).^2 + 4 * abs(Pxf).^2)) ./ (2 * conj(Pxf));
end

valid = f > 0 & Pxx > 1e-4 * max(Pxx) & isfinite(real(H)) & isfinite(imag(H));
w = 2 * pi * f(valid);
H = H(valid);

A = [-w.^2 1i*w ones(size(w))];
b = H;

if use_coherence_weight
    weight = sqrt(coh(valid) .* Pxx(valid) / max(Pxx(valid)));
    A = A .* weight;
    b = b .* weight;
end

p = [real(A); imag(A)] \ [real(b); imag(b)];
fit = pack_fit(estimator, p);
end
