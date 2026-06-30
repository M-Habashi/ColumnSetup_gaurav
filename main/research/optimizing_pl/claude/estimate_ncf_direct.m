function out = estimate_ncf_direct(response, kind, freq_hz)
%ESTIMATE_NCF_DIRECT Loop-only NCF margin straight from a frequency response.
% Avoids the GM step entirely. Uses the exact identity (verified to 4 decimals
% against custom_stability_margins):
%
%   b(w) = |1+L|/sqrt(2(1+|L|^2)) = 1/(sqrt(2)*sqrt(|S(jw)|^2 + |T(jw)|^2))
%   NCF  = min_w b(w) = 1 / ( sqrt(2) * max_w sqrt(|S|^2 + |T|^2) )
%
% with S = 1/(1+L) (sensitivity) and T = L/(1+L) (complementary sensitivity).
% Because it uses |S| and |T| at EVERY frequency, it sees the whole Nyquist curve
% and therefore captures a low phase margin (Nyquist passing near -1 away from the
% -180 deg crossing) that a gain-margin reading is blind to: high GM can coexist
% with low NCF, and this estimator reports the true low value.
%
% Why it is directly measurable online: for a unity-feedback loop the complementary
% sensitivity T is the CLOSED-LOOP FRF from command to output -- for the inner
% actuator loop that is exactly T = dm/dd_lead, which is already logged. Then
% S = 1 - T, no open-loop inversion needed (closed-loop FRFs are bounded and
% well-conditioned even at modest coherence). Estimate T over the binding band
% (~37 Hz here); add a small command dither if the operating signal does not
% excite that band.
%
% Inputs:
%   response : complex FRF samples, OR an LTI model (then freq_hz is required).
%   kind     : 'open' (response = L), 'comp' (response = T = output/command),
%              'sens' (response = S). Default 'open'.
%   freq_hz  : optional frequency vector [Hz] matching response (used to report the
%              binding frequency, and required if response is an LTI model).
%
% Output struct: ncf, binding_hz, peak_st_norm (= max_w sqrt(|S|^2+|T|^2)).

if nargin < 2 || isempty(kind), kind = 'open'; end
if nargin < 3, freq_hz = []; end

if isa(response, 'lti') || isa(response, 'tf') || isa(response, 'ss') ...
        || isa(response, 'frd') || isa(response, 'zpk')
    if isempty(freq_hz)
        error('estimate_ncf_direct:NeedFreq', ...
            'freq_hz is required when response is an LTI model.');
    end
    response = squeeze(freqresp(response, 2*pi*freq_hz(:)));
end
response = response(:);

switch lower(kind)
    case 'open'
        S = 1./(1 + response);
        T = response./(1 + response);
    case 'comp'
        T = response;
        S = 1 - T;
    case 'sens'
        S = response;
        T = 1 - S;
    otherwise
        error('estimate_ncf_direct:Kind', ...
            'kind must be ''open'', ''comp'', or ''sens''.');
end

st_norm = sqrt(abs(S).^2 + abs(T).^2);
[peak_st_norm, idx] = max(st_norm);
out.ncf = 1/(sqrt(2)*peak_st_norm);
out.peak_st_norm = peak_st_norm;
if ~isempty(freq_hz)
    freq_hz = freq_hz(:);
    out.binding_hz = freq_hz(min(idx, numel(freq_hz)));
else
    out.binding_hz = NaN;
end
end
