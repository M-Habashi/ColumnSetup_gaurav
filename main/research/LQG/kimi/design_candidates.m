function result = design_candidates
%DESIGN_CANDIDATES Robust/adaptive LQG candidates against the baseline.
%
% Candidates (all share the baseline LQR output weight qy, ru = 1, and the
% canonical filter ratio rho = 1 unless a tuning says otherwise):
%   robust_lqi   - LQR with an integrator on r - y (zero steady-state error
%                  on any stabilized plant); qi tuned to minimize the worst
%                  step overshoot over the two identified plants.
%   robust_minmax- fixed LQG whose qy is retuned to minimize the worst
%                  overshoot over both plants; shows robust retuning cannot
%                  repair the steady-state error.
%   path_lqg     - proposed method: one-parameter family A(theta), C(theta)
%                  with the whole LQG (K, L, Nbar) scheduled along its LQG
%                  homotopy; online output-error estimator for theta.
%   dist_lqg     - LQG whose Kalman filter is augmented with an input
%                  disturbance state (random walk); the estimate is
%                  subtracted at the input (internal-model cancellation).

assets = kimi_assets;
family = load(fullfile(assets.results, 'plant_family.mat'), 'result');
family = family.result;
baseline = load(fullfile(assets.results, 'baseline_lqg.mat'), 'result');
baseline = baseline.result;

A = family.A0; B = family.B; C = family.C0;
dA = family.dA; dC = family.dC;
ws = family.frequency_scale;
n = size(A, 1);
A5 = A + dA; C5 = C + dC;
qy = baseline.qy; ru = baseline.ru; rho = baseline.filter_rho;
K0 = baseline.K; L0 = baseline.L; nbar0 = baseline.nbar;
stepTime = linspace(0, 30, 30001).';

% ---- Candidate 1: robust LQI with feedforward ---------------------------
% Servo LQI: u = nbar r - Kx x_hat - ki xi, xi' = r - y. The feedforward
% keeps the nominal response; the integrator removes the steady-state
% error. qi is picked from a grid as the fastest correction that keeps the
% 5k plant stable (larger ki rings and then destabilizes the 5k loop).
Aa = [A, zeros(n, 1); -C, 0];
Ba = [B; 0];
ei = [zeros(1, n), 1];
logQiGrid = (-4:0.5:2).';
lqiCosts = zeros(size(logQiGrid));
for i = 1:numel(logQiGrid)
    lqiCosts(i) = lqiFfCost(logQiGrid(i), Aa, Ba, ei, ...
        A, C, A5, C5, B, qy, nbar0, L0, ws, stepTime);
end
[minLqiCost, argmin] = min(lqiCosts);
logQi = logQiGrid(argmin);
Qa = qy*([C, 0].'*[C, 0]) + 10^logQi*(ei.'*ei);
Ka = lqr(Aa, Ba, Qa, ru);
Klqi = Ka(1:n); ki = Ka(n+1);
fprintf('LQI+FF grid: min cost %.6g at logQi %.6g (1e6 = unstable)\n', ...
    minLqiCost, logQi)

% ---- Candidate 2: robust min-max retune of qy --------------------------
minmaxObjective = @(logQy) worstOvershootMinMax(logQy, ...
    A, C, A5, C5, B, ru, ws, stepTime);
