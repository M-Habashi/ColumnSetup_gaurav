function [zDerivative, energyDerivative] = blk_bouc_wen_derivative( ...
        velocity, z, energy, p)
%BLK_BOUC_WEN_DERIVATIVE Degrading Bouc-Wen z and work evolution.
%   VELOCITY and Z use m/s and m; ENERGY uses m^2. Damage-driving work is
%   weighted by (abs(z)/u_y)^q so linear-range motion contributes smoothly
%   less than motion close to the equivalent yield displacement.

effectiveEnergy = max(energy, 0);
nu = 1 + p.delta_nu * effectiveEnergy;
eta = max(1, 1 + p.delta_eta * effectiveEnergy);
zDerivative = (velocity - ...
    nu * p.beta_b * abs(velocity) * z * abs(z) ^ (p.n_bw - 1) - ...
    nu * p.gamma_b * velocity * abs(z) ^ p.n_bw) / eta;

yieldProximityWeight = (abs(z) / p.u_y) ^ p.q_damage;
energyDerivative = yieldProximityWeight * z * velocity;
if energy <= 0 && energyDerivative < 0
    energyDerivative = 0;
end
end
