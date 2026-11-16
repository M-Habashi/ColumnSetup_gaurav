function result = theoretical
%THEORETICAL Calculate the critical stiffness ratio from the scripted Y(s).
%   THEORETICAL prints Y(s), omega_cr, and alpha_cr for Controller A from
%   the last completed SCRIPTED_MAIN run.
%
%   This is the scripted equivalent of Stability Analysis/theoritical_alpha.
%   It retains the continuous-time derivation: the printed Y(s) is the
%   continuous prototype, not the Tustin-discretized simulation model.

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir);

[lastRun, configurationPath] = ...
    scripted_last_run_configuration(projectRoot);
if isempty(lastRun)
    options = fallback_options;
    parameters = scripted_build_trial(options, projectRoot, 1);
    configurationSource = 'theoretical.m fallback settings';
else
    options = lastRun.Options;
    parameters = scripted_build_trial(options, projectRoot, 1);
    parameters = restore_controllers(parameters, lastRun);
    configurationSource = configurationPath;
end

controller = parameters.controller_a;

s = tf('s');
Ga1 = parameters.a1_beta0 / ...
    (s^2 + parameters.beta1 * s + parameters.beta2);
Ga2 = parameters.a2 * s;
Ga3 = 1 / (s + parameters.a3);
Ca = 1;                         % Unity analog controller in the benchmark.
Cd = controller;
Y = minreal(Ga3 * (Ga2 + Ca * Ga1 * (Cd + 1)), 1e-10);

mass = parameters.m_e;
stiffness = parameters.k_e;
zeta = parameters.z_e;
equation = @(omega) critical_equation(omega, Y, mass, stiffness, zeta);
omegaCritical = critical_frequency(equation);
YCritical = evalfr(Y, 1i * omegaCritical);
alphaCritical = imag(YCritical)^2 / ...
    (4 * zeta^2 * omegaCritical^2 * mass * stiffness);

fprintf('\nTheoretical critical-stiffness calculation (Controller A)\n')
fprintf('Configuration: %s\n', configurationSource)
print_pretty_transfer_function(Y)
fprintf('omega_cr = %.12g rad/s\n', omegaCritical)
fprintf('alpha_cr = %.12g\n\n', alphaCritical)

result = struct( ...
    'ControllerName', 'A', ...
    'Controller', controller, ...
    'Y', Y, ...
    'omega_cr', omegaCritical, ...
    'alpha_cr', alphaCritical, ...
    'Y_at_omega_cr', YCritical, ...
    'Options', options, ...
    'ConfigurationSource', configurationSource);
end

function value = critical_equation(omega, Y, mass, stiffness, zeta)
response = evalfr(Y, 1i * omega);
value = mass * omega^2 / stiffness - real(response) / stiffness - ...
    imag(response)^2 / (4 * zeta^2 * omega^2 * mass * stiffness);
end

function omegaCritical = critical_frequency(equation)
frequencyGrid = logspace(-1, 4, 20000);
residual = arrayfun(equation, frequencyGrid);
finite = isfinite(residual);
signChanges = find(finite(1:end-1) & finite(2:end) & ...
    residual(1:end-1) .* residual(2:end) <= 0);

if isempty(signChanges)
    error('scripted:TheoreticalNoCriticalFrequency', ...
        'No positive root for the theoretical critical-frequency equation was found.')
end

roots = nan(size(signChanges));
for index = 1:numel(signChanges)
    bracket = frequencyGrid(signChanges(index) + [0 1]);
    roots(index) = fzero(equation, bracket);
end
roots = roots(isfinite(roots) & roots > 0);
if isempty(roots)
    error('scripted:TheoreticalNoCriticalFrequency', ...
        'The critical-frequency equation did not converge to a positive root.')
end

% Retain the original script's intended branch (the root near 282.2 rad/s).
[~, selected] = min(abs(roots - 282.2));
omegaCritical = roots(selected);
end

