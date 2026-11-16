function [manual_margin, w_at_peak, phase_at_peak] = compute_ncfmargin(G, K, max_freq)
    % Set a default max frequency if one is not provided.
    if nargin < 3
        max_freq = 10000;
    end

    w = logspace(-1, log10(max_freq), 10000);
    
    % Convert from 3D arrays to vectors
    resp_G = squeeze(freqresp(G, w));
    resp_K = squeeze(freqresp(K, w));
    
    sigma = (sqrt(abs(resp_G).^2 + 1) .* sqrt(abs(resp_K).^2 + 1)) ./ abs(1 + resp_G .* resp_K);
    
    % Find the peak value and its index
    [max_sigma, idx] = max(sigma);
    
    % Find the frequency (omega) corresponding to the peak
    w_at_peak = w(idx);
    
    % Calculate the phase of the open-loop response at the peak frequency
    loop_response_at_peak = resp_G(idx) * resp_K(idx);
    phase_at_peak = resp_G(idx) * resp_K(idx);
    
    manual_margin = 1 / max_sigma;
end