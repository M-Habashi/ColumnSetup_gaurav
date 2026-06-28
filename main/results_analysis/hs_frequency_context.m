function context = hs_frequency_context(hs, fs_hz, fmax_hz, duration_s, acceleration_sample)
%HS_FREQUENCY_CONTEXT Build reusable HS frequency-domain annotations.
% Units: fs/fmax/duration/frequency [Hz/s/Hz], acceleration [m/s^2].

context = struct('mode_frequency_hz', [], 'eq_freq_hz', [], ...
    'eq_fft_abs', [], 'earthquake_type', '');
if nargin < 1 || ~isstruct(hs)
    return
end

if isfield(hs, 'damping') && isfield(hs.damping, 'frequency_hz')
    context.mode_frequency_hz = hs.damping.frequency_hz(:);
    context.mode_frequency_hz = context.mode_frequency_hz( ...
        context.mode_frequency_hz <= fmax_hz);
end
if isfield(hs, 'earthquake_type')
    context.earthquake_type = char(string(hs.earthquake_type));
end

if nargin < 5
    acceleration_sample = [];
end
if isempty(acceleration_sample) && isfield(hs, 'time') && isfield(hs, 'ag')
    time_scale_factor = 1;
    if isfield(hs, 'time_scale_factor')
        time_scale_factor = hs.time_scale_factor;
    end
    if nargin < 4 || isempty(duration_s)
        duration_s = hs.time(end)*time_scale_factor;
    end
    sample_time = (0:ceil(duration_s*fs_hz))'/fs_hz;
    model_time = sample_time/time_scale_factor;
    acceleration_sample = interp1(hs.time(:), hs.ag(:), model_time, ...
        'linear', 0);
end

if ~isempty(acceleration_sample)
    [Y_ag, freq_ag] = fft_c(acceleration_sample(:), fs_hz, fmax_hz);
    context.eq_freq_hz = freq_ag;
    context.eq_fft_abs = abs(Y_ag);
end
end
