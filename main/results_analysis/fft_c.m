function [Y_f, freq] = fft_c(y_t, fs, fmax)
%FFT_C Return the correctly scaled one-sided FFT of a real signal.

y_t = y_t(:);
N = numel(y_t);
Y_f = fft(y_t)/N;

last_idx = floor(N/2)+1;
Y_f = Y_f(1:last_idx);
freq = (0:last_idx-1)'*fs/N;

% Double only bins that have a distinct negative-frequency counterpart.
if mod(N, 2) == 0
    Y_f(2:end-1) = 2*Y_f(2:end-1);
else
    Y_f(2:end) = 2*Y_f(2:end);
end

if nargin > 2 && ~isempty(fmax)
    keep = freq <= fmax;
    freq = freq(keep);
    Y_f = Y_f(keep);
end

if (nargout == 0)
    figure;
    plot(freq, abs(Y_f));
    xlabel('Frequency (Hz)');
    ylabel('|Y(f)|');
    title('FFT of y');
end

end

