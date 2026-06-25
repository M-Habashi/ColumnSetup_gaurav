function phase_lead = normalizePhaseLeadConfig(phase_lead_override, ...
        section_count)
%NORMALIZEPHASELEADCONFIG Return a validated phase-lead configuration.
% The continuous compensator is gain*prod(s + zi)/prod(s + pi), with
% zeros and poles entered in Hz for easier tuning.

if nargin < 1
    phase_lead_override = [];
end
if nargin < 2
    section_count = [];
end
section_count = inferSectionCount(phase_lead_override, section_count);
phase_lead = struct( ...
    'enabled', false, ...
    'section_count', section_count, ...
    'gain', 1.0, ...
    'zero_hz', NaN(1, section_count), ...
    'pole_hz', NaN(1, section_count), ...
    'zero_rad_s', NaN(1, section_count), ...
    'pole_rad_s', NaN(1, section_count), ...
    'dc_gain', 1.0, ...
    'high_frequency_gain', 1.0, ...
    'center_frequency_hz', NaN(1, section_count), ...
    'section_ratio', NaN(1, section_count), ...
    'section_max_phase_lead_deg', NaN(1, section_count), ...
    'max_phase_lead_deg', 0.0, ...
    'max_phase_lead_frequency_hz', NaN);

if nargin == 0 || isempty(phase_lead_override)
    return
end

phase_lead.enabled = true;
if isnumeric(phase_lead_override)
    validateattributes(phase_lead_override, {'numeric'}, ...
        {'vector', 'real', 'finite'}, mfilename, ...
        'phase_lead_override');
    phase_lead_override = phase_lead_override(:).';
    if numel(phase_lead_override) == 3
        phase_lead.gain = phase_lead_override(1);
        phase_lead.zero_hz = phase_lead_override(2);
        phase_lead.pole_hz = phase_lead_override(3);
    else
        phase_lead.gain = phase_lead_override(1);
        phase_lead.zero_hz = phase_lead_override(2:1+section_count);
        phase_lead.pole_hz = phase_lead_override(2+section_count:end);
    end
elseif isstruct(phase_lead_override)
    fields = {'enabled', 'gain', 'zero_hz', 'pole_hz'};
    for field_id = 1:numel(fields)
        field = fields{field_id};
        if isfield(phase_lead_override, field)
            phase_lead.(field) = phase_lead_override.(field);
        end
    end
else
    error('normalizePhaseLeadConfig:InvalidOverride', ...
        ['phase_lead_override must be [], [gain zero_hz pole_hz], ' ...
        '[gain zero_hz_vector pole_hz_vector], or a struct.'])
end

if ~phase_lead.enabled
    return
end

validateattributes(phase_lead.gain, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, ...
    'phase_lead.gain');
validateattributes(phase_lead.zero_hz, {'numeric'}, ...
    {'vector', 'real', 'finite', 'positive'}, mfilename, ...
    'phase_lead.zero_hz');
validateattributes(phase_lead.pole_hz, {'numeric'}, ...
    {'vector', 'real', 'finite', 'positive'}, mfilename, ...
    'phase_lead.pole_hz');
phase_lead.zero_hz = phase_lead.zero_hz(:).';
phase_lead.pole_hz = phase_lead.pole_hz(:).';
if numel(phase_lead.zero_hz) ~= section_count ...
        || numel(phase_lead.pole_hz) ~= section_count
    error('normalizePhaseLeadConfig:InvalidSectionCount', ...
        'zero_hz and pole_hz must each have %d value(s).', section_count)
end
if any(phase_lead.pole_hz <= phase_lead.zero_hz)
    error('normalizePhaseLeadConfig:InvalidLead', ...
        'For each phase-lead section, pole_hz must be greater than zero_hz.')
end

phase_lead.zero_rad_s = 2*pi*phase_lead.zero_hz;
phase_lead.pole_rad_s = 2*pi*phase_lead.pole_hz;
phase_lead.dc_gain = phase_lead.gain ...
    * prod(phase_lead.zero_rad_s./phase_lead.pole_rad_s);
phase_lead.high_frequency_gain = phase_lead.gain;
phase_lead.center_frequency_hz = sqrt( ...
    phase_lead.zero_hz.*phase_lead.pole_hz);
phase_lead.section_ratio = phase_lead.pole_hz./phase_lead.zero_hz;
phase_lead.section_max_phase_lead_deg = asind( ...
    (phase_lead.section_ratio - 1)./(phase_lead.section_ratio + 1));
[phase_lead.max_phase_lead_deg, ...
    phase_lead.max_phase_lead_frequency_hz] = ...
    combinedPhaseLeadMaximum(phase_lead);
end

function section_count = inferSectionCount(phase_lead_override, section_count)
if ~isempty(section_count)
    validateattributes(section_count, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'section_count');
    return
end
section_count = 1;
if nargin == 0 || isempty(phase_lead_override)
    return
end
if isnumeric(phase_lead_override)
    n_value = numel(phase_lead_override);
    if n_value == 3
        section_count = 1;
    elseif n_value > 3 && mod(n_value - 1, 2) == 0
        section_count = (n_value - 1)/2;
    else
        error('normalizePhaseLeadConfig:InvalidNumericOverride', ...
            ['Numeric phase_lead_override must have 3 values or ' ...
            '1 + 2*n values.'])
    end
elseif isstruct(phase_lead_override)
    if isfield(phase_lead_override, 'zero_hz')
        section_count = numel(phase_lead_override.zero_hz);
    elseif isfield(phase_lead_override, 'pole_hz')
        section_count = numel(phase_lead_override.pole_hz);
    end
end
end

function [max_lead_deg, max_lead_frequency_hz] = ...
        combinedPhaseLeadMaximum(phase_lead)
lower_hz = max(min(phase_lead.zero_hz)/10, eps);
upper_hz = max(phase_lead.pole_hz)*10;
freq_hz = logspace(log10(lower_hz), log10(upper_hz), 1000);
s = 1i*2*pi*freq_hz;
response = phase_lead.gain*ones(size(s));
for section_id = 1:phase_lead.section_count
    response = response ...
        .* (s + phase_lead.zero_rad_s(section_id)) ...
        ./ (s + phase_lead.pole_rad_s(section_id));
end
phase_deg = unwrap(angle(response))*180/pi;
[max_lead_deg, max_id] = max(phase_deg);
max_lead_frequency_hz = freq_hz(max_id);
end
