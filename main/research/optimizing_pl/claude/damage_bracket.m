function members = damage_bracket(H0_dc_dm, k0, opts)
%DAMAGE_BRACKET Multiplicative-gain damage ensemble from a healthy baseline.
% The measured damage signature (sp1_7000 -> sp1_5000) is, to 0.2-0.9 dB,
% a pure magnitude gain on the deployed H_dc_dm:
%       H_damaged(s) ~= gamma_meas * H_healthy(s),  gamma_meas ~= 2.4 (+7.7 dB)
% with only a few degrees of phase change, while the experimental force-feedback
% stiffness drops to k_ratio_meas ~= 0.747 of healthy. Because the change is
% multiplicative (relative), the same law transfers to ANY baseline H_dc_dm:
% identify a healthy H0 on new hardware, then bracket damage as gamma*H0.
%
% A scalar damage coordinate rho indexes the family:
%       gamma(rho)   = 1 + rho*(gamma_meas   - 1)
%       k_scale(rho) = 1 + rho*(k_ratio_meas - 1)
% rho = 0 is healthy, rho = 1 reproduces the measured sp1_5000 state, and
% rho > 1 EXTRAPOLATES to further (unmeasured) excess damage. Designing for the
% whole interval rho in [0, rho_max] is what guarantees stability beyond the
% specimen you have actually tested.
%
% members(i) = struct('label','Hdc',H0-scaled tf,'k_exp',scaled k,'gamma','rho')

if nargin < 3, opts = struct(); end
d = struct('gamma_meas', 2.4, 'k_ratio_meas', 0.747, ...
    'rho', [0 0.5 1.0 1.5 2.0]);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end

rho = opts.rho(:)';
members = repmat(struct('label', '', 'Hdc', [], 'k_exp', [], ...
    'gamma', [], 'rho', []), numel(rho), 1);
for i = 1:numel(rho)
    g = 1 + rho(i)*(opts.gamma_meas - 1);
    ks = 1 + rho(i)*(opts.k_ratio_meas - 1);
    members(i).label = sprintf('rho=%.2g (gamma=%.2f, k=%.0f%%)', ...
        rho(i), g, 100*ks);
    members(i).Hdc = g*H0_dc_dm;
    members(i).k_exp = ks*k0;
    members(i).gamma = g;
    members(i).rho = rho(i);
end
end
