function result = simulate_controllers(reference, noise, dt, switchTime, ...
    estimatorOverride)
%SIMULATE_CONTROLLERS Run all candidate controllers on one scenario.
%
% reference, noise: column vectors at sample time dt (s). switchTime is the
% instant the plant changes from the 7k to the 5k model (Inf = healthy).
% Fixed linear controllers run as closed-loop lsim per plant segment; the
% path-adaptive LQG runs a per-sample loop with its online estimator.
% estimatorOverride (optional) replaces path estimator fields for
% calibration sweeps.

assets = kimi_assets;
family = load(fullfile(assets.results, 'plant_family.mat'), 'result');
family = family.result;
baseline = load(fullfile(assets.results, 'baseline_lqg.mat'), 'result');
baseline = baseline.result;
designs = load(fullfile(assets.results, 'candidate_designs.mat'), 'result');
designs = designs.result;

A = family.A0; B = family.B; C = family.C0;
dA = family.dA; dC = family.dC;
ws = family.frequency_scale;
n = size(A, 1);
A5 = A + dA; C5 = C + dC;
K0 = baseline.K; L0 = baseline.L; nbar0 = baseline.nbar;

% Discrete plant models.
plant7 = c2d(ss(ws*A, ws*B, C, 0), dt);
plant5 = c2d(ss(ws*A5, ws*B, C5, 0), dt);
t = (0:numel(reference)-1).'*dt;
switchIndex = find(t >= switchTime, 1, 'first');
if isempty(switchIndex)
    switchIndex = numel(t) + 1;
end
switched = switchIndex <= numel(t);

% ---- Fixed linear controllers as discrete closed loops -----------------
controllerSs = {};
labels = {};
[controllerSs{end+1}, labels{end+1}] = fixedController('baseline_lqg', ...
    ws*(A - B*K0 - L0*C), ws*B*nbar0, ws*L0, -K0, nbar0, dt);
[controllerSs{end+1}, labels{end+1}] = fixedController('robust_minmax', ...
    ws*(A - B*designs.robust_minmax.K - L0*C), ...
    ws*B*designs.robust_minmax.nbar, ws*L0, -designs.robust_minmax.K, ...
    designs.robust_minmax.nbar, dt);
Klqi = designs.robust_lqi.K; ki = designs.robust_lqi.ki;
AcLqi = [ws*(A - B*Klqi - L0*C), -ws*B*ki; zeros(1, n), 0];
[controllerSs{end+1}, labels{end+1}] = fixedController('robust_lqi_ff', ...
    AcLqi, [ws*B*nbar0; 1], [ws*L0; -1], [-Klqi, -ki], nbar0, dt);
Ld = designs.dist_lqg.L_aug;
Ad = [A, B; zeros(1, n), 0];
Bd = [B; 0];
Cd = [C, 0];
H = [-K0, -1];
[controllerSs{end+1}, labels{end+1}] = fixedController('dist_lqg', ...
    ws*(Ad + Bd*H - Ld*Cd), ws*Bd*nbar0, ws*Ld, H, nbar0, dt);
K5 = designs.path_lqg.K(end, :);
L5 = designs.path_lqg.L(end, :).';
N5 = designs.path_lqg.nbar(end);
[controllerSs{end+1}, labels{end+1}] = fixedController('matched_5k_lqg', ...
    ws*(A5 - B*K5 - L5*C5), ws*B*N5, ws*L5, -K5, N5, dt);

outputs = cell(size(labels));
for i = 1:numel(labels)
    outputs{i} = runFixed(controllerSs{i}, plant7, plant5, ...
        switchIndex, reference, noise, t);
end

% ---- Path-adaptive LQG -------------------------------------------------
pathDesign = designs.path_lqg;
if nargin >= 5 && ~isempty(estimatorOverride)
    fields = fieldnames(estimatorOverride);
    for i = 1:numel(fields)
        pathDesign.estimator.(fields{i}) = estimatorOverride.(fields{i});
    end
end
outputs{end+1} = runPathAdaptive(family, pathDesign, ...
    plant7, plant5, switchIndex, reference, noise, t, dt, ws);
labels{end+1} = 'path_lqg_adaptive';

% ---- Metrics -------------------------------------------------------------
metrics = {};
if switched
    windowPre = t >= switchTime - 15 & t < switchTime;
else
    windowPre = t >= t(end) - 35 & t < t(end) - 20;
