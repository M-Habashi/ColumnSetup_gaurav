function authFactor = osi_method_9_2_auth_factor(osiValue, targetNcf)
%OSI_METHOD_9_2_AUTH_FACTOR Direct OSI-to-authority trial law.
% Research-only Method 9.2: targetNcf is required, and authority is just the
% normalized OSI value clipped to the natural authority-factor range.

assert(nargin == 2 && isscalar(targetNcf) && isfinite(targetNcf) ...
    && targetNcf > 0, 'targetNcf must be a positive finite scalar.')

authFactor = osiValue./targetNcf;
authFactor(~isfinite(authFactor)) = NaN;
authFactor = min(1, max(0, authFactor));
end
