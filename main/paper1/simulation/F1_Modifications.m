%% pgeneral
% modified=1;
fprintf('Modified value: %d\n', modified);
if modified ==1  
    % 0 to run the original benchmark problem (simulink will adapt to this
    %  to use the original controller)
    m_e = m_e*1.3;
    ME = ME*1.3;
end
addpath("helper\")
k_factor = 1;
alpha=1;

%% new controller design
%% my_controller (for the modified benchmark)
% PID tracking controller
inner_sys = inner_open_loop2_with_params(m_e ,c_e, k_e);

opts = pidtuneOptions('PhaseMargin',60);
% [analog_cntrlr, info_a]= pidtune(inner_sys, 'PI', 30, opts);
analog_cntrlr= pid(1, 0, 0); 
analog_cl = feedback(analog_cntrlr*inner_sys, 1);

% Controller A
[digital_cntrlr, info_d] = pidtune(analog_cl, 'PI',80, opts);
digital_cl = feedback(digital_cntrlr*analog_cl, 1);

% Controller B
opts = pidtuneOptions('PhaseMargin',60);
[digital_cntrlr2, info_d] = pidtune(analog_cl, 'PI',60, opts);

%% Reference Model

M_r = ME+MN; 
K_r = KE+KN; 
C_r = CE+CN;

dof =3;
gamma_R = [0; 0; 0]; gamma_n = [1; 0; 0];  l = [1; 1; 1];  

AA_R = [zeros(dof)        eye(dof);
     -M_r\K_r         -M_r\C_r];

BB_R = [zeros(dof,1);
     -l];

CC_R = [ eye(dof)   zeros(dof);      % x
      zeros(dof) eye(dof);        % xdot
     -M_r\K_r   -M_r\C_r];        % xddot

DD_R = [zeros(2*dof,1);
     -l];

%% Lead Compensator Selection
% ==========================================================================

% OLD compensator (original from Controller file): G(s) = K*(s+z)/(s+p)
old_K = 50.8316336027;  old_zero = 168.6036181018;  old_pole = 8570.3973394443;

% NEW compensator (modify these to experiment)
new_K = 50.455;  new_zero = 85.965;  new_pole = 4035.9;

% Best Compensator found
best_K = 44.4745; best_zero = 81.21; best_pole = 3887.08;


% Select and discretize
if modified
    lead_K = new_K; lead_zero = new_zero; lead_pole = new_pole;
    disp('Using NEW lead compensator')
else
    lead_K = old_K; lead_zero = old_zero; lead_pole = old_pole;
    disp('Using OLD lead compensator (original)')
end
s = tf('s');
G_T_mod = lead_K * (s + lead_zero) / (s + lead_pole);
pre_ss_mod = ss(G_T_mod);
[Apred_mod, Bpred_mod, Cpred_mod, Dpred_mod] = c2dm(...
    pre_ss_mod.a, pre_ss_mod.b, pre_ss_mod.c, pre_ss_mod.d, dt_rths, 'tustin');
% ==========================================================================

%% Stiffness reduction factor in simulink
k_factor = 1;
%% List of modifications (coding)
% 1- I added this file
% 2- Added helper folder
% 3- F3_simulation model file
% 4- Simulink: Added new blockes and paths (no blocks were removed)
% 5- Added helper folder (essential for simulation)
% 6- Added sim_results and Stability Analysis folders (will not affect
%   simulations)
% 7- Added the lead compensator here to override the original one (the
%   state space model im simulink is modified by the new ones to return to
%   the original just remove _new)
% 8- F3_simulation is modified to be compatible with the new Matlab
%   version, and to run faster and toadapt with the changes in this file
%   and to store new indicator and alpha data


%% List of modifications (concept)
% 1- Reference model is simplified
% 2- mass is increased by 30%
% 3- new PI controller is designed
% 4- All the analysis and the paper Figures codes are inside in the 
%   Stability Analysis folder 






%% Useful codes
% pwelch(X_m.Data(:,1)*fs, [], [], [], fs);