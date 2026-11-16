function p = scripted_build_trial(options, projectRoot, trialIndex)
%SCRIPTED_BUILD_TRIAL Reproduce F1/F2 setup, including ordering quirks.

fs = options.fs;
dt = 1 / fs;
caseFile = fullfile(projectRoot, 'Building cases', ...
    sprintf('Case_%d.mat', options.Building_c));
caseData = load(caseFile);

p = struct;
p.options = options;
p.project_root = projectRoot;
p.fs = fs;
p.dt_rths = dt;
if isfield(options, 'alpha_start')
    p.alpha_start = options.alpha_start;
else
    p.alpha_start = 1;
end
if options.consider_damage == 1
    p.alpha_min = options.alpha_min;
else
    % alpha_min is not part of no-damage or degrading Bouc-Wen modes.
    p.alpha_min = p.alpha_start;
end
p.post_yield_ratio = option_or_default(options, 'post_yield_ratio', 0.001);
p.n_bw = option_or_default(options, 'n', 8);
p.u_y_mm = option_or_default(options, 'u_y', 1.25);
p.u_y = p.u_y_mm / 1000;
p.sigma = option_or_default(options, 'sigma', 0.769230769230769);
p.beta_b_per_mm_n = p.sigma / p.u_y_mm ^ p.n_bw;
p.gamma_b_per_mm_n = (1 - p.sigma) / p.u_y_mm ^ p.n_bw;
p.beta_b = p.beta_b_per_mm_n * 1000 ^ p.n_bw;
p.gamma_b = p.gamma_b_per_mm_n * 1000 ^ p.n_bw;
p.delta_nu_per_mm2 = option_or_default(options, 'delta_nu', 0.05);
p.delta_eta_per_mm2 = option_or_default(options, 'delta_eta', 0.011);
p.reference_delta_nu_per_mm2 = option_or_default(options, ...
    'reference_delta_nu', p.delta_nu_per_mm2);
p.reference_delta_eta_per_mm2 = option_or_default(options, ...
    'reference_delta_eta', p.delta_eta_per_mm2);
p.delta_nu = 1e6 * p.delta_nu_per_mm2;
p.delta_eta = 1e6 * p.delta_eta_per_mm2;
p.reference_delta_nu = 1e6 * p.reference_delta_nu_per_mm2;
p.reference_delta_eta = 1e6 * p.reference_delta_eta_per_mm2;
p.q_damage = option_or_default(options, 'q', 6);
p.lse_window = option_or_default(options, 'lse_window', 1);
p.lse_window_samples = round(p.lse_window * p.fs);
if options.modified == 1
    defaultLeadGain = 31.6431547;
    defaultLeadZero = 49.3502225;
    defaultLeadPole = 1657.846121;
else
    defaultLeadGain = 50.8316336027;
    defaultLeadZero = 168.6036181018;
    defaultLeadPole = 8570.3973394443;
end
p.lead_gain = option_or_default(options, 'lead_gain', defaultLeadGain);
p.lead_zero = option_or_default(options, 'lead_zero', defaultLeadZero);
p.lead_pole = option_or_default(options, 'lead_pole', defaultLeadPole);
if isfield(options, 'target_ncf_c')
    p.target_ncf_c = options.target_ncf_c;
else
    p.target_ncf_c = 0.46;
end
if isfield(options, 'target_ncf_c_alpha')
    p.target_ncf_c_alpha = options.target_ncf_c_alpha;
else
    p.target_ncf_c_alpha = p.alpha_start;
end
p.start_c = upper(char(options.start_c));
p.start_a = p.start_c == 'A';
p.use_c = p.start_c == 'C';
p.switch_on = logical(options.switch_on);
p.switch_transition_duration = option_or_default( ...
    options, 'switch_transition_duration', 0.25);
p.b_th = options.b_th;
p.b_th_2 = option_or_default(options, 'b_th_2', 0.15);
p.switch_back_hold = option_or_default(options, 'switch_back_hold', 2);
p.M = caseData.M;
p.K = caseData.K;
p.C = caseData.C;
p.n = caseData.n;
p.nom = double(trialIndex > 1);

p.eq_intensity = 0.4;
p.E_sw = 1;
p.f_ini = 0;
p.f_end = 10;

