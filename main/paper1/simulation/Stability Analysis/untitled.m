clear; clc; close all;

clear update_progress;

% === Configuration ===
mp_spec = 37.8690; 
kp_spec = 1190000;  

% ---- frequency range in Hz instead of mass ----
fmin = 20;     % choose suitable Hz limits
fmax = 40;
ymin = kp_spec*0.5; 
ymax = kp_spec*2;
num_points = 50;

% === Reference frequencies for markers ===
fn1 = (1/(2*pi))*sqrt(kp_spec/mp_spec);          % original benchmark
fn2 = (1/(2*pi))*sqrt(kp_spec/(mp_spec/1.3));    % modified benchmark

% === Create Grid ===
f_vec = linspace(fmin, fmax, num_points);
y_vec = linspace(ymin, ymax, num_points);
[F, Y] = meshgrid(f_vec, y_vec);

% Flatten inputs for parallel loop
f_flat = F(:);
y_flat = Y(:);
z_flat = zeros(size(f_flat));
total_iters = numel(f_flat);

% === Setup Parallel Pool & Progress Bar ===
if isempty(gcp('nocreate')), parpool; end 

D = parallel.pool.DataQueue;
afterEach(D, @(x) update_progress(x, total_iters));

fprintf('Simulation Progress: 000%%');

% === Compute Z Using Parallel Loop ===
parfor k = 1:total_iters
    fn = f_flat(k);           % natural frequency in Hz
    kp = y_flat(k);           % stiffness
    
    omega_n = 2*pi*fn;        % rad/s
    mp = kp / omega_n^2;      % convert (fn, kp) -> mass
    
    [alpha_val, ~] = loopy_degrade_optimized(mp, kp);
    z_flat(k) = alpha_val;
    
    send(D, k); 
end
fprintf('\nDone!\n');

% Reshape results back to matrix for plotting
Z = reshape(z_flat, length(y_vec), length(f_vec));

%% === Plotting Section ===
fig = figure('Units','inches','Position',[1 1 8 5],'Color','w');
imagesc(f_vec, y_vec, Z);
set(gca,'YDir','normal');
axis tight;
clim([0.01 0.99]);

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
xlabel('$f_n$ (Hz)','Interpreter','latex', 'FontName','Times New Roman','FontSize',10);
ylabel('$k_o$ (N/m)','Interpreter','latex', 'FontName','Times New Roman','FontSize',10);

hold on;

% --- Contours ---
levels = 0.1:0.1:0.9;
[C,hc] = contour(f_vec, y_vec, Z, levels, 'LineColor','k', 'LineStyle','--', 'LineWidth',0.8);
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
k_plot = kp_spec;    
h1 = plot(fn1, k_plot, 'kx', 'MarkerSize',10, 'LineWidth',1.5);
h2 = plot(fn2, k_plot, 'k+', 'MarkerSize',10, 'LineWidth',1.5);

% --- Legend ---
lgd = legend([h1 h2], {'Original benchmark','Modified benchmark'}, ...
    'Location','northeast', 'FontName','Times New Roman','FontSize',10);
lgd.Color = [1 1 1];
lgd.EdgeColor = [0 0 0];
hold off;

copygraphics(fig,'ContentType','image','Resolution',300);

%% === Local Functions ===

function update_progress(~, total_N)
    persistent cnt
    if isempty(cnt)
        cnt = 0;
    end
    cnt = cnt + 1;
    
    pct = floor(cnt / total_N * 100);
    fprintf('\b\b\b\b%3d%%', pct);
end

function [alpha, omega] = loopy_degrade_optimized(mp, kp)
    omega = sqrt(kp/mp);
    zeta = 0.01;
    cp = 2 * zeta * mp * omega;
    
    transfer_sys = inner_open_loop2_with_params(mp, cp, kp);
    opts = pidtuneOptions('PhaseMargin', 60);
    analog_cntrlr = pid(1, 0, 0);  
    analog_cl = feedback(analog_cntrlr*transfer_sys, 1); 
    digital_cntrlr = pidtune(analog_cl, 'PI', 80, opts); 
    
    low = 0; 
    high = 1;
    alpha = 0; 
    tol = 0.01;
    
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
            low = mid; 
            alpha = mid; 
        else
            high = mid; 
        end
    end
end