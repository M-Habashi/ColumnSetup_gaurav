function b = osi_ncf_looponly(L)
%OSI_NCF_LOOPONLY Loop-only NCF margin = min normalized Nyquist distance.
% Identical definition to id_utils/custom_stability_margins.m:
%   b = min_w |1 + L| / sqrt( 2*(1 + |L|^2) )
% Input  L : complex loop response L(jw) sampled over the evaluation band.
% Output b : dimensionless margin in (0, 1/sqrt(2)].
    L = L(:);
    L = L(isfinite(L));
    if isempty(L)
        b = NaN; return
    end
    nd = abs(1 + L) ./ sqrt(2*(1 + abs(L).^2));
    b = min(nd);
end
