function [gain_margin_db, phase_margin_deg, ncf_margin] = ...
    custom_stability_margins(loop_tf, freq_range_hz)
%CUSTOM_STABILITY_MARGINS Practical SISO margins over a specified band.
% Gain margin considers only destabilizing gain increases. Phase margin
% considers positive margins at unity-gain crossings. The loop-only NCF
% margin assumes a unity-controller factorization and is evaluated as the
% normalized Nyquist distance over the requested frequency range.

    freq_hz = logspace(log10(freq_range_hz(1)), ...
        log10(freq_range_hz(2)), 10000).';
    response = squeeze(freqresp(loop_tf, 2*pi*freq_hz));
    response = response(:);

    imag_response = imag(response);
    phase_crossings = find(imag_response(1:end-1).*imag_response(2:end) <= 0);
    gain_candidates = [];
    for i = phase_crossings.'
        fraction = -imag_response(i)/(imag_response(i+1) - imag_response(i));
        crossing_response = response(i) + ...
            fraction*(response(i+1) - response(i));
        if real(crossing_response) < 0
            candidate = 1/abs(crossing_response);
            if candidate >= 1
                gain_candidates(end+1, 1) = candidate; %#ok<AGROW>
            end
        end
    end
    gain_margin_db = 20*log10(min([gain_candidates; Inf]));

    log_magnitude = log(abs(response));
    gain_crossings = find(log_magnitude(1:end-1).*log_magnitude(2:end) <= 0);
    phase_deg = unwrap(angle(response))*180/pi;
    phase_candidates = [];
    for i = gain_crossings.'
        fraction = -log_magnitude(i)/(log_magnitude(i+1) - log_magnitude(i));
        crossing_phase = phase_deg(i) + fraction*(phase_deg(i+1) - phase_deg(i));
        candidate = mod(180 + crossing_phase + 180, 360) - 180;
        if candidate > 0
            phase_candidates(end+1, 1) = candidate; %#ok<AGROW>
        end
    end
    phase_margin_deg = min([phase_candidates; Inf]);

    normalized_distance = abs(1 + response) ./ ...
        sqrt(2*(1 + abs(response).^2));
    ncf_margin = min(normalized_distance);
end
