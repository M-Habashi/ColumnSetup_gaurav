%% Run Output Verification
% Agent helper for output verification. Start MATLAB from the active step
% folder so this can be reused from repo-level .codex workflows.

originalFolder = pwd;

if exist(fullfile(originalFolder, 'main_ColumnSetup.m'), 'file')
    projectFolder = originalFolder;
else
    scriptFolder = fileparts(mfilename('fullpath'));
    repoFolder = fileparts(fileparts(scriptFolder));
    projectFolder = fullfile(repoFolder, 'main');
end

[~, projectAttributes] = fileattrib(projectFolder);
projectFolder = projectAttributes.Name;

cleanup = onCleanup(@() cd(originalFolder));
cd(projectFolder)

[resultFilePath, didSave] = runMainScript();
if ~didSave
    outputImagePath = '';
    fprintf('Output verification stopped: main script did not save a MAT file.\n');
    return
end

resultFilePath = fullfile(projectFolder, resultFilePath);
outputVerificationFile = resultFilePath;
run(fullfile('helpers', 'visualization', 'visualize_saved_results.m'))

outputFolder = fullfile(projectFolder, 'visual_inspection');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder)
end

outputImagePath = fullfile(outputFolder, 'output_verification_result.png');
print(gcf, outputImagePath, '-dpng', '-r150')
fprintf('Output verification image saved: %s\n', outputImagePath);

function [resultFilePath, didSave] = runMainScript()
run('main_ColumnSetup.m')

didSave = exist('savedfile_flag', 'var') ~= 0;
if didSave
    resultFilePath = file_name;
else
    resultFilePath = '';
end
end
