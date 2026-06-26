function ctx = osi_load_context(cfg)
%OSI_LOAD_CONTEXT Load test record, nominal exp_tf model and PID, and derive
% the shared quantities every trial needs.
% Units: t s, fs Hz, signals mm (displacement), margins dimensionless.

    if nargin < 1, cfg = osi_config(); end
    addpath(cfg.id_utils_dir);                 % xfunc, custom_stability_margins

    % --- nominal model + constant PID (from the exp_tf run) ---
    R = load(cfg.ref_file);
    pv = R.pid_values;
    Cpid = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, pv.dt, ...
        'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
    ctx.pid_values = pv;
    ctx.C   = tf(Cpid);                        % discrete PID, Ts = pv.dt
    ctx.dt  = pv.dt;
    ctx.H0d = R.models.H_dc_dm_d;              % nominal discrete plant (Ts = dt)
    ctx.H0c = R.H_dc_dm;                       % nominal continuous plant

    % nominal loop margins
    ctx.Cf       = squeeze(freqresp(ctx.C, 2*pi*cfg.fgrid));   % PID FRF on grid
    L0           = squeeze(freqresp(ctx.C*ctx.H0d, 2*pi*cfg.fgrid));
    ctx.nom_ncf  = osi_ncf_looponly(L0);                       % loop-only (~0.588)
    ctx.nom_bexact = ncfmargin(ctx.H0d, ctx.C);                % true 4-block b0
    ctx.H0f      = squeeze(freqresp(ctx.H0d, 2*pi*cfg.fgrid)); % nominal plant FRF

    % --- test record, restricted to a padded span around the window ---
    T = load(cfg.test_file);
    fs = T.fs; ctx.fs = fs;
    t_full = (0:numel(T.dm)-1).' / fs;
    pad = max(cfg.W, 5);
    keep = t_full >= cfg.t_start - pad & t_full <= cfg.t_end + pad;
    ctx.t  = t_full(keep);
    ctx.dd = T.dd(keep);
    ctx.dc = T.dc(keep);
    ctx.dm = T.dm(keep);

    % --- non-overlapping window edges & centers ---
    ctx.edges = cfg.t_start : cfg.W : cfg.t_end;
    ctx.tc    = (ctx.edges(1:end-1) + ctx.edges(2:end)).' / 2;
    ctx.nW    = numel(ctx.tc);

    ctx.cfg = cfg;
end
