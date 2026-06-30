function [cases, ctx] = load_adaptive_ctx(cfg)
%LOAD_ADAPTIVE_CTX Build the 5-case battery + context for the adaptive-PID study.
% Reuses osi_test_cases (the canonical battery) and attaches, to each case, the
% healthy-phase and damaged-phase PID parameters [P I D N] that the sample-accurate
% simulator needs (it rebuilds the PID as separate branches). The healthy phase is
% always C0; the damaged phase is C0 for every case except C4 (integral-driven),
% whose damaged controller is the integral-heavy CI defined in osi_test_cases.

addpath(cfg.osi);  addpath(genpath(cfg.osi));  addpath(cfg.optdir);
[cases, ctx] = osi_test_cases();

% healthy PID parameters [P I D N] (the C0 design, from the saved model)
sr = fullfile(cfg.main,'saved_results');
H7 = load(fullfile(sr,'exp_tf','tf_sp_1_7000_20260627_210411.mat'));
pv = H7.pid_values;
pp0 = [pv.P pv.I pv.D pv.derivative_filter_N];
ctx.pp0 = pp0;

% CI parameters must match osi_test_cases' integral-heavy controller (case C4)
ppCI = [0.15 200 0.0015 512];

for i = 1:numel(cases)
    cases(i).pidh = pp0;                              % healthy phase: C0
    if strcmp(cases(i).id,'C4')
        cases(i).pidd = ppCI;                         % damaged phase: CI
    else
        cases(i).pidd = pp0;                          % damaged phase: C0
    end
end
end