function parameters = restore_controllers(parameters, configuration)
parameters.controller_a = controller_from_record(configuration.ControllerA);
parameters.controller_b = controller_from_record(configuration.ControllerB);
parameters.controller_c = controller_from_record(configuration.ControllerC);
parameters.pi_a_kp = parameters.controller_a.Kp;
parameters.pi_a_ki = parameters.controller_a.Ki;
parameters.pi_b_kp = parameters.controller_b.Kp;
parameters.pi_b_ki = parameters.controller_b.Ki;
parameters.pi_c_kp = parameters.controller_c.Kp;
parameters.pi_c_ki = parameters.controller_c.Ki;
end

function controller = controller_from_record(record)
controller = pid(record.Kp, record.Ki, record.Kd, record.Tf);
end

function print_pretty_transfer_function(system)
[numerator, denominator] = tfdata(system, 'v');
normalizer = denominator(1);
numerator = numerator / normalizer;
denominator = denominator / normalizer;

numeratorText = polynomial_text(numerator);
denominatorText = polynomial_text(denominator);
lineWidth = max(strlength(numeratorText), strlength(denominatorText));
numeratorPadding = floor((lineWidth - strlength(numeratorText)) / 2);
denominatorPadding = floor((lineWidth - strlength(denominatorText)) / 2);

fprintf('Y(s) used:\n')
fprintf('  Y(s) = %s%s\n', repmat(' ', 1, double(numeratorPadding)), ...
    numeratorText)
fprintf('         %s\n', repmat('-', 1, double(lineWidth)))
fprintf('         %s%s\n', repmat(' ', 1, double(denominatorPadding)), ...
    denominatorText)
fprintf('  LaTeX: $Y(s) = \\frac{%s}{%s}$\n', ...
    polynomial_latex(numerator), polynomial_latex(denominator))
fprintf('  %s\n', repmat('-', 1, double(lineWidth) + 10))
fprintf('  The LaTeX line above is normalized with a monic denominator.\n')
end

function text = polynomial_text(coefficients)
text = polynomial_format(coefficients, false);
end

function text = polynomial_latex(coefficients)
text = polynomial_format(coefficients, true);
end

function text = polynomial_format(coefficients, useLatex)
order = numel(coefficients) - 1;
terms = strings(0, 1);
for index = 1:numel(coefficients)
    coefficient = coefficients(index);
    if abs(coefficient) <= 100 * eps(max(1, max(abs(coefficients))))
        continue
    end
    power = order - index + 1;
    magnitude = string(coefficient_text(abs(coefficient), useLatex));
    variable = string(power_text(power, useLatex));
    if power > 0 && abs(abs(coefficient) - 1) < 1e-10
        term = variable;
    else
        term = magnitude + variable;
    end
    if isempty(terms)
        if coefficient < 0
            term = "-" + term;
        end
    elseif coefficient < 0
        term = " - " + term;
    else
        term = " + " + term;
    end
    terms(end + 1, 1) = term; %#ok<AGROW>
end
if isempty(terms)
    text = '0';
else
    text = char(join(terms, ''));
end
end

function text = coefficient_text(value, useLatex)
exponent = floor(log10(value));
if abs(exponent) >= 3
    mantissa = value / 10^exponent;
    if useLatex
        text = sprintf('%.4g\\times 10^{%d}', mantissa, exponent);
    else
        text = sprintf('%.4g*10^%d', mantissa, exponent);
    end
else
    text = sprintf('%.4g', value);
end
end

function text = power_text(power, useLatex)
if power == 0
    text = '';
elseif power == 1
    text = 's';
elseif useLatex
    text = sprintf('s^{%d}', power);
else
    text = sprintf('s^%d', power);
end
end

function options = fallback_options
[targetNCF, targetAlpha] = scripted_controller_c_settings;
options = struct( ...
    'Building_c', 1, 'plot_on', 'n', 'modified', 1, ...
    'consider_damage', 1, 'alpha_start', 1, 'alpha_min', 0.5, ...
    'b_th', 0.13, 'num_add', 0, 'enable_indicator_plot', 0, ...
    'test_name', 'None', 'fs', 4096, ...
    'bw_a', 70, 'pm_a', 70, 'bw_b', 55, 'pm_b', 55, ...
    'bw_c', 40, 'pm_c', 60, 'target_ncf_c', targetNCF, ...
    'target_ncf_c_alpha', targetAlpha, 'start_c', 'A', 'switch_on', 0);
end
