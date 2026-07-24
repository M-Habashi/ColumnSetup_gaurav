function result = run_sol_osi_simplified_sweep(eta_A)
%RUN_SOL_OSI_SIMPLIFIED_SWEEP Evaluate activity thresholds with Fabby.

if nargin < 1
    eta_A = [0.04 0.05 0.055 0.0575 0.06 0.07 0.08 0.10].';
else
    eta_A = eta_A(:);
end
n = numel(eta_A);

all_gates_pass = false(n, 1);
fabby_score_1 = zeros(n, 1);
fabby_score_2 = zeros(n, 1);
S3_detection = zeros(n, 1);
S4_smoothness = zeros(n, 1);
S5_gdb_recovery = zeros(n, 1);
composite = zeros(n, 1);
recovery_latency_s = zeros(n, 1);

for k = 1:n
    candidate = struct();
    evalc('candidate = run_sol_osi_simplified_benchmark(eta_A(k));');
    all_gates_pass(k) = candidate.all_gates_pass;
    fabby_score_1(k) = candidate.scores.fabby_score_1;
    fabby_score_2(k) = candidate.scores.fabby_score_2;
    S3_detection(k) = candidate.scores.S3_detection;
    S4_smoothness(k) = candidate.scores.S4_smoothness;
    S5_gdb_recovery(k) = candidate.scores.S5_gdb_recovery;
    composite(k) = candidate.composite;
    recovery_latency_s(k) = candidate.gdb.recovery_latency_s;
    fprintf('eta_A %.6f | gates %d | composite %.6f | recovery %.3f s\n', ...
        eta_A(k), all_gates_pass(k), composite(k), recovery_latency_s(k));
end

valid_score = composite;
valid_score(~all_gates_pass) = -Inf;
[best_composite, best_index] = max(valid_score);
result = struct( ...
    'generated_at', char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'eta_A', eta_A, ...
    'all_gates_pass', all_gates_pass, ...
    'fabby_score_1', fabby_score_1, ...
    'fabby_score_2', fabby_score_2, ...
    'S3_detection', S3_detection, ...
    'S4_smoothness', S4_smoothness, ...
    'S5_gdb_recovery', S5_gdb_recovery, ...
    'composite', composite, ...
    'recovery_latency_s', recovery_latency_s, ...
    'best_eta_A', eta_A(best_index), ...
    'best_composite', best_composite);
end