switch p.E_sw
    case 1
        ground = load(fullfile(projectRoot, 'ElCentroAccelNoScaling.mat'));
        p.ground_record = ground.ElCentroAccel;
    case 2
        ground = load(fullfile(projectRoot, 'KobeAccelNoScaling.mat'));
        p.ground_record = ground.KobeAccel;
    case 3
        ground = load(fullfile(projectRoot, 'MorganAccelNoScaling.mat'));
        p.ground_record = ground.MorganAccel;
    otherwise
        p.f_ini = 0.1;
        p.f_end = 40;
        p.tend = 90;
        p.ground_record = [];
end
if p.E_sw <= 3
    p.tend = p.ground_record(1, end);
end

p.m_e = 29.13;
p.k_e = 1190e3;
p.z_e = 0.0097;
p.ME = zeros(p.n);
p.ME(1, 1) = p.m_e;
p.KE = zeros(p.n);

if trialIndex == 1
    savedRng = rng(123);
else
    savedRng = rng('shuffle');
end
p.KE(1, 1) = p.k_e + 50e3 * p.nom * randn(1, 1);
p.k_x_specimen = p.post_yield_ratio * ...
    p.alpha_start * p.k_e;
p.k_w_specimen = (1 - p.post_yield_ratio) * ...
    p.alpha_start * p.k_e;
p.k_x_reference = p.post_yield_ratio * ...
    p.alpha_start * p.KE(1, 1);
p.k_w_reference = (1 - p.post_yield_ratio) * ...
    p.alpha_start * p.KE(1, 1);
p.c_e = 2 * p.z_e * p.m_e * sqrt(p.KE(1, 1) / p.m_e);
p.CE = zeros(p.n);
p.CE(1, 1) = p.c_e;

% These are intentionally constructed before the optional 30% mass change.
p.MN = p.M - p.ME;
p.KN = p.K - p.KE;
p.CN = p.C - p.CE;
iota = ones(p.n, 1);
p.A_ns = [zeros(p.n), eye(p.n); -p.MN \ p.KN, -p.MN \ p.CN];
p.B_ns = [zeros(p.n, 1), zeros(p.n); ...
    -(p.MN \ p.M) * iota, -inv(p.MN)];
p.C_ns = [eye(p.n), zeros(p.n); zeros(p.n), eye(p.n); ...
    -p.MN \ p.KN, -p.MN \ p.CN];
p.D_ns = [zeros(p.n, 1), zeros(p.n); ...
    zeros(p.n, 1), zeros(p.n); ...
    (-p.MN \ p.M + eye(p.n)) * iota, -inv(p.MN)];
p.sys_num = ss(p.A_ns, p.B_ns, p.C_ns, p.D_ns);
% Interface force (input 2) to first numerical displacement (output 1).
p.G_num = tf(p.sys_num(1, 2));

p.mm2m = 1 / 1000;
% The scripted plant uses an uncalibrated unity command path.
p.gain = 1;
p.a1_beta0 = 2.1283e13;
p.a2 = 4.2297e6;
p.beta1 = 425 + 3.3 * p.nom * randn(1, 1);
p.beta2 = 9.9976e4 + 3.3e3 * p.nom * randn(1, 1);
p.a3 = 3.3 + 1.3 * p.nom * randn(1, 1);

% Match the two successive rng(seed) statements in F1_input_file. The
% second assignment is the Seed_snr value visible to both noise blocks.
rng(savedRng);
seedSnr = rng(savedRng);
p.noise_seed = double(seedSnr.Seed);

p.rms_noise_DT = 6.25e-14;
p.rms_noise_FT = 1.16e-3;
p.Gsnsr_DT = 1;
p.Gsnsr_FT = 1;
p.sat_limit_upper = 3.8;
p.sat_limit_lower = -3.8;
p.quantize_int = 1 / 2^18;

fprintf('Modified value: %d\n', options.modified);
if options.modified == 1
    p.m_e = p.m_e * 1.3;
    p.ME = p.ME * 1.3;
    % Preserve the requested experimental damping ratio after increasing
    % the physical mass. The numerical partition remains unchanged.
    p.c_e = 2 * p.z_e * p.m_e * sqrt(p.KE(1, 1) / p.m_e);
    p.CE(1, 1) = p.c_e;
