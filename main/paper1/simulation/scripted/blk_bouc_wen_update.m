function [zNew, energyNew] = blk_bouc_wen_update( ...
        displacement, previousDisplacement, z, energy, p)
%BLK_BOUC_WEN_UPDATE Major-sample degrading Bouc-Wen recurrence.
%   All runtime quantities use metres: Z and displacement are in m and
%   ENERGY is in m^2. This is the displacement-increment realization of
%   the displayed continuous z-dot and yield-weighted E-dot equations.

increment = displacement - previousDisplacement;
effectiveEnergy = max(energy, 0);
nu = 1 + p.delta_nu * effectiveEnergy;
eta = max(1, 1 + p.delta_eta * effectiveEnergy);
zNew = z + (increment - ...
    nu * p.beta_b * abs(increment) * z * abs(z) ^ (p.n_bw - 1) - ...
    nu * p.gamma_b * increment * abs(z) ^ p.n_bw) / eta;
oldWeight = (abs(z) / p.u_y) ^ p.q_damage;
newWeight = (abs(zNew) / p.u_y) ^ p.q_damage;
weightedWorkIncrement = 0.5 * ...
    (oldWeight * z + newWeight * zNew) * increment;
energyNew = max(0, energy + weightedWorkIncrement);
end
