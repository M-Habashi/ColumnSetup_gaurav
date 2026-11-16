function metrics = scripted_ncf_curve_metrics(p, controller, alpha)
%SCRIPTED_NCF_CURVE_METRICS Audit one PI over a stiffness-ratio vector.

arguments
    p (1,1) struct
    controller
    alpha (1,:) double {mustBeReal, mustBeFinite}
end
if any(alpha < 0 | alpha > 1) || any(diff(alpha) > 0)
    error('scripted:NCFAlphaGrid', ...
        'alpha must be a descending vector contained in [0, 1].')
end

p.controller_b = controller;
p.pi_b_kp = controller.Kp;
p.pi_b_ki = controller.Ki;
rawNCF = zeros(size(alpha));
stable = false(size(alpha));
for index = 1:numel(alpha)
    stiffness = alpha(index) * p.k_e;
    damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
    innerPlant = feedback(scripted_inner_open_loop( ...
        p.m_e, damping, stiffness), 1);
    stable(index) = isstable(feedback(controller * innerPlant, 1));
    rawNCF(index) = blk_indicator_margin(alpha(index), 0, p);
end
plottedNCF = rawNCF .* stable;
unstableIndex = find(~stable, 1, 'first');
if isempty(unstableIndex)
    collapseAlpha = NaN;
else
    collapseAlpha = alpha(unstableIndex);
end
[~, alphaPointOneIndex] = min(abs(alpha - 0.1));
increments = diff(plottedNCF);

metrics = struct( ...
    'Alpha', alpha, ...
    'RawNCF', rawNCF, ...
    'PlottedNCF', plottedNCF, ...
    'Stable', stable, ...
    'NCFAlpha1', plottedNCF(1), ...
    'NCFAlphaPointOne', plottedNCF(alphaPointOneIndex), ...
    'NCFAlphaZero', plottedNCF(end), ...
    'RawNCFAlphaZero', rawNCF(end), ...
    'CollapseAlpha', collapseAlpha, ...
    'MaximumIncreaseWithDegradation', max([0 increments]), ...
    'MonotonicDecrease', all(increments <= 2e-5));
end
