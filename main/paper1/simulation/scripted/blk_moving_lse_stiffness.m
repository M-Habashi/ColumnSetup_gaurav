function [alpha, stiffness, state] = blk_moving_lse_stiffness( ...
        displacement, force, state, p)
%BLK_MOVING_LSE_STIFFNESS Causal rolling F = k*d + c stiffness fit.
%   The centered least-squares slope removes a constant force offset. The
%   estimate starts at the configured initial stiffness and is held until a
%   full window has a displacement standard deviation of at least 5% of u_y.
%   It also holds the last valid estimate whenever excitation later falls
%   below that threshold.

if isempty(state)
    window = p.lse_window_samples;
    state = struct( ...
        'DisplacementBuffer', zeros(window, 1), ...
        'ForceBuffer', zeros(window, 1), ...
        'Cursor', 1, ...
        'Count', 0, ...
        'DisplacementSum', 0, ...
        'ForceSum', 0, ...
        'DisplacementSquaredSum', 0, ...
        'DisplacementForceSum', 0, ...
        'Alpha', p.alpha_start, ...
        'Stiffness', p.alpha_start * p.k_e);
end

index = state.Cursor;
if state.Count >= p.lse_window_samples
    oldDisplacement = state.DisplacementBuffer(index);
    oldForce = state.ForceBuffer(index);
    state.DisplacementSum = state.DisplacementSum - oldDisplacement;
    state.ForceSum = state.ForceSum - oldForce;
    state.DisplacementSquaredSum = state.DisplacementSquaredSum - ...
        oldDisplacement ^ 2;
    state.DisplacementForceSum = state.DisplacementForceSum - ...
        oldDisplacement * oldForce;
else
    state.Count = state.Count + 1;
end

state.DisplacementBuffer(index) = displacement;
state.ForceBuffer(index) = force;
state.DisplacementSum = state.DisplacementSum + displacement;
state.ForceSum = state.ForceSum + force;
state.DisplacementSquaredSum = state.DisplacementSquaredSum + ...
    displacement ^ 2;
state.DisplacementForceSum = state.DisplacementForceSum + ...
    displacement * force;
state.Cursor = state.Cursor + 1;
if state.Cursor > p.lse_window_samples
    state.Cursor = 1;
end

centeredDisplacement = state.DisplacementSquaredSum - ...
    state.DisplacementSum ^ 2 / state.Count;
centeredCrossProduct = state.DisplacementForceSum - ...
    state.DisplacementSum * state.ForceSum / state.Count;
displacementVariance = centeredDisplacement / max(state.Count - 1, 1);
minimumDisplacementStd = 0.05 * p.u_y;
if state.Count >= p.lse_window_samples && ...
        displacementVariance >= minimumDisplacementStd ^ 2 && ...
        centeredDisplacement > 0
    candidate = centeredCrossProduct / centeredDisplacement;
    if isfinite(candidate)
        state.Stiffness = candidate;
        state.Alpha = max(0.001, min(1, candidate / p.k_e));
    end
end

alpha = state.Alpha;
stiffness = state.Stiffness;
end