logQyMm = fminbnd(minmaxObjective, 0, 4, optimset('Display', 'off'));
qyMm = 10^logQyMm;
Kmm = lqr(A, B, qyMm*(C.'*C), ru);
nbarMm = -1/(C*((A - B*Kmm) \ B));

% ---- Candidate 3: path-following adaptive LQG --------------------------
thetaGrid = linspace(0, 1, 51).';
Kpath = zeros(numel(thetaGrid), n);
Lpath = zeros(numel(thetaGrid), n);
Npath = zeros(numel(thetaGrid), 1);
for i = 1:numel(thetaGrid)
    At = A + thetaGrid(i)*dA;
    Ct = C + thetaGrid(i)*dC;
    Kpath(i, :) = lqr(At, B, qy*(Ct.'*Ct), ru);
    Lpath(i, :) = lqr(At.', Ct.', rho*(B*B.'), 1).';
    Npath(i) = -1/(Ct*((At - B*Kpath(i, :)) \ B));
end
% Pointwise pairwise certificates over the grid.
pairSF = -Inf; pairLQG = -Inf;
for it = 1:numel(thetaGrid)
    At = A + thetaGrid(it)*dA;
    Ct = C + thetaGrid(it)*dC;
    for ie = 1:numel(thetaGrid)
        Ae = A + thetaGrid(ie)*dA;
        Ce = C + thetaGrid(ie)*dC;
        Ke = Kpath(ie, :);
        Le = Lpath(ie, :).';
        pairSF = max(pairSF, max(real(eig(At - B*Ke))));
        Acl = [Ae - B*Ke - Le*Ce, Le*Ct; -B*Ke, At];
        pairLQG = max(pairLQG, max(real(eig(Acl))));
    end
end

% ---- Candidate 4: input-disturbance-augmented LQG ----------------------
% The stable-on-both-plants region is a narrow ledge of slow disturbance
% bandwidths (found by grid evaluation; fminbnd is unreliable on the
% 1e6 plateau). Faster disturbance estimates destabilize the 5k plant.
ed = [zeros(1, n), 1];
Ad = [A, B; zeros(1, n), 0];
Bd = [B; 0];
Cd = [C, 0];
H = [-K0, -1]; % u = nbar r + H [x_hat; d_hat]
logQdGrid = (-4:0.25:2).';
distCosts = zeros(size(logQdGrid));
for i = 1:numel(logQdGrid)
    distCosts(i) = worstSettleDist(logQdGrid(i), Ad, Bd, Cd, ed, H, ...
        A, C, A5, C5, B, nbar0, rho, ws, stepTime);
end
[minDistCost, argmin] = min(distCosts);
logQd = logQdGrid(argmin);
Ld = lqr(Ad.', Cd.', rho*(Bd*Bd.') + 10^logQd*(ed.'*ed), 1).';
fprintf('Disturbance LQG ledge: min cost %.6g at logQd %.6g (1e6 = unstable)\n', ...
    minDistCost, logQd)

% ---- Offline step metrics on both plants -------------------------------
metrics = {};
metrics(end+1, :) = stepMetrics('baseline_lqg', A, C, A, C, A5, C5, ...
    B, ws, stepTime, K0, L0, nbar0);
Lrho = lqr(A.', C.', rho*(B*B.'), 1).';
metrics(end+1, :) = lqiMetrics('robust_lqi_ff', A, C, A5, C5, B, ws, ...
    stepTime, Klqi.', ki, Lrho, nbar0);
metrics(end+1, :) = stepMetrics('robust_minmax', A, C, A, C, A5, C5, ...
    B, ws, stepTime, Kmm, Lrho, nbarMm);
metrics(end+1, :) = stepMetrics('path_lqg_theta0', A, C, A, C, A5, ...
    C5, B, ws, stepTime, Kpath(1, :), Lpath(1, :).', Npath(1));
% matched 5k design: stepMetrics returns {name, os, f} for the nominal
% slot (here the 5k plant with the 5k-matched controller) in columns 2-3
% and the mismatched plant (7k) in columns 4-6; reorder so table columns
% always report the physical 7k then 5k plant.
row = stepMetrics('path_lqg_theta1', A5, C5, A5, C5, A, C, B, ws, ...
    stepTime, Kpath(end, :), Lpath(end, :).', Npath(end));
metrics(end+1, :) = {row{1}, row{5}, row{6}, row{7}, row{2}, row{3}, ...
    row{4}, row{8}};
metrics(end+1, :) = distMetrics('dist_lqg', A, C, A5, C5, B, ws, ...
    stepTime, K0, nbar0, Ld);
metrics = cell2table(metrics, 'VariableNames', {'controller', ...
    'overshoot_7k', 'final_7k', 'settle_7k', 'overshoot_5k', ...
    'final_5k', 'settle_5k', 'stable_5k'});

result = struct;
result.qy = qy; result.ru = ru; result.rho = rho;
result.robust_lqi = struct('K', Klqi, 'ki', ki, 'qi', 10^logQi);
result.robust_minmax = struct('K', Kmm, 'nbar', nbarMm, 'qy', qyMm);
result.path_lqg = struct('theta_grid', thetaGrid, 'K', Kpath, ...
    'L', Lpath, 'nbar', Npath, ...
    'pairwise_state_feedback_worst', pairSF, ...
    'pairwise_lqg_worst', pairLQG, ...
    'estimator', struct('gamma', 30, 'deadzone', 0.0075, ...
        'window_time', 0.25, 'nu', 1e-3, ...
        'smoothing_time', 0.25, 'projection', [0 1]));
result.dist_lqg = struct('L_aug', Ld, 'qd', 10^logQd, ...
    'K', K0, 'nbar', nbar0);
result.metrics = metrics;

outputFile = fullfile(assets.results, 'candidate_designs.mat');
save(outputFile, 'result')
fprintf('LQI: qi=%.6g, ki=%.6g\n', 10^logQi, ki)
fprintf('MinMax: qy=%.6g\n', qyMm)
fprintf('Path LQG pairwise worst poles: SF %.6g, full %.6g (normalized)\n', ...
    pairSF, pairLQG)
fprintf('Disturbance LQG: qd=%.6g\n', 10^logQd)
disp(metrics)
fprintf('Saved candidate designs to %s\n', outputFile)
end

function cost = lqiFfCost(logQi, Aa, Ba, ei, ...
        A, C, A5, C5, B, qy, nbar, L, ws, stepTime)
    % worst-case post-switch correction time + overshoot penalty
    n = size(A, 1);
    Qa = qy*([C, 0].'*[C, 0]) + 10^logQi*(ei.'*ei);
    Ka = lqr(Aa, Ba, Qa, 1);
    Kx = Ka(1:n).'; ki = Ka(n+1);
    cost = 0;
    for k = 1:2
        if k == 1
            Ap = A; Cp = C;
        else
            Ap = A5; Cp = C5;
        end
        Acl = [A - B*Kx.' - L*C, L*Cp, -B*ki; ...
               -B*Kx.', Ap, -B*ki; ...
               zeros(1, n), -Cp, 0];
        sys = ss(ws*Acl, ws*[B*nbar; B*nbar; 1], [zeros(1, n), Cp, 0], 0);
        if ~isstable(sys)
            cost = 1e6; return
        end
        response = step(sys, stepTime);
        final = response(end);
        overshoot = max(0, (max(response) - final)/max(abs(final), eps)*100);
        outside = abs(response - final) > 0.02*max(abs(final), eps);
        lastOutside = find(outside, 1, 'last');
        settle = stepTime(min(lastOutside + 1, numel(stepTime)));
        cost = max(cost, 100*settle + overshoot);
    end
end

function cost = worstOvershootMinMax(logQy, A, C, A5, C5, B, ru, ...
        ws, stepTime)
    K = lqr(A, B, 10^logQy*(C.'*C), ru);
    nbar = -1/(C*((A - B*K) \ B));
    L = lqr(A.', C.', B*B.', 1).';
    cost = 0;
    for k = 1:2
        if k == 1
            Ap = A; Cp = C;
        else
            Ap = A5; Cp = C5;
        end
        Acl = [A - B*K - L*C, L*Cp; -B*K, Ap];
        sys = ss(ws*Acl, ws*[B*nbar; B*nbar], [zeros(1, size(A,1)), Cp], 0);
        if ~isstable(sys)
            cost = 1e6; return
        end
        response = step(sys, stepTime);
        cost = max(cost, max(0, (max(response) - response(end)) / ...
            max(abs(response(end)), eps)*100));
    end
end

function cost = worstSettleDist(logQd, Ad, Bd, Cd, ed, H, ...
        A, C, A5, C5, B, nbar, rho, ws, stepTime)
    n = size(A, 1);
    Ld = lqr(Ad.', Cd.', rho*(Bd*Bd.') + 10^logQd*(ed.'*ed), 1).';
    cost = 0;
    for k = 1:2
        if k == 1
            Ap = A; Cp = C;
        else
            Ap = A5; Cp = C5;
        end
        Acl = [Ad + Bd*H - Ld*Cd, Ld*Cp; B*H, Ap];
        sys = ss(ws*Acl, ws*[Bd*nbar; B*nbar], [zeros(1, n+1), Cp], 0);
        if ~isstable(sys)
            cost = 1e6; return
        end
        response = step(sys, stepTime);
        overshoot = max(0, (max(response) - response(end)) / ...
            max(abs(response(end)), eps)*100);
        outside = abs(response - 1) > 0.05;
        lastOutside = find(outside, 1, 'last');
        settle = stepTime(min(lastOutside + 1, numel(stepTime)));
        cost = max(cost, overshoot + 20*settle);
    end
end

function row = stepMetrics(name, Ac, Cc, A, C, A5, C5, B, ws, stepTime, ...
        K, L, nbar)
    n = size(A, 1);
    [os7, f7, ts7, os5, f5, ts5, st5] = deal(NaN);
    Acl7 = [Ac - B*K - L*Cc, L*C; -B*K, A];
    sys7 = ss(ws*Acl7, ws*[B*nbar; B*nbar], [zeros(1, n), C], 0);
    r = step(sys7, stepTime);
    os7 = max(0, (max(r) - r(end))/max(abs(r(end)), eps)*100);
    f7 = dcgain(sys7);
    ts7 = settlingTime(r, stepTime);
    Acl5 = [Ac - B*K - L*Cc, L*C5; -B*K, A5];
    sys5 = ss(ws*Acl5, ws*[B*nbar; B*nbar], [zeros(1, n), C5], 0);
    st5 = isstable(sys5);
    if st5
        r = step(sys5, stepTime);
        os5 = max(0, (max(r) - r(end))/max(abs(r(end)), eps)*100);
        f5 = dcgain(sys5);
        ts5 = settlingTime(r, stepTime);
    end
    row = {name, os7, f7, ts7, os5, f5, ts5, st5};
end

function row = lqiMetrics(name, A, C, A5, C5, B, ws, stepTime, ...
        Kx, ki, L, nbar)
    n = size(A, 1);
    [os7, f7, ts7, os5, f5, ts5, st5] = deal(NaN);
    for k = 1:2
        if k == 1
            Ap = A; Cp = C;
        else
            Ap = A5; Cp = C5;
        end
        Acl = [A - B*Kx.' - L*C, L*Cp, -B*ki; ...
               -B*Kx.', Ap, -B*ki; ...
               zeros(1, n), -Cp, 0];
        sys = ss(ws*Acl, ws*[B*nbar; B*nbar; 1], [zeros(1, n), Cp, 0], 0);
        stable = isstable(sys);
        r = step(sys, stepTime);
        os = max(0, (max(r) - r(end))/max(abs(r(end)), eps)*100);
        f = dcgain(sys);
        ts = settlingTime(r, stepTime);
        if k == 1
            os7 = os; f7 = f; ts7 = ts;
        else
            os5 = os; f5 = f; ts5 = ts; st5 = stable;
        end
    end
    row = {name, os7, f7, ts7, os5, f5, ts5, st5};
end

function row = distMetrics(name, A, C, A5, C5, B, ws, stepTime, ...
        K, nbar, Ld)
    n = size(A, 1);
    H = [-K, -1];
    Ad = [A, B; zeros(1, n), 0];
    Bd = [B; 0];
    Cd = [C, 0];
    [os7, f7, ts7, os5, f5, ts5, st5] = deal(NaN);
    for k = 1:2
        if k == 1
            Ap = A; Cp = C;
        else
            Ap = A5; Cp = C5;
        end
        Acl = [Ad + Bd*H - Ld*Cd, Ld*Cp; B*H, Ap];
        sys = ss(ws*Acl, ws*[Bd*nbar; B*nbar], [zeros(1, n+1), Cp], 0);
        stable = isstable(sys);
        r = step(sys, stepTime);
        os = max(0, (max(r) - r(end))/max(abs(r(end)), eps)*100);
        f = dcgain(sys);
        ts = settlingTime(r, stepTime);
        if k == 1
            os7 = os; f7 = f; ts7 = ts;
        else
            os5 = os; f5 = f; ts5 = ts; st5 = stable;
        end
    end
    row = {name, os7, f7, ts7, os5, f5, ts5, st5};
end

function settle = settlingTime(response, time)
    final = response(end);
    outside = abs(response - final) > 0.02*max(abs(final), eps);
    lastOutside = find(outside, 1, 'last');
    if isempty(lastOutside)
        settle = 0;
    elseif lastOutside < numel(time)
        settle = time(lastOutside + 1);
    else
        settle = Inf;
    end
end
