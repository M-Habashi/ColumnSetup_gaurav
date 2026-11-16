include_bg = false; % Set to false to hide bg plot

%% Run RUN_vRTHS_demo first and add this folder to tha path
% Load Case_1.mat first
%% specimen
mp = 37.8690; %kg
kp = 1190000;  %N/m
zeta = 0.01;
cp = 2*zeta*sqrt(kp*mp); %N.s/m
%% Numerical system (needed for margin 1 only)
m_e     = mp;
k_e     = kp;
z_e     = zeta; 
n=3;
ME = zeros(n);
ME(1,1) = m_e;
KE      = zeros(n);
KE(1,1) = k_e;
CE = zeros(n);
c_e = 2*z_e*m_e*sqrt(KE(1,1)/m_e);
CE(1,1) = c_e;
% NUMERICAL SUBSTRUCTURE
MN = M-ME;
KN = K-KE;
CN = C-CE;   
% State Space form  
iota = ones(n,1);
A_ns = [...
    zeros(n) eye(n);
    -MN\KN -MN\CN];
B_ns = [...
    zeros(n,1)      zeros(n); 
    -(MN\M)*iota    -inv(MN)];
C_ns = [...
    eye(n)              zeros(n);
    zeros(n)            eye(n);
    -MN\KN              -MN\CN];
D_ns = [...
    zeros(n,1)            zeros(n); 
    zeros(n,1)            zeros(n); 
    (-MN\M + eye(n))*iota    -inv(MN)];     % for TOTAL acc
sys_num = ss(A_ns,B_ns,C_ns,D_ns);
%%%%
%% original system
transfer_sys = inner_open_loop2_with_params(mp ,cp, kp);
opts = pidtuneOptions('PhaseMargin',60);
% [analog_cntrlr, info_a]= pidtune(transfer_sys, 'PI', 50, opts);
analog_cntrlr= pid(1, 0, 0); 
analog_cl = feedback(analog_cntrlr*transfer_sys, 1);
[digital_cntrlr, info_d] = pidtune(analog_cl, 'PI',80, opts);
[digital_cntrlr2, info_d] = pidtune(analog_cl, 'PI',62.5, opts);
% digital_cntrlr= pid(2, 95, 0); 
digital_cl = feedback(digital_cntrlr*analog_cl, 1);
%% one iteration example
factor = 0.4;
analog_cl_r_ex = feedback(analog_cntrlr*inner_open_loop2_with_params(mp, cp, factor*kp), 1);  % only change from loop to another is factor
digital_cl_r_ex = feedback(digital_cntrlr*analog_cl_r_ex, 1);
margin_ex = compute_ncfmargin(analog_cl, digital_cntrlr);
gap_ex = gapmetric(analog_cl, analog_cl_r_ex);
step(digital_cl, digital_cl_r_ex)
%% Loop Through Stiffness Factors and Compute Margins
% Define the vector of stiffness factors to test (from 0 to 1)
factors = 1:-0.01:0;
% Pre-allocate an array to store the margin results for efficiency
margins = zeros(size(factors));
margins1 = zeros(size(factors));
margins2 = zeros(size(factors));
margins3 = zeros(size(factors));
margins4 = zeros(size(factors));
margins5 = zeros(size(factors));
% Loop over each factor
n = size(C_ns,1); AA_p = zeros(n); BB_p = eye(n); CC_p = zeros(1,n); 
for i = 1:length(factors)
    current_factor = factors(i);
    ki = current_factor * kp;
    ci = 2*zeta*sqrt(current_factor*kp*mp);
    analog_cl_r = feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci, ki), 1);
    sys = digital_cntrlr*analog_cl_r;
    digital_cl_r = feedback(sys, 1);
    % profile on
    gain_phase_margins = allmargin(sys);
    dm = min(gain_phase_margins.DelayMargin)*gain_phase_margins.Stable;
    ncfmargin_value = compute_ncfmargin(analog_cl_r, digital_cntrlr); % user defined
    ncfmargin_value = ncfmargin(analog_cl_r, digital_cntrlr); % built-in
    isstable(feedback(sys, 1));
    ncfmargin_value = compute_ncfmargin(analog_cl_r, digital_cntrlr)*isstable(feedback(sys, 1));
    % profile viewer
    % profile off
    % Numerical Stability
    %n_p for numerical physical, minreal is essential for stability check,
    %evalc to silent the mireal function
    DD_p = [ki 0 0 ci 0 0 mp 0 0];
    ss_phy = ss(AA_p,BB_p, CC_p, DD_p); 
    ss_comb = series(sys_num, -ss_phy);
    temp = evalc('n_p_sys = minreal(ss_comb(:,2));');
    margins1(i) = min([min(allmargin(n_p_sys).DelayMargin)*allmargin(n_p_sys).Stable, inf]);
    margins2(i) = min([min(allmargin(sys).DelayMargin)*allmargin(sys).Stable, inf]);
    margins3(i) = min([min(allmargin(n_p_sys).GainMargin)*allmargin(n_p_sys).Stable, inf]); %ignore this one
    margins4(i) = min([db(min(allmargin(sys).GainMargin))*allmargin(sys).Stable, inf]);
    margins5(i) = ncfmargin_value;
    margins(i) = margins2(i);
