%% Comparison of LQR and PID Controllers
% Load Case_1.mat first 
 
mp = 37.8690;  kp = 1190000;  zeta = 0.01; 
cp = 2*zeta*sqrt(kp*mp); 
 
transfer_sys = inner_open_loop2_with_params(mp, cp, kp); 
opts = pidtuneOptions('PhaseMargin', 60); 
 
analog_cntrlr = pid(1, 0, 0);  
analog_cl = feedback(analog_cntrlr*transfer_sys, 1); 
 
digital_cntrlr = pidtune(analog_cl, 'PI', 80, opts); 
 
factors = 1:-0.01:0; 
bg_margin_pid = zeros(size(factors)); 
bg_margin_lqr = zeros(size(factors));

% Store healthy structure systems for step response comparison
healthy_idx = 1; % alpha = 1 (first iteration)

% Calculate K_lqr once for the healthy structure (alpha = 1)
ki_healthy = kp; 
ci_healthy = 2*zeta*sqrt(ki_healthy*mp); 
analog_cl_healthy = feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci_healthy, ki_healthy), 1); 
[Aacl_h, Bacl_h, Cacl_h, Dacl_h] = tf2ss(analog_cl_healthy.num{1,1}, analog_cl_healthy.den{1,1}); 
analog_cl_healthy_ss = ss(Aacl_h, Bacl_h, Cacl_h, Dacl_h); 
Q = 5; 
R = 1; 
K_lqr = lqry(analog_cl_healthy_ss, Q, R); % K_lqr computed once and fixed

for i = 1:length(factors) 
    ki = factors(i) * kp; 
    ci = 2*zeta*sqrt(ki*mp); 
    analog_cl_r = feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci, ki), 1); 
    sys = digital_cntrlr * analog_cl_r; 
    
    % PID margin
    bg_margin_pid(i) = ncfmargin(analog_cl_r, digital_cntrlr) * isstable(feedback(sys, 1)); 
 
    %% LQR controller (using fixed K_lqr from healthy structure)
    [Aacl, Bacl, Cacl, Dacl] = tf2ss(analog_cl_r.num{1,1}, analog_cl_r.den{1,1}); 
    kdc = 1/dcgain(ss(Aacl-Bacl*K_lqr, Bacl, Cacl, Dacl)); 
     
    %% Reduce the system 
    A_reduced = Aacl - Bacl*K_lqr; 
    B_reduced = Bacl(:, 1); 
    C_reduced = Cacl(1, :); 
    D_reduced = Dacl(1, 1); 
     
    reduced_ss = ss(A_reduced, B_reduced, C_reduced, D_reduced); 
    
    % LQR margin
    bg_margin_lqr(i) = ncfmargin(reduced_ss, 1) * isstable(reduced_ss);
    
    % Store healthy structure systems (alpha = 1)
    if i == healthy_idx
        pid_healthy_sys = feedback(sys, 1);
        lqr_healthy_sys = kdc * reduced_ss;
    end
end 


%% Figure 1: Margin Comparison (LQR vs PID)
script_path = mfilename('fullpath');
[script_dir, script_name] = fileparts(script_path);

fig1 = figure('Units', 'pixels', 'Position', [150 150 1100 600], 'Color', 'w'); 
ax1 = axes('XDir', 'reverse', 'XLim', [0 1], ... 
    'TickLabelInterpreter', 'latex', 'FontSize', 14, ... 
    'GridColor', [0.7 0.7 0.7], 'GridLineStyle', '--', 'GridAlpha', 1, ... 
    'LineWidth', 0.5, 'Box', 'on', 'Layer', 'bottom'); 
grid on; hold on; 
 
plot(ax1, factors, bg_margin_pid, '-', 'LineWidth', 2, 'Color', '#020b21', 'DisplayName', 'PID'); 
plot(ax1, factors, bg_margin_lqr, '-', 'LineWidth', 2, 'Color', '#d62728', 'DisplayName', 'LQR'); 

title('Stability Margin Comparison: PID vs LQR', 'FontSize', 14, 'Interpreter', 'latex'); 
xlabel('$\bf{\alpha}$', 'Interpreter', 'latex', 'FontSize', 14); 
ylabel('$b_{g}$ (unnormalized)', 'Interpreter', 'latex', 'FontSize', 14); 
legend('Interpreter', 'latex', 'FontSize', 14, 'Location', 'northeast'); 
 
hold off;

output_file1 = fullfile(script_dir, [script_name '.png']);
drawnow;
exportgraphics(fig1, output_file1, 'Resolution', 800);

%% Figure 2: Step Response Comparison for Healthy Structure (alpha = 1)
fig2 = figure('Units', 'pixels', 'Position', [200 200 1100 600], 'Color', 'w'); 
ax2 = axes('TickLabelInterpreter', 'latex', 'FontSize', 14, ... 
    'GridColor', [0.7 0.7 0.7], 'GridLineStyle', '--', 'GridAlpha', 1, ... 
    'LineWidth', 0.5, 'Box', 'on'); 
grid on; hold on; 

% Plot step responses
[y_pid, t_pid] = step(pid_healthy_sys);
[y_lqr, t_lqr] = step(lqr_healthy_sys);

plot(ax2, t_pid, y_pid, '-', 'LineWidth', 2, 'Color', '#020b21', 'DisplayName', 'PID'); 
plot(ax2, t_lqr, y_lqr, '-', 'LineWidth', 2, 'Color', '#d62728', 'DisplayName', 'LQR'); 

title('Step Response Comparison: Healthy Structure ($\alpha = 1$)', 'FontSize', 14, 'Interpreter', 'latex'); 
xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 14); 
ylabel('Response', 'Interpreter', 'latex', 'FontSize', 14); 
legend('Interpreter', 'latex', 'FontSize', 14, 'Location', 'best'); 

hold off;

output_file2 = fullfile(script_dir, [script_name, '_step.png']);
drawnow;
exportgraphics(fig2, output_file2, 'Resolution', 800);

