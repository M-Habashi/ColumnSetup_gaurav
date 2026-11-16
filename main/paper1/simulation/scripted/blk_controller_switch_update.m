function [activeA, switchTarget, eventTime, aboveStart, switched] = ...
        blk_controller_switch_update(activeA, switchTarget, eventTime, ...
        aboveStart, previousNcfA, ncfA, t, bThreshold, ...
        returnThreshold, returnHold, enabled)
%BLK_CONTROLLER_SWITCH_UPDATE Repeatable hysteretic A/B switch state.
% A switches to B on a downward crossing of bThreshold. While B is the
% active target, A's independently evaluated NCF must remain strictly above
% returnThreshold for returnHold continuous seconds before switching to A.

switched = false;
if ~enabled
    aboveStart = NaN;
    return
end

if activeA
    aboveStart = NaN;
    fallingHit = previousNcfA > bThreshold && ncfA <= bThreshold;
    if fallingHit
        activeA = false;
        switchTarget = 0;
        eventTime = t;
        switched = true;
    end
    return
end

if ncfA > returnThreshold
    if isnan(aboveStart)
        aboveStart = t;
    elseif t - aboveStart >= returnHold
        activeA = true;
        switchTarget = 1;
        eventTime = t;
        aboveStart = NaN;
        switched = true;
    end
else
    % The required interval must be continuous.
    aboveStart = NaN;
end
end
