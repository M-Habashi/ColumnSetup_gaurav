function results = scripted_controller_characteristics_table(p, maximumCommand)
%SCRIPTED_CONTROLLER_CHARACTERISTICS_TABLE Report achieved local PI data.
%   Bandwidth is the lowest-frequency open-loop unity-gain crossover, which
%   is the crossover targeted by pidtune for A and B. Phase margin is taken
%   at that same crossover. A and B use the alpha_start tracking plant; C
%   uses the tracking plant at target_ncf_c_alpha. All values are achieved
%   values, rather than requested tuning inputs. maximumCommand contains
%   saved max(abs(PI output)) displacement-demand values in millimetres.

if nargin < 2
    maximumCommand = nan(3, 1);
end
if ~isnumeric(maximumCommand) || ~isreal(maximumCommand) || ...
        ~isequal(size(maximumCommand), [3, 1]) || ...
        any(isinf(maximumCommand)) || ...
        any(maximumCommand(~isnan(maximumCommand)) < 0)
    error('scripted:CommandMaximum', ...
        'maximumCommand must be a 3-by-1 nonnegative vector allowing NaN.')
end

controllerNames = ["A"; "B"; "C"];
controllers = {p.controller_a; p.controller_b; p.controller_c};
evaluationAlpha = [p.alpha_start; p.alpha_start; ...
    p.target_ncf_c_alpha];
pGain = nan(3, 1);
iGain = nan(3, 1);
bandwidth = nan(3, 1);
phaseMargin = nan(3, 1);

for controllerIndex = 1:3
    controller = controllers{controllerIndex};
    pGain(controllerIndex) = controller.Kp;
    iGain(controllerIndex) = controller.Ki;

    innerSystem = scripted_inner_open_loop(p.m_e, p.c_e, ...
        evaluationAlpha(controllerIndex) * p.k_e);
    trackingPlant = feedback(innerSystem, 1);
    allMargins = allmargin(controller * trackingPlant);
    crossoverFrequencies = allMargins.PMFrequency(:);
    phaseMargins = allMargins.PhaseMargin(:);
    validCrossovers = isfinite(crossoverFrequencies) & ...
        crossoverFrequencies > 0 & isfinite(phaseMargins);
    if any(validCrossovers)
        crossoverFrequencies = crossoverFrequencies(validCrossovers);
        phaseMargins = phaseMargins(validCrossovers);
        [bandwidth(controllerIndex), selectedIndex] = ...
            min(crossoverFrequencies);
        phaseMargin(controllerIndex) = phaseMargins(selectedIndex);
    end
end

fprintf('\nLocal PI controller characteristics\n')
fprintf(['Bandwidth is the lowest unity-gain crossover [rad/s]. A/B are ', ...
    'evaluated at alpha_start = %.3g; C at target_ncf_c_alpha = %.3g.\n'], ...
    p.alpha_start, p.target_ncf_c_alpha)
fprintf(['Higher-frequency resonance crossings are excluded from this ', ...
    'tracking-bandwidth table.\n'])
if any(isnan(maximumCommand))
    fprintf(['NaN PI-command values mean no matching saved pure-controller ', ...
        'simulation is available yet.\n'])
end

results = table(controllerNames, pGain, iGain, bandwidth, phaseMargin, ...
    maximumCommand, ...
    'VariableNames', {'Controller', 'P_gain', 'I_gain', ...
    'Bandwidth_rad_s', 'PhaseMargin_deg', ...
    'MaxPICommandDisplacement_mm'});
disp(results)
end
