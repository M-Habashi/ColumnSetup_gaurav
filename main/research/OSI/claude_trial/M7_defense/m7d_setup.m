function [D, M] = m7d_setup(which)
%M7D_SETUP Load a test record and the nominal model for the Method-7 proofs.
%  which : 'A' = 1731 (broadband input)   |   'B' = 1749 (low-frequency input)
%  D : struct with fs, t, dd, dc, dm, analysis window w=[t0 t1], label, which
%  M : struct with C (discrete PID tf), H0d (nominal discrete plant), dt
% Self-contained: locates the repo, the exp_tf model, and the test files itself.

    here = fileparts(mfilename('fullpath'));
    main = fileparts(fileparts(fileparts(fileparts(here))));   % M7_defense -> ... -> main
    addpath(fullfile(main, 'control_and_HS', 'b_system_id', 'id_utils'));   % xfunc

    R  = load(fullfile(main, 'saved_results', 'exp_tf', ...
        '20260617_1708_sp_1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015_20260623_174918.mat'));
    pv = R.pid_values;
    M.C   = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, pv.dt, ...
                   'IFormula','ForwardEuler', 'DFormula','ForwardEuler'));
    M.H0d = R.models.H_dc_dm_d;     % nominal plant dc->dm (discrete, Ts = dt)
    M.dt  = pv.dt;

    tdir = fullfile(main, 'saved_results', 'tests', 'important');
    if strcmpi(which, 'A')
        f = fullfile(tdir, '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat');
        D.w = [620 770.1];  D.label = '1731 (broadband input)';
    else
        f = fullfile(tdir, '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat');
        D.w = [100 286];    D.label = '1749 (low-frequency input)';
    end
    T = load(f);
    D.fs = T.fs;  D.dd = T.dd(:);  D.dc = T.dc(:);  D.dm = T.dm(:);
    D.t  = (0:numel(T.dm)-1).' / T.fs;  D.which = upper(which);

    if ~exist(fullfile(here,'figs'), 'dir'), mkdir(fullfile(here,'figs')); end
end
