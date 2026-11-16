function [Y_f, freq] = fft_c(y_t, fs, fmax)

%% FFT
Ts=1/fs;
N = length(y_t);
Y_fft = fft(y_t)/(N-1);  % Normalized FFT
% Frequency vector
freq = (0:N-1)/Ts/N; % Hz
if nargin > 2 && ~isempty(fmax)
    max_idx = find(freq <= fmax, 1, 'last');
    idx = 1:max_idx;
else
    idx = 1:(length(freq)/2+1);
end
freq = freq(idx);
Y_f = 2*Y_fft(idx);

if (nargout == 0)
    figure;
    plot(freq, abs(Y_f));
    xlabel('Frequency (Hz)');
    ylabel('|Y(f)|');
    title('FFT of y');
end

end

