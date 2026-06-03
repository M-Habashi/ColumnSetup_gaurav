function save_actuator_params_profile(profile_name, identified_params, metadata)
%SAVE_ACTUATOR_PARAMS_PROFILE Save a compact identified-parameter profile.

    profile_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'models', 'paarametric');
    if ~exist(profile_dir, 'dir')
        mkdir(profile_dir);
    end

    profile_path = fullfile(profile_dir, sprintf('%s_profile.mat', profile_name));
    save(profile_path, 'identified_params', 'metadata');
end
