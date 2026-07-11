function [result, missing] = embed_saved_result_dependencies(result, projectFolder)
%EMBED_SAVED_RESULT_DEPENDENCIES Embed analysis inputs in a test result.
% Units: embedded values retain the units documented by their source data.

if nargin < 2 || isempty(projectFolder)
    projectFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

dependencies = fieldOr(result, 'dependencies', struct());
dependencies.format_version = 1;
missing = strings(0, 1);
needsModernValidation = isfield(result, 'phase_lead_file') ...
    || isfield(result, 'exp_tf_file');

if ~isfield(dependencies, 'phase_lead') && isfield(result, 'phase_lead_file')
    [file, found] = resolveFile(projectFolder, 'phase_lead', ...
        result.phase_lead_file);
    if found
        dependencies.phase_lead = load(file);
        dependencies.phase_lead_source = sourceName(file);
    else
        missing(end + 1, 1) = "phase_lead: " + string(result.phase_lead_file);
    end
end
if needsModernValidation && ~isfield(dependencies, 'phase_lead') ...
        && ~isfield(result, 'phase_lead_file')
    missing(end + 1, 1) = "phase_lead: no phase_lead_file metadata";
end

if ~isfield(dependencies, 'exp_tf') && isfield(result, 'exp_tf_file')
    [file, found] = resolveFile(projectFolder, 'exp_tf', result.exp_tf_file);
    if found
        dependencies.exp_tf = load(file, 'H_dc_dm', 'pid_values');
        dependencies.exp_tf_source = sourceName(file);
    else
        missing(end + 1, 1) = "exp_tf: " + string(result.exp_tf_file);
    end
end
if needsModernValidation && ~isfield(dependencies, 'exp_tf') ...
        && ~isfield(result, 'exp_tf_file')
    missing(end + 1, 1) = "exp_tf: no exp_tf_file metadata";
end

if ~isfield(dependencies, 'delay_comp') && isfield(result, 'delay_comp_file')
    [file, found] = resolveFile(projectFolder, 'delay_comp', ...
        result.delay_comp_file);
    if ~found
        [file, found] = resolveFile(projectFolder, 'phase_lead', ...
            result.delay_comp_file);
    end
    if found
        dependencies.delay_comp = load(file);
        dependencies.delay_comp_source = sourceName(file);
    else
        missing(end + 1, 1) = "delay_comp: " + string(result.delay_comp_file);
    end
end

if ~isfield(dependencies, 'fem') && isfield(result, 'hs')
    if isfield(result.hs, 'fem')
        dependencies.fem = struct('fem', result.hs.fem);
        dependencies.fem_source = sourceName(fieldOr(result.hs, ...
            'fem_file', 'embedded hs.fem'));
    elseif isfield(result.hs, 'fem_file')
        [file, found] = resolveFile(projectFolder, 'fem', result.hs.fem_file);
        if found
            dependencies.fem = load(file);
            dependencies.fem_source = sourceName(file);
        else
            missing(end + 1, 1) = "fem: " + string(result.hs.fem_file);
        end
    end
end

if ~isfield(dependencies, 'earthquake') && isfield(result, 'hs') ...
        && isfield(result.hs, 'time') && isfield(result.hs, 'ag')
    intensity = fieldOr(result.hs, 'intensity_factor', 1);
    if intensity == 0
        rawAg = result.hs.ag;
    else
        rawAg = result.hs.ag/intensity;
    end
    dependencies.earthquake = [result.hs.time(:), rawAg(:)];
    dependencies.earthquake_source = char(string(fieldOr(result.hs, ...
        'earthquake_type', 'embedded hs.time/ag')));
end

if ~isfield(dependencies, 'specimen')
    specimenPath = '';
    if isfield(dependencies, 'phase_lead') ...
            && isfield(dependencies.phase_lead, 'config') ...
            && isfield(dependencies.phase_lead.config, 'specimen_file')
        specimenPath = dependencies.phase_lead.config.specimen_file;
    elseif isfield(result, 'hs') && isfield(result.hs, 'fem') ...
            && isfield(result.hs.fem, 'specimen_file')
        specimenPath = result.hs.fem.specimen_file;
    end
    if ~isempty(specimenPath)
        [file, found] = resolveFile(projectFolder, 'specimens', specimenPath);
        if found
            dependencies.specimen = load(file);
            dependencies.specimen_source = sourceName(file);
        else
            missing(end + 1, 1) = "specimen: " + string(specimenPath);
        end
    elseif needsModernValidation && isfield(dependencies, 'phase_lead')
        missing(end + 1, 1) = "specimen: phase-lead data has no specimen_file";
    end
end

if isfield(dependencies, 'phase_lead_source')
    result.phase_lead_file = dependencies.phase_lead_source;
    if isfield(result, 'hs') && isfield(result.hs, 'phase_lead_file')
        result.hs.phase_lead_file = dependencies.phase_lead_source;
    end
end
if isfield(dependencies, 'exp_tf_source')
    result.exp_tf_file = dependencies.exp_tf_source;
    if isfield(result, 'hs') && isfield(result.hs, 'exp_tf_file')
        result.hs.exp_tf_file = dependencies.exp_tf_source;
    end
end
if isfield(dependencies, 'fem_source') && isfield(result, 'hs')
    result.hs.fem_file = dependencies.fem_source;
end
if isfield(dependencies, 'delay_comp_source')
    result.delay_comp_file = dependencies.delay_comp_source;
    if isfield(result, 'hs') && isfield(result.hs, 'delay_comp_file')
        result.hs.delay_comp_file = dependencies.delay_comp_source;
    end
end
if isfield(dependencies, 'specimen_source') ...
        && isfield(dependencies, 'phase_lead') ...
        && isfield(dependencies.phase_lead, 'config')
    dependencies.phase_lead.config.specimen_file = ...
        dependencies.specimen_source;
end

missing = unique(missing, 'stable');
dependencies.missing = missing;
result.dependencies = dependencies;
result.is_standalone = isempty(missing);
end

function [file, found] = resolveFile(projectFolder, subfolder, storedPath)
file = char(string(storedPath));
found = isfile(file);
if found
    return
end
[~, name, ext] = fileparts(file);
matches = dir(fullfile(projectFolder, 'saved_results', subfolder, '**', ...
    [name ext]));
found = ~isempty(matches);
if found
    file = fullfile(matches(1).folder, matches(1).name);
end
end

function name = sourceName(file)
[~, stem, ext] = fileparts(char(string(file)));
name = [stem ext];
end

function value = fieldOr(s, name, default)
if isfield(s, name)
    value = s.(name);
else
    value = default;
end
end
