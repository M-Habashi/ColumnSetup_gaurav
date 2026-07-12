function [new_params, current_params] = habashi_osi_parameter_sets(projectFolder)
%HABASHI_OSI_PARAMETER_SETS Editable GPT-5.6.4 OSI/authority tuning parameters.
% Edit the "new" values below and run tune_habashi_osi_parameters (record
% replay) or run_habashi_fable_10_cases (synthetic suite). "current" is the
% canonical implementation with its built-in defaults, so every comparison
% is new-tuning vs what the rig runs today. Both sets execute the SAME
% implementation: control_and_HS/OSI/gpt5_6_4_osi.m + gpt5_6_4_auth.m.

if nargin < 1 || isempty(projectFolder)
    script_root = fileparts(mfilename('fullpath'));
    projectFolder = fileparts(fileparts(fileparts(script_root)));
end

%% Model Used To Build The OSI Loop Model
exp_tf_file = fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat');

%% Category A - Spectral Estimator (gpt5_6_4_osi)
step_s = 0.125;          % OSI update period [s]. Faster reacts sooner but
                         % each spectrum sees less data; must divide segment_s.
segment_s = 0.5;         % FFT window length [s]. Longer = finer frequency
                         % resolution, slower to notice changes.
memory_s = 0.25;         % Spectral averaging time [s]. Longer smooths the
                         % coherence/FRF estimates; shorter tracks faster
                         % but is noisier (more authority jitter downstream).
margin_s = 0.15;         % Smoothing of the published margin b [s]. The auth
                         % law reads this b, so longer = calmer authority,
                         % shorter = quicker sheds after real edges.
warm_s = 2.0;            % Startup blackout [s]: no residual fit before this;
                         % also the averaging time of the drive/rho_drive EMAs
                         % the fast detector compares against.
band_hz = [2 100];       % Analysis band [Hz] for the coherent margin.
line_reject_hz = [58 62];% Mains-line notch: bins ignored everywhere.
residual_band_hz = [28 44]; % Quiet band for the rho shape fit (instability
                         % grows here first on this rig).
power_floor_db = 30;     % Bin leverage floor [dB below the strongest bin].
                         % Higher floor = fewer bins trusted = safer but
                         % blinder margin estimate.
quiet_rms = 0.06;        % Drive level [mm rms] that counts as "active".
                         % Below it the OSI holds memory instead of fitting
                         % (and the rho leak takes over).

%% Category B - Damage Memory And Fit (gpt5_6_4_osi)
residual_s = 0.50;       % Time constant [s] of the rho memory update while
                         % driven. Shorter locks onto damage faster but
                         % follows fit noise more.
fit_floor = 0.175;       % Minimum weight of the quiet-band shape fit when the
                         % coherent detector is silent. Higher = trusts the
                         % shape fit more (faster damage tracking, more false
                         % sensitivity); lower = coherent evidence rules.
detector_max = 2.0;      % NEW. Ceiling on the fast drive-ratio kick on rho.
                         % A sudden coherent-gain excursion multiplies rho by
                         % at most this (2.0 = one doubling), and only after
                         % two consecutive hot updates (0.25 s). Directly
                         % limits how hard one detection event can shed the
                         % authority; raise for harder first response, lower
                         % for calmer authority.
rho_leak_s = 10.0;       % NEW. Idle decay time constant [s] of the damage
                         % memory. With no drive rho leaks toward healthy, b
                         % rises, and the authority climbs back blind (no
                         % safety evidence). Shorter = faster recovery but
                         % the memory of a still-present fault fades equally
                         % fast; longer = safer hold, slower blind rise.
                         % Benchmark 2026-07-12: 2-10 s fail the stability
                         % gates on osi_calibration_test (unstable after
                         % the quake fades with the gain held); >= 20 s
                         % passes, 40 s is the recommended safe minimum.
                         % 10 s is safe only when the fault is removed
                         % before the excitation stops.

%% Category C - Authority Law (gpt5_6_4_auth)
target_outer_ncf = 0.55; % Regulated NCF margin setpoint. The auth factor is
                         % steered so the estimated b sits here. Higher =
                         % more conservative (less authority, better margin);
                         % lower = better tracking, closer to instability.
                         % Live tests read this from the record's hs config.
guard = 0.02;            % Extra setpoint margin added when the estimate
                         % leans on the uncertain residual branch.
deadband = 0.008;        % |b - setpoint| band with no authority motion;
                         % suppresses hunting around the target.
rate = 5.0;              % Log-domain integral gain: how aggressively a moves
                         % per unit margin error each update.
max_step = 0.05;         % Hard cap on |da| per 0.125 s update. The main
                         % smoothness guard: lower = gentler actuator-gain
                         % motion, higher = faster sheds AND climbs.
osi_gain_min = 0.20;     % Authority floor a_min (keeps the test observable).
a_max = 1.00;            % Authority ceiling.
osi_gain_initial = 1.00; % Authority at t = 0.

if abs(round(segment_s/step_s) - segment_s/step_s) > 1e-9
    error('habashi_osi_parameter_sets:StepRatio', ...
        'segment_s must contain an integer number of step_s blocks.')
end

new_osi = struct( ...
    'step_s', step_s, ...
    'segment_s', segment_s, ...
    'memory_s', memory_s, ...
    'margin_s', margin_s, ...
    'residual_s', residual_s, ...
    'warm_s', warm_s, ...
    'band_hz', band_hz, ...
    'line_reject_hz', line_reject_hz, ...
    'residual_band_hz', residual_band_hz, ...
    'power_floor_db', power_floor_db, ...
    'fit_floor', fit_floor, ...
    'quiet_rms', quiet_rms, ...
    'detector_max', detector_max, ...
    'rho_leak_s', rho_leak_s);

new_auth = struct( ...
    'target', target_outer_ncf, ...
    'guard', guard, ...
    'deadband', deadband, ...
    'rate', rate, ...
    'max_step', max_step, ...
    'a_min', osi_gain_min, ...
    'a_max', a_max, ...
    'a_init', osi_gain_initial, ...
    'dt_update', step_s);

new_params = struct( ...
    'name', 'new', ...
    'projectFolder', projectFolder, ...
    'exp_tf_file', exp_tf_file, ...
    'target_outer_ncf', target_outer_ncf, ...
    'osi_gain_min', osi_gain_min, ...
    'osi_gain_initial', osi_gain_initial, ...
    'osi_override', new_osi, ...
    'auth_override', new_auth);

% Canonical implementation defaults (gpt5_6_4_osi/gpt5_6_4_auth 'config'
% and 'params' with empty overrides) — what main_ColumnSetup deploys when
% hs.gpt5_6_override is empty.
current_params = struct( ...
    'name', 'current', ...
    'projectFolder', projectFolder, ...
    'exp_tf_file', exp_tf_file, ...
    'target_outer_ncf', target_outer_ncf, ...
    'osi_gain_min', osi_gain_min, ...
    'osi_gain_initial', osi_gain_initial, ...
    'osi_override', struct(), ...
    'auth_override', struct('target', target_outer_ncf, ...
    'a_min', osi_gain_min, 'a_init', osi_gain_initial));
end
