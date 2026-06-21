function [base_rotation_k, rigid_base_k] = calculateBaseRotationStiffness( ...
        k_experimental, column)
%CALCULATEBASEROTATIONSTIFFNESS Calibrate a column-base rotational spring.
%   The column is an Euler-Bernoulli cantilever with a rotational spring at
%   its base.
% Units: lateral stiffness [N/m], geometry [m], E [N/m^2], Ix [m^4],
% output rotational stiffness [N*m/rad].

validateattributes(k_experimental, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'k_experimental');
assert(isstruct(column) && isfield(column, 'height') ...
    && isfield(column, 'E') && isfield(column, 'section') ...
    && isfield(column.section, 'Ix'), ...
    'column must define height, E, and section.Ix.');

L = column.height;
E = column.E;
Ix = column.section.Ix;
flexural_compliance = L^3/(3*E*Ix);
rigid_base_k = 1/flexural_compliance;
base_rotation_compliance = 1/k_experimental-flexural_compliance;

assert(base_rotation_compliance > 0, ...
    ['The selected stiffness (%.6g N/m) is not below the rigid-base ' ...
     'column stiffness (%.6g N/m), so no positive finite base ' ...
     'rotational stiffness can match it.'], ...
    k_experimental, rigid_base_k);

base_rotation_k = L^2/base_rotation_compliance;
end