end

% Controllers are tuned against the actual initial specimen stiffness.
innerSystem = scripted_inner_open_loop(p.m_e, p.c_e, ...
    p.alpha_start * p.k_e);
analogClosedLoop = feedback(innerSystem, 1);
tuneA = pidtuneOptions('PhaseMargin', options.pm_a);
tuneB = pidtuneOptions('PhaseMargin', options.pm_b);
p.controller_a = pidtune(analogClosedLoop, 'PI', options.bw_a, tuneA);
p.controller_b = pidtune(analogClosedLoop, 'PI', options.bw_b, tuneB);
p.pi_a_kp = p.controller_a.Kp;
p.pi_a_ki = p.controller_a.Ki;
p.pi_b_kp = p.controller_b.Kp;
p.pi_b_ki = p.controller_b.Ki;

fprintf(['Using configured phase lead: gain = %.12g, zero = %.12g, ', ...
    'pole = %.12g rad/s\n'], p.lead_gain, p.lead_zero, p.lead_pole)
leadSystem = ss(tf(p.lead_gain * [1 p.lead_zero], [1 p.lead_pole]));
[p.Apred, p.Bpred, p.Cpred, p.Dpred] = c2dm(leadSystem.A, ...
    leadSystem.B, leadSystem.C, leadSystem.D, dt, 'tustin');

% Controller C is tuned at its configured NCF alpha by matching the legacy
% NCF margin while maximizing the sampled coupled-mode damping at that alpha.
specimen = struct('mass', p.m_e, 'stiffness', p.k_e, ...
    'damping', p.c_e);
controllerCInnerSystem = scripted_inner_open_loop(p.m_e, p.c_e, ...
    p.target_ncf_c_alpha * p.k_e);
ncfDamping = 2 * p.z_e * sqrt( ...
    p.target_ncf_c_alpha * p.k_e * p.m_e);
ncfInnerSystem = scripted_inner_open_loop(p.m_e, ncfDamping, ...
    p.target_ncf_c_alpha * p.k_e);
rthsParams = struct;
rthsParams.sampleTime = dt;
rthsParams.innerClosedLoop = ss(feedback(controllerCInnerSystem, 1));
rthsParams.innerClosedLoopNCF = ss(feedback(ncfInnerSystem, 1));
rthsParams.phaseLead = ss(p.Apred, p.Bpred, p.Cpred, p.Dpred, dt);
rthsParams.numericalSubstructure = ss( ...
    p.A_ns, p.B_ns, p.C_ns, p.D_ns);
rthsParams.forceInputIndex = 2;
rthsParams.displacementOutputIndex = 1;
[p.controller_c, p.controller_c_report] = custom_pi_tune( ...
    p.target_ncf_c, p.target_ncf_c_alpha, specimen, rthsParams);
p.pi_c_kp = p.controller_c.Kp;
p.pi_c_ki = p.controller_c.Ki;

controllerData = load(fullfile(projectRoot, 'Controllers', ...
    'Controller_2018_6_11_15_20_29.mat'));
originalController = ss(controllerData.pid_1);
[p.Acd, p.Bcd, p.Ccd, p.Dcd] = c2dm(originalController.A, ...
    originalController.B, originalController.C, originalController.D, ...
    dt, 'tustin');

p.M_r = p.ME + p.MN;
% This fixed system is used by no-damage simulation and linear analyses.
% Damage-enabled time simulations integrate the reference explicitly.
p.K_r = p.alpha_start * p.KE + p.KN;
p.C_r = p.CE + p.CN;
p.AA_R = [zeros(p.n), eye(p.n); -p.M_r \ p.K_r, -p.M_r \ p.C_r];
p.BB_R = [zeros(p.n, 1); -ones(p.n, 1)];
p.CC_R = [eye(p.n), zeros(p.n); zeros(p.n), eye(p.n); ...
    -p.M_r \ p.K_r, -p.M_r \ p.C_r];
p.DD_R = [zeros(2 * p.n, 1); -ones(p.n, 1)];
p.sys_r = ss(p.AA_R, p.BB_R, p.CC_R, p.DD_R);
end

function value = option_or_default(options, name, defaultValue)
if isfield(options, name)
    value = options.(name);
else
    value = defaultValue;
end
end
