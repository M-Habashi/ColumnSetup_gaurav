function beta = blk_beta_value( ...
        switchTarget, t, eventTime, startC, switchOn, transitionDuration)
%BLK_BETA_VALUE Linear-ramp controller blending for repeatable A/B switches.
% switchTarget is -1 before the first switch, 0 when transitioning to B,
% and 1 when transitioning to A.  beta=1 selects A and beta=0 selects B.

if nargin < 6
    transitionDuration = 0.25;
end

if strcmpi(startC, 'C')
    beta = NaN;
    return
end
startA = strcmpi(startC, 'A');
beta = double(startA);
if ~switchOn || switchTarget < 0
    return
end
blend = min(max((t - eventTime) / transitionDuration, 0), 1);
if switchTarget == 1
    beta = blend;
else
    beta = 1 - blend;
end
end
