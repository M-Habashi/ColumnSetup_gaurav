clear; clc; close all;

% === RESET PROGRESS BAR COUNTER ===
% This is crucial! It clears the memory of the helper function 
% so the percentage starts at 0% every time you run the script.
clear update_progress; 

% === Configuration ===
mp_spec = 37.8690; 
kp_spec = 1190000;  
xmin = 25; xmax = 60;
ymin = kp_spec*0.5; ymax = kp_spec*2;
num_points = 50;

% === Create Grid ===
x_vec = linspace(xmin, xmax, num_points);
y_vec = linspace(ymin, ymax, num_points);
[X, Y] = meshgrid(x_vec, y_vec);

% Flatten inputs for parallel loop
x_flat = X(:);
y_flat = Y(:);
z_flat = zeros(size(x_flat));
total_iters = numel(x_flat);

% === Setup Parallel Pool & Progress Bar ===
if isempty(gcp('nocreate')), parpool; end 

D = parallel.pool.DataQueue;
% Send the total number of iterations to the progress function first
afterEach(D, @(x) update_progress(x, total_iters));

fprintf('Simulation Progress: 000%%');

% === Compute Z Using Parallel Loop ===
parfor k = 1:total_iters
    % Call the optimized binary search function
    [alpha_val, ~] = loopy_degrade_optimized(x_flat(k), y_flat(k));
    z_flat(k) = alpha_val;
    
    % Send a dummy value to trigger the progress update
    send(D, k); 
end
fprintf('\nDone!\n');

% Reshape results back to matrix for plotting
Z = reshape(z_flat, length(y_vec), length(x_vec));

%% === Plotting Section (Now in Main Script) ===
fig = figure('Units','inches','Position',[1 1 8 5],'Color','w');
imagesc(x_vec, y_vec, Z);
set(gca,'YDir','normal');
axis tight;
clim([0.01 0.99]); % Updated from caxis

% --- Colormap ---
N = 10240;
baseMap = sky(N);
darkFactor = 1.02;
newMap = max(min(baseMap * darkFactor, 1), 0);
colormap(newMap);
cb = colorbar;

% --- Fonts & Labels ---
ax = gca;
set(ax,'FontName','Times New Roman','FontSize',10);
set(cb,'FontName','Times New Roman','FontSize',10);
xlabel('$m$ (kg)','Interpreter','latex', 'FontName','Times New Roman','FontSize',10);
ylabel('$k_o$ (N/m)','Interpreter','latex', 'FontName','Times New Roman','FontSize',10);

hold on;

% --- Contours ---
levels = 0.1:0.1:0.9;
[C,hc] = contour(x_vec, y_vec, Z, levels, 'LineColor','k', 'LineStyle','--', 'LineWidth',0.8);
clabel(C, hc, 'LabelSpacing', 500, 'FontName','Times New Roman','FontSize',10,'Color','k');
drawnow;

% --- Fix Contour Label Rotation ---
ht = findall(gca, 'Type', 'text');
targets = {'0.1','0.2','0.3'}; 
for i = 1:numel(ht)
    if ismember(ht(i).String, targets)
        ht(i).Rotation = ht(i).Rotation + 90;
    end
end

% --- Markers ---
m1 = mp_spec;      
m2 = mp_spec/1.3;    
k_plot = kp_spec;    
h1 = plot(m2, k_plot, 'kx', 'MarkerSize',10, 'LineWidth',1.5);
h2 = plot(m1, k_plot, 'k+', 'MarkerSize',10, 'LineWidth',1.5);

% --- Legend ---
lgd = legend([h1 h2], {'Original benchmark','Modified benchmark'}, ...
    'Location','northeast', 'FontName','Times New Roman','FontSize',10);
lgd.Color = [1 1 1];
lgd.EdgeColor = [0 0 0];
hold off;

script_path = mfilename('fullpath');
[script_dir, script_name] = fileparts(script_path);
output_file = fullfile(script_dir, [script_name '.png']);
drawnow;
exportgraphics(fig, output_file, 'Resolution', 800);


%% === Local Functions (Must be at the end of the file) ===

function update_progress(~, total_N)
    % Uses a persistent variable to remember count between calls
    persistent cnt
    if isempty(cnt)
        cnt = 0;
    end
    cnt = cnt + 1;
    
    pct = floor(cnt / total_N * 100);
    % Delete previous 4 characters (e.g. " 12%") and print new
    fprintf('\b\b\b\b%3d%%', pct);
end

function [alpha, omega] = loopy_degrade_optimized(mp, kp)
    % 1. Base Parameters
    omega = sqrt(kp/mp);
    zeta = 0.01;
    cp = 2 * zeta * mp * omega;
    
    % 2. Expensive Setup (Plant & Controller)
    transfer_sys = inner_open_loop2_with_params(mp, cp, kp);
    opts = pidtuneOptions('PhaseMargin', 60);
    analog_cntrlr = pid(1, 0, 0);  
    analog_cl = feedback(analog_cntrlr*transfer_sys, 1); 
    digital_cntrlr = pidtune(analog_cl, 'PI', 80, opts); 
    
    % 3. Optimized Binary Search
    low = 0; 
    high = 1;
    alpha = 0; 
    tol = 0.01; % Precision tolerance
    
    % Check nominal (factor = 1) first
    ki = 1 * kp;
    ci = 2*zeta*sqrt(1*kp*mp);
    sys = digital_cntrlr * feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci, ki), 1);
    if ~isstable(feedback(sys, 1))
        alpha = 1;
        return;
    end

    while (high - low) > tol
        mid = (low + high) / 2;
        
        ki = mid * kp;
        ci = 2*zeta*sqrt(mid*kp*mp);
        
        analog_cl_r = feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci, ki), 1);
        digital_cl_r = feedback(digital_cntrlr*analog_cl_r, 1);
        
        if ~isstable(digital_cl_r)
            % Unstable region found, search higher (closer to 1)
            low = mid; 
            alpha = mid; 
        else
            % Stable, search lower (closer to 0)
            high = mid; 
        end
    end
end