end
windowPost = t >= t(end) - 20;
sustain = round(3/dt);
for i = 1:numel(labels)
    err = reference - outputs{i}.dm;
    preRms = rms(err(windowPre));
    postRms = rms(err(windowPost));
    moving = movingRms(err, round(1/dt));
    recoveryTime = NaN;
    peakU = NaN;
    if switched
        below = find(t >= switchTime & moving < 1.25*preRms);
        for k = below(:).'
            if k + sustain <= numel(t) && ...
                    all(moving(k:k+sustain) < 1.25*preRms)
                recoveryTime = t(k) - switchTime;
                break
            end
        end
        peakU = max(abs(outputs{i}.u(t >= switchTime & ...
            t < switchTime + 5)));
    end
    metrics(end+1, :) = {labels{i}, preRms, postRms, recoveryTime, peakU};
end
metrics = cell2table(metrics, 'VariableNames', {'controller', ...
    'rms_error_pre', 'rms_error_post', 'recovery_s', 'peak_u_post'});

result = struct;
result.labels = labels;
result.metrics = metrics;
result.t = t;
result.reference = reference;
result.noise = noise;
result.switch_time = switchTime;
result.outputs = outputs;
end

function [sys, label] = fixedController(label, Ac, Br, By, Cc, Dr, dt)
    continuous = ss(Ac, [Br, By], Cc, [Dr, 0]);
    sys = c2d(continuous, dt);
end

function output = runFixed(controller, plant7, plant5, ...
        switchIndex, reference, noise, t)
    % controller: discrete ss with inputs [r; y], output u.
    n = size(plant7.A, 1);
    nc = size(controller.A, 1);
    output = struct;
    output.dm = zeros(size(t));
    output.u = zeros(size(t));
    segments = {1:switchIndex-1, switchIndex:numel(t)};
    plants = {plant7, plant5};
    xc = zeros(nc, 1);
    xp = zeros(n, 1);
    for s = 1:2
        idx = segments{s};
        if isempty(idx)
            continue
        end
        plant = plants{s};
        Acl = [controller.A, controller.B(:, 2)*plant.C; ...
               plant.B*controller.C, plant.A];
        Br = [controller.B(:, 1); plant.B*controller.D(:, 1)];
        Bv = [controller.B(:, 2); zeros(n, 1)];
        Cu = [controller.C, zeros(1, n)];
        closed = ss(Acl, [Br, Bv], [zeros(1, nc), plant.C; Cu], ...
            [0, 0; controller.D(:, 1), 0], plant7.Ts);
        [ySim, ~, xSim] = lsim(closed, [reference(idx), noise(idx)], ...
            t(idx) - t(idx(1)), [xc; xp]);
        output.dm(idx) = ySim(:, 1);
        output.u(idx) = ySim(:, 2);
        xc = xSim(end, 1:nc).';
        xp = xSim(end, nc+1:end).';
    end
end

