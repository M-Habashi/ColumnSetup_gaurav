function force = blk_bouc_wen_restoring_force( ...
        displacement, z, initialStiffness, p)
%BLK_BOUC_WEN_RESTORING_FORCE F = k0*(rho*d + (1-rho)*z).
%   DISPLACEMENT and Z are in m, INITIALSTIFFNESS is k0 in N/m, and the
%   public post_yield_ratio option is the equation's residual ratio rho.

force = initialStiffness * (p.post_yield_ratio * displacement + ...
    (1 - p.post_yield_ratio) * z);
end
