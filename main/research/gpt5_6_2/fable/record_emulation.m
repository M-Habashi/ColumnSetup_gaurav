function sim = record_emulation(which_osi, projectFolder, osi_fn, auth_fn)
%RECORD_EMULATION Closed-loop re-run of the 20260710_1845 test scenario.
%
%   sim = record_emulation('new')                    % this folder's OSI
%   sim = record_emulation('old', proj, osi, auth)   % pass handles bound
%     to research/gpt5_6 (create them with gpt5_6 first on the path;
%     functions in this folder otherwise shadow the path)
%
% Rebuilds the live test as a model-consistent closed loop: the identified
% 5k plant under its PID, the diagnostic gain schedule applied on the dc
% path (1 -> 1.5 @34.014 -> 2 @37.703 -> 3 @44.958, held to the end), the
% logged OSI tap replayed as the exogenous loop reference, measured-level
% sensor noise, actuator-command saturation, and the live configuration
% (target 0.35, a_min 0.2).  The OSI under test closes the authority loop.
% b_true is the chordal margin of g*a*L5 at each update; the linear loop is
% genuinely unstable for g*a >= 2.25, so a law that climbs too far diverges
% here exactly as the rig did.
%
% Data source: osi_calibration_test.mat, the corrected export of the
% 20260710_1845 run.  It is identical in every signal except dc, which is
% logged BEFORE the diagnostic gain there (the 1845 file's dc carried the
% gain, so anything reading it saw the test knob directly).  The emulation
% only replays u_osi (identical in both files) and synthesizes its own dc;
% the reported dc_rms is the post-gain command the actuator would receive.

here = fileparts(mfilename('fullpath'));
if nargin < 2 || isempty(projectFolder)
    projectFolder = fileparts(fileparts(fileparts(here)));
end
if nargin < 4
    osi_fn = @gpt_osi;      % same-folder resolution: this folder's v2
    auth_fn = @gpt_auth;
end
probe = osi_fn('config', 1/2048, tf(0.1, [1 1], 1/2048), struct());
is_new = isfield(probe, 'rho_relax_s');
switch lower(which_osi)
    case 'new'
        assert(is_new, 'record_emulation:Handles', ...
            'osi_fn resolves to the OLD estimator; pass v2 handles.')
    case 'old'
        assert(~is_new, 'record_emulation:Handles', ...
            'osi_fn resolves to the NEW estimator; pass gpt5_6 handles.')
    otherwise
        error('record_emulation:Which', 'Use ''old'' or ''new''.')
end

S = load(fullfile(projectFolder, 'saved_results', 'tests', 'gpt5_6_tests', ...
    'osi_calibration_test.mat'));
rec = S.result;
E = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E.pid_values;
dt = rec.dt;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H5 = ss(c2d(E.H_dc_dm, dt, 'zoh'));
L0 = C*H5;

t = rec.t(:);
ref = rec.u_osi(:);                    % exogenous loop reference (tap level)
gain = rec.Results(:, 21);             % diagnostic gain schedule
N = numel(t);
rng(3, 'twister')
noise = 0.06*randn(N, 1);              % measured idle dm level
dc_sat = 10;                           % actuator command limit [mm]

cfg = osi_fn('config', dt, L0, struct());
prm = auth_fn('params', struct('target', 0.35, 'a_min', 0.2, ...
    'dt_update', cfg.step_s));
ost = osi_fn('state', cfg);
ast = auth_fn('state', prm);

f = (1:100)';
L5f = squeeze(freqresp(L0, 2*pi*f));
[Ac, Bc, Cc, Dc] = ssdata(ss(C));
[Ap, Bp, Cp] = ssdata(H5);
xc = zeros(size(Ac, 1), 1);
xp = zeros(size(Ap, 1), 1);

blk = cfg.step_n;
nU = floor(N/blk);
tc = NaN(nU,1); bE = NaN(nU,1); bT = NaN(nU,1); aU = NaN(nU,1);
rhoU = NaN(nU,1); tripU = zeros(nU,1); dcr = NaN(nU,1); dmr = NaN(nU,1);
a = prm.a_init; ib = 0; ku = 0;
refB = zeros(blk,1); dmB = zeros(blk,1); dcW = zeros(blk,1); dmW = zeros(blk,1);
for k = 1:N
    y = Cp*xp;
    dmk = y + noise(k);
    e = ref(k) - dmk;
    u = Cc*xc + Dc*e;
    xc = Ac*xc + Bc*e;
    dck = min(max(gain(k)*a*u, -dc_sat), dc_sat);
    xp = Ap*xp + Bp*dck;
    ib = ib + 1;
    refB(ib) = ref(k); dmB(ib) = dmk; dcW(ib) = dck; dmW(ib) = dmk;
    if ib == blk
        ib = 0; ku = ku + 1;
        ost.a_cmd = a;
        [b, ost, oi] = osi_fn(refB, dmB, cfg, ost);
        [a, ast] = auth_fn(b, oi.full_margin, oi.residual_weight, ast, prm);
        tc(ku) = t(k); bE(ku) = b; aU(ku) = a;
        La = gain(k)*a*L5f;
        bT(ku) = min(abs(1+La)./sqrt(2*(1+abs(La).^2)));
        if isfield(oi, 'rho'), rhoU(ku) = oi.rho; end
        if isfield(oi, 'trip'), tripU(ku) = oi.trip; end
        dcr(ku) = rms(dcW); dmr(ku) = rms(dmW);
    end
end

idx = (1:nU)'*blk;
sim = struct('which', lower(which_osi), 't', tc, 'gain', gain(idx), ...
    'b', bE, 'b_true', bT, 'a', aU, 'rho', rhoU, 'trip', tripU, ...
    'dc_rms', dcr, 'dm_rms', dmr, 'target', prm.target, ...
    'dc_sat', dc_sat, 'sat_frac', mean(dcr >= 0.6*dc_sat));
end