function output = runPathAdaptive(family, path, plant7, plant5, ...
        switchIndex, reference, noise, t, dt, ws)
    A = family.A0; B = family.B; C = family.C0;
    dA = family.dA; dC = family.dC;
    n = size(A, 1);
    grid = path.theta_grid;
    nodes = numel(grid);
    % Offline discrete matrices per grid node: the controller filter and
    % the model-reference predictor (designed closed loop driven by the
    % exogenous reference, with its theta sensitivity appended).
    PhiC = zeros(n, n, nodes); GuC = zeros(n, 1, nodes);
    GyC = zeros(n, 1, nodes);
    PhiR = zeros(4*n, 4*n, nodes); GuR = zeros(4*n, 1, nodes);
    dth = grid(2) - grid(1);
    for i = 1:nodes
        At = A + grid(i)*dA;
        Ct = C + grid(i)*dC;
        Lt = path.L(i, :).';
        M = expm(dt*ws*[At - Lt*Ct, B, Lt; zeros(2, n+2)]);
        PhiC(:, :, i) = M(1:n, 1:n);
        GuC(:, :, i) = M(1:n, n+1);
        GyC(:, :, i) = M(1:n, n+2);
        [Mc, Gc] = closedModel(At, Ct, path.K(i, :), Lt, path.nbar(i), ...
            B, n);
        ip = min(i + 1, nodes); im = max(i - 1, 1);
        [Mp, Gp] = closedModel(A + grid(ip)*dA, C + grid(ip)*dC, ...
            path.K(ip, :), path.L(ip, :).', path.nbar(ip), B, n);
        [Mm, Gm] = closedModel(A + grid(im)*dA, C + grid(im)*dC, ...
            path.K(im, :), path.L(im, :).', path.nbar(im), B, n);
        dMc = (Mp - Mm)/((grid(ip) - grid(im)));
        dGc = (Gp - Gm)/((grid(ip) - grid(im)));
        augmented = [Mc, zeros(2*n); dMc, Mc];
        augmentedG = [Gc; dGc];
        Mr = expm(dt*ws*[augmented, augmentedG; zeros(1, 4*n+1)]);
        PhiR(:, :, i) = Mr(1:4*n, 1:4*n);
        GuR(:, :, i) = Mr(1:4*n, 4*n+1);
    end
    est = path.estimator;
    theta = 0; thetaF = 0;
    ePower = 0; phiPower = 0;
    xc = zeros(n, 1); xr = zeros(4*n, 1); xp = zeros(n, 1);
    output = struct('dm', zeros(size(t)), 'u', zeros(size(t)), ...
        'theta', zeros(size(t)), 'e', zeros(size(t)), ...
        'phi', zeros(size(t)));
    for k = 1:numel(t)
        if k < switchIndex
            plant = plant7;
        else
            plant = plant5;
        end
        % interpolate discrete controller matrices at thetaF
        [Phi, Gu, Gy, Kt, ~, Nt] = interpolate(thetaF, grid, ...
            PhiC, GuC, GyC, path.K, path.L, path.nbar);
        Ct = C + thetaF*dC;
        output.dm(k) = plant.C*xp;
        y = output.dm(k) + noise(k);
        u = -Kt*xc + Nt*reference(k);
        xc = Phi*xc + Gu*u + Gy*y;
        [PhiRs, GuRs] = interpolateM(thetaF, grid, PhiR, GuR);
        xr = PhiRs*xr + GuRs*reference(k);
        yHat = Ct*xr(1:n);
        phi = Ct*xr(2*n+1:3*n) + dC*xr(1:n);
        e = y - yHat;
        output.e(k) = e;
        output.phi(k) = phi;
        ePower = ePower + (dt/est.window_time)*(e^2 - ePower);
        phiPower = phiPower + (dt/est.window_time)*(phi^2 - phiPower);
        if sqrt(ePower) > est.deadzone
            theta = theta + est.gamma*dt*e*phi/(est.nu + phiPower);
            theta = min(max(theta, est.projection(1)), est.projection(2));
        end
        thetaF = thetaF + (dt/est.smoothing_time)*(theta - thetaF);
        xp = plant.A*xp + plant.B*u;
        output.u(k) = u;
        output.theta(k) = thetaF;
    end
end

function [Mc, Gc] = closedModel(At, Ct, Kt, Lt, Nt, B, n)
    % designed closed loop driven by r: states [x_hat; x_model]
    Mc = [At - B*Kt - Lt*Ct, Lt*Ct; -B*Kt, At];
    Gc = [B*Nt; B*Nt];
end

function [Phi, Gu, Gy, Kt, Lt, Nt] = interpolate(theta, grid, ...
        PhiC, GuC, GyC, K, L, N)
    position = min(max(theta, grid(1)), grid(end))/(grid(end) - grid(1)) ...
        *(numel(grid) - 1) + 1;
    i = min(floor(position), numel(grid) - 1);
    alpha = position - i;
    Phi = (1-alpha)*PhiC(:, :, i) + alpha*PhiC(:, :, i+1);
    Gu = (1-alpha)*GuC(:, :, i) + alpha*GuC(:, :, i+1);
    Gy = (1-alpha)*GyC(:, :, i) + alpha*GyC(:, :, i+1);
    Kt = (1-alpha)*K(i, :) + alpha*K(i+1, :);
    Lt = (1-alpha)*L(i, :).' + alpha*L(i+1, :).'; %#ok<NASGU>
    Nt = (1-alpha)*N(i) + alpha*N(i+1);
end

function [Phi, Gu] = interpolateM(theta, grid, PhiM, GuM)
    position = min(max(theta, grid(1)), grid(end))/(grid(end) - grid(1)) ...
        *(numel(grid) - 1) + 1;
    i = min(floor(position), numel(grid) - 1);
    alpha = position - i;
    Phi = (1-alpha)*PhiM(:, :, i) + alpha*PhiM(:, :, i+1);
    Gu = (1-alpha)*GuM(:, :, i) + alpha*GuM(:, :, i+1);
end

function value = movingRms(x, window)
    value = sqrt(filter(ones(window, 1)/window, 1, x.^2));
end
