%% Run Output Verification
% Start this from the project folder or call it by path. At the pause in
% main_ColumnSetup.m, run the model on target, wait for it to finish, then
% press a key in MATLAB so the script saves and plots the result.

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fullfile(scriptFolder, '..', '..');
[~, projectAttributes] = fileattrib(projectFolder);
projectFolder = projectAttributes.Name;

originalFolder = pwd;
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
