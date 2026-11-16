function habashi
%HABASHI List the scripted plotting commands.

[targetNCF, targetAlpha] = scripted_controller_c_settings;
fprintf('\nScripted plotting commands\n');
fprintf(['  Controller C uses custom PI tuning ', ...
    '(NCF target %g at alpha %g).\n'], targetNCF, targetAlpha);
fprintf('  step    Unit-step responses for controllers A, B, and C.\n');
fprintf('  step_num  Exact full-RTHS ground-acceleration step simulation.\n');
fprintf('  freq_num  Exact full-RTHS chirp-based frequency-response estimate.\n');
fprintf('  ncf     NCF margin versus stiffness ratio alpha for A, B, and C.\n');
fprintf(['  margins  Normalized delay, gain, and NCF indicators for ', ...
    'manuscript Figures 4 and 8.\n']);
fprintf(['  margins_evolve  Outer-loop magnitude/phase evolution and ', ...
    'gain/phase margins for manuscript Figure 5 at alpha = 1 and 0.3.\n']);
fprintf(['  tables  Robustness table, then PI gains, bandwidth, and ', ...
    'phase margin plus saved PI-command maxima.\n']);
fprintf(['  scripted_benchmark_indicator_runtime  Time the 10,000-point ', ...
    'NCF sweep and full three-margin slow task on the current host.\n']);
fprintf('  bode    Closed-loop Bode plots for A, B, and C; dashed = alpha 0.5.\n');
fprintf('  pl      Bode plot of the phase-lead compensator only.\n');
fprintf('  pl_cl   Phase-lead-weighted closed-loop Bode plots for A, B, and C.\n');
fprintf('  num_pl_cl  G_num and phase-lead weighted closed-loop Bode plots.\n');
fprintf('  G_num   Numerical-substructure force-to-displacement transfer function.\n');
fprintf('  theoretical  Print Y(s), omega_cr, and alpha_cr for Controller A.\n');
fprintf(['  lyap(''A'',''C'')  Common quadratic Lyapunov sweep for any ', ...
    'two controllers; alpha 1 to 0. Prints and returns Acl1/Acl2 at ', ...
    'the minimum feasible alpha, together with P.\n\n']);
fprintf(['  scripted_search_ab_phase_lead_ncf  Resumable joint A/B PI ', ...
    'and shared phase-lead retuning.\n\n']);
end
