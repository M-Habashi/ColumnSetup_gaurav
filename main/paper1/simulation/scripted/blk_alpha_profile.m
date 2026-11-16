function alpha = blk_alpha_profile(t, alphaMin, alphaStart)
%BLK_ALPHA_PROFILE Time-varying experimental stiffness ratio.

if nargin < 3
    alphaStart = 1;
end
time = max(t, 0);
intermediateAlpha = min(0.75, alphaStart);
term1 = (alphaStart - intermediateAlpha) ./ ...
    (1 + exp(-2 .* (time - 8)));
term2 = (intermediateAlpha - alphaMin) ./ ...
    (1 + exp(-(time - 16)));
alpha = alphaStart - term1 - term2;
end