end
%% Plotting the Results (Formatted for Single Column Manuscript / Review Draft)
% Dimensions: 6.5 inches is standard text width (8.5" page - 2x1" margins)
fig_width = 8.27; 
fig_height = 4; % Aspect ratio approx 1.6 (Golden ratio-ish)
% === 1) Figure & Axes setup ===
fig = figure('Units','inches','Position',[5 5 fig_width fig_height],'Color','w');
ax  = axes('Parent',fig, ...
    'XDir','reverse', 'XLim',[0 1], 'YLim',[0 2], ...           
    'YTick',0:0.2:2, ...                                        % Higher tick density for wider plot
    'TickLabelInterpreter','latex', ...
    'FontName', 'Times New Roman', 'FontSize', 10, ...          % 10pt Times New Roman
    'GridColor',[0.7 0.7 0.7],'GridLineStyle','--','GridAlpha',1, ... 
    'LineWidth',0.5,'Box','on','Layer','bottom');                    
grid(ax,'on'); hold(ax,'on');
% === 2) Curves ===
ls = {'LineStyle','-','LineWidth',1.5}; 
plot(ax,factors, margins1./margins1(1), ls{:}, 'Color','#555555');
plot(ax,factors, margins2./margins2(1), ls{:}, 'Color','#0c558e');
plot(ax,factors, margins4./margins4(1), ls{:}, 'Color','#a5347b');

% Logic for including bg
legend_labels = {'${\tau_{cr,N}}$','${\tau_{cr,P}}$','${GM_{P}}$'};
if include_bg
    plot(ax,factors, margins5./margins5(1), ls{:}, 'Color','#318C12'); 
    legend_labels{end+1} = '${b_{g}}$';
end

% === 3) Title, labels, legend ===
xlabel(ax,'$\bf{\alpha}$','Interpreter','latex','FontName','Times New Roman','FontSize',10);
ylabel(ax,'Normalized Stability Indicator ($SI_{\alpha}/SI_{\alpha=1}$)', ... 
       'Interpreter','latex','FontName','Times New Roman','FontSize',10);
% Legend
lgd = legend(ax, legend_labels, ...
       'Interpreter','latex','FontName','Times New Roman','FontSize',10,'Location','northeast');
lgd.ItemTokenSize = [20, 18]; % Standard token size for wider plot
% === 4) Instability marker & annotation ===
alpha_instability = 0.23;
xline(ax,alpha_instability,'--','Color','k','LineWidth',1.5,'HandleVisibility','off');
text(ax,0.245,1.1,'Instability at $\alpha = 0.23$', ...
     'Rotation',90,'Color','k','FontName','Times New Roman','FontSize',10,'Interpreter','latex');
hold(ax,'off');
% === 5) Export PNG ===
script_path = mfilename('fullpath');
[script_dir, script_name] = fileparts(script_path);
output_file = fullfile(script_dir, [script_name '.png']);

exportgraphics(fig, output_file, 'Resolution', 800);
%% Alpha theoritical Solution
