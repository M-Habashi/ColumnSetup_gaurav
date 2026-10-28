%% Optimize vHS phase_lead With Minimum NCF Margin (v2 engine)
% Finds the phase_lead that minimizes J4 subject to
% NumPhaseLeadExpNCFMargin >= ncfmargin (set ncfmargin before running,
% default 0.45). Specimen, exp_tf and FEM files are loaded the same way
% as before (interactive picker unless an override file is set).
%
% Optional workspace overrides (same interface as the legacy script):
%   ncfmargin / ncf_margin          target NCF margin
%   specimen_file_override          saved_results/specimens file
%   exp_specimen_file_override      alias for specimen_file_override
%   h_dc_dm_model_file_override     saved_results/exp_tf file
%   fem_file_override               saved_results/fem file
%   pid_gain_override               [P I D N] or struct
%   phase_lead_file_name_override   output MAT name
%   phase_lead_optimizer_config     struct of engine options
%     (see defaultConfigV2 in utils_HS/optimize_vHS_phase_lead_v2.m,
%      e.g. extra_penalties / custom_objective_fcn for added goals)

clearvars -except phase_lead_optimizer_config ncfmargin ncf_margin ...
    fem_file_override ...
    specimen_file_override exp_specimen_file_override ...
    h_dc_dm_model_file_override pid_gain_override ...
    phase_lead_file_name_override; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils_HS'));

config = struct( ...
    'target_ncf_margin', 0.3, ...
    'phase_lead_file_name', 'pl_7000_ncf3', ...
    'optimization_record_fraction', 1.0, ...
    'save_results', true, ...
    'save_best_checkpoint', true, ...
    'plot_results', true);

if exist('phase_lead_optimizer_config', 'var') ...
        && ~isempty(phase_lead_optimizer_config)
    override_fields = fieldnames(phase_lead_optimizer_config);
    for override_id = 1:numel(override_fields)
        config.(override_fields{override_id}) = ...
            phase_lead_optimizer_config.(override_fields{override_id});
    end
end
config.save_results = true;
config.save_best_checkpoint = true;
config.optimization_record_fraction = ...
    max(config.optimization_record_fraction, 0.7);

if exist('ncfmargin', 'var') && ~isempty(ncfmargin)
    config.target_ncf_margin = ncfmargin;
elseif exist('ncf_margin', 'var') && ~isempty(ncf_margin)
    config.target_ncf_margin = ncf_margin;
end
if exist('fem_file_override', 'var') && ~isempty(fem_file_override)
    config.fem_file = fem_file_override;
end
if exist('exp_specimen_file_override', 'var') ...
        && ~isempty(exp_specimen_file_override)
    config.specimen_file = exp_specimen_file_override;
elseif exist('specimen_file_override', 'var') ...
        && ~isempty(specimen_file_override)
    config.specimen_file = specimen_file_override;
end
if exist('h_dc_dm_model_file_override', 'var') ...
        && ~isempty(h_dc_dm_model_file_override)
    config.h_dc_dm_model_file = h_dc_dm_model_file_override;
end
if exist('pid_gain_override', 'var') && ~isempty(pid_gain_override)
    config.pid_gain_override = pid_gain_override;
end
if exist('phase_lead_file_name_override', 'var') ...
        && ~isempty(phase_lead_file_name_override)
    config.phase_lead_file_name = phase_lead_file_name_override;
end

phase_lead_v2_result = optimize_vHS_phase_lead_v2(config);
