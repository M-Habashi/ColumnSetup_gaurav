%% Optimize vHS Delay Compensation With Minimum NCF Margin
% Set ncfmargin before running to require a NumDelayCompExpNCFMargin value.

clearvars -except phase_lead_optimizer_config ncfmargin ncf_margin ...
    fem_file_override ...
    specimen_file_override exp_specimen_file_override ...
    h_dc_dm_model_file_override pid_gain_override; clc;

script_dir = fileparts(mfilename('fullpath'));
defaults = struct( ...
    'minimum_num_delay_comp_exp_ncf_margin', 0.6, ...
    'use_parallel_grid', true);

if exist('phase_lead_optimizer_config', 'var') ...
        && ~isempty(phase_lead_optimizer_config)
    phase_lead_optimizer_config = mergeLocalStruct(defaults, ...
        phase_lead_optimizer_config);
else
    phase_lead_optimizer_config = defaults;
end
if exist('ncfmargin', 'var') && ~isempty(ncfmargin)
    phase_lead_optimizer_config.minimum_num_delay_comp_exp_ncf_margin = ...
        ncfmargin;
elseif exist('ncf_margin', 'var') && ~isempty(ncf_margin)
    phase_lead_optimizer_config.minimum_num_delay_comp_exp_ncf_margin = ...
        ncf_margin;
end

run(fullfile(script_dir, 'utils_HS', 'optimize_vHS_phase_lead.m'))

function config = mergeLocalStruct(config, override)
fields = fieldnames(override);
for field_id = 1:numel(fields)
    config.(fields{field_id}) = override.(fields{field_id});
end
end
