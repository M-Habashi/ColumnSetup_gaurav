function params = specimen_params_si(specimen)
%SPECIMEN_PARAMS_SI Convert stored specimen parameters to SI dynamics units.

has_fields = all(isfield(specimen, {'m', 'c', 'k', 'units'}));
if ~has_fields || ~all(isfield(specimen.units, {'m', 'c', 'k'}))
    error('specimen_params_si:MissingUnits', ...
        'Specimen files must define m, c, k, and their units.');
end
validateattributes(specimen.m, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'specimen.m');
validateattributes(specimen.c, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'specimen.c');
validateattributes(specimen.k, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'specimen.k');
assert(strcmpi(strrep(string(specimen.units.m), ' ', ''), 'kg'), ...
    'Specimen mass must use kg.');
assert(strcmpi(strrep(string(specimen.units.c), ' ', ''), 'N*s/mm'), ...
    'Specimen damping must use N*s/mm.');
assert(strcmpi(strrep(string(specimen.units.k), ' ', ''), 'N/mm'), ...
    'Specimen stiffness must use N/mm.');

params.mass = specimen.m;             % [kg]
params.damping = 1000*specimen.c;     % [N*s/m]
params.stiffness = 1000*specimen.k;   % [N/m]
params.units = struct('mass', 'kg', 'damping', 'N*s/m', ...
    'stiffness', 'N/m', 'length', 'm', 'schema_version', 2);
end
