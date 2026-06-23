function save_actuator_params_profile(profile_name, identified_params, metadata)
%SAVE_ACTUATOR_PARAMS_PROFILE Save a compact identified-parameter profile.
% Units: profile name/path are unitless text; parameter units are supplied
% by metadata and continuous-time model definitions.

    step_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    profile_dir = fullfile(step_root, 'saved_results', 'models');
    if ~exist(profile_dir, 'dir')
        mkdir(profile_dir);
    end

    profile_path = fullfile(profile_dir, sprintf('%s_profile.mat', profile_name));
    save(profile_path, 'identified_params', 'metadata');
end
