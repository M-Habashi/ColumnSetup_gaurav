% Load Case_1.mat first
%% ----- Inputs you may tweak -----
alpha_instability = 0.23;
switching_limit = 0.35;
factors = 1:-0.01:0; 

%% ----- Specimen / plant params -----
mp = 37.8690;            % kg
kp = 1190000;            % N/m
zeta = 0.01;
cp = 2*zeta*sqrt(kp*mp); 

transfer_sys = inner_open_loop2_with_params(mp, cp, kp);

%% ----- Define controllers -----
opts = pidtuneOptions('PhaseMargin',60);
analog_cntrlr = pid(1,0,0);
analog_cl     = feedback(analog_cntrlr*transfer_sys, 1);

controllerA = pidtune(analog_cl, 'PI', 80, opts);   
controllerB = pidtune(analog_cl, 'PI', 62.5, opts); 

%% ----- Sweep alpha and compute NCF margins -----
ncfA = zeros(size(factors));
ncfB = zeros(size(factors));

for i = 1:numel(factors)
    a = factors(i);
    ki = a * kp;
    ci = 2*zeta*sqrt(ki*mp);
    Gcl_a = feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci, ki), 1);
    
    is_stable_A = isstable(feedback(controllerA*Gcl_a, 1));
    is_stable_B = isstable(feedback(controllerB*Gcl_a, 1));
    
    try
        mA = compute_ncfmargin(Gcl_a, controllerA);
    catch
        mA = ncfmargin(Gcl_a, controllerA);
    end
    try
        mB = compute_ncfmargin(Gcl_a, controllerB);
    catch
        mB = ncfmargin(Gcl_a, controllerB);
    end
    
    ncfA(i) = mA * double(is_stable_A);
    ncfB(i) = mB * double(is_stable_B);
end

%% ----- Plotting (mat_paper Style) -----
fig = figure('Units','inches','Position', [2, 2, 8.27, 4], 'Color', 'w');
ax = axes('Parent', fig, ...
    'FontName', 'Times New Roman', 'FontSize', 10, ...
    'TickLabelInterpreter', 'latex', ...
    'XDir', 'reverse', 'XLim', [0 1], ...
    'Box', 'on');

hold(ax, 'on');
grid(ax, 'on');

% Plot data with template colors
plot(factors, ncfA, 'Color', '#0c558e', 'LineWidth', 1.5); % Blue
plot(factors, ncfB, 'Color', '#a5347b', 'LineWidth', 1.5); % Purple

% Labels
xlabel('$\alpha$', 'Interpreter', 'latex');
ylabel('NCF margin ($b_g$)', 'Interpreter', 'latex');

% Legend with compatibility check for ItemTokenSize
lgd = legend({'Controller A', 'Controller B'}, ...
    'Location', 'northeast', ...
    'Interpreter', 'latex');
% Manual nudge: [left bottom width height] 
% We increase 'left' and 'bottom' values slightly to pin it to the edge
lgd.Units = 'normalized';
pos = lgd.Position;
pos(1) = 1 - pos(3)-0.086; % 0.01 is the margin from the right edge
pos(2) = 1 - pos(4)-0.082; % 0.01 is the margin from the top edge
lgd.Position = pos;


try
    lgd.ItemTokenSize = [20, 18];
catch
    % Property not supported in this MATLAB version; skipping.
end

% Vertical Markers (Grey #555555)
xline(alpha_instability, '--', 'Color', '#555555', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xline(switching_limit, '--', 'Color', '#555555', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Marker Labels
y_text = 0.8 * max([ncfA, ncfB]); 
text(alpha_instability, y_text, sprintf('TheoriticalInstability: $\\alpha = %.2f$', alpha_instability), ...
    'Interpreter', 'latex', 'FontName', 'Times New Roman', 'FontSize', 10, ...
    'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

text(switching_limit, y_text, sprintf('Switching Boundary: $\\alpha = %.2f$', switching_limit), ...
    'Interpreter', 'latex', 'FontName', 'Times New Roman', 'FontSize', 10, ...
    'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

% Output
script_path = mfilename('fullpath');
[script_dir, script_name] = fileparts(script_path);
output_file = fullfile(script_dir, [script_name '.png']);
drawnow;
exportgraphics(fig, output_file, 'Resolution', 1000);
