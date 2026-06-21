function tests = test_analysis_utilities
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
main_folder = fileparts(fileparts(mfilename('fullpath')));
results_folder = fullfile(main_folder, 'results_analysis');
helpers_folder = fullfile(main_folder, 'helpers', 'utils');
addpath(results_folder);
addpath(helpers_folder);
testCase.TestData.results_folder = results_folder;
testCase.TestData.helpers_folder = helpers_folder;

repo_folder = fileparts(main_folder);
test_project = fullfile(repo_folder, '.codex', 'tests', ...
    'test_analysis_utilities');
test_results = fullfile(test_project, 'saved_results', 'tests');
if ~isfolder(test_results), mkdir(test_results); end
payload = 42;
preferred_file = fullfile(test_results, 'preferred.mat');
save(preferred_file, 'payload');
testCase.TestData.test_project = test_project;
testCase.TestData.preferred_file = preferred_file;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.results_folder);
rmpath(testCase.TestData.helpers_folder);
rmdir(testCase.TestData.test_project, 's');
end

function testExplicitPreferredResult(testCase)
[data, file_path, file_name] = load_saved_result_file( ...
    testCase.TestData.test_project, 'tests', false, ...
    testCase.TestData.preferred_file);

verifyEqual(testCase, data.payload, 42);
verifyEqual(testCase, file_path, testCase.TestData.preferred_file);
verifyEqual(testCase, file_name, 'preferred.mat');
end

function testSpecimenSIConversion(testCase)
specimen = struct('m', 2, 'c', 0.01, 'k', 7, ...
    'units', struct('m', 'kg', 'c', 'N*s/mm', 'k', 'N/mm'));
params = specimen_params_si(specimen);

verifyEqual(testCase, params.mass, 2);
verifyEqual(testCase, params.damping, 10);
verifyEqual(testCase, params.stiffness, 7000);
verifyEqual(testCase, params.units.schema_version, 2);
end

function testSpecimenUnitsAreRequired(testCase)
specimen = struct('m', 2, 'c', 0.01, 'k', 7);
verifyError(testCase, @()specimen_params_si(specimen), ...
    'specimen_params_si:MissingUnits');
end

function testPreferredResultMustMatchCategory(testCase)
verifyError(testCase, @()load_saved_result_file( ...
    testCase.TestData.test_project, 'specimens', false, ...
    testCase.TestData.preferred_file), ...
    'load_saved_result_file:PreferredFileOutsideRoot');
end

function testEvenLengthAmplitudeScaling(testCase)
fs = 1000;
t = (0:fs-1)'/fs;
y = 2+3*sin(2*pi*50*t);
[spectrum, frequency] = fft_c(y, fs);

verifyEqual(testCase, abs(spectrum(frequency == 0)), 2, 'AbsTol', 1e-12);
verifyEqual(testCase, abs(spectrum(frequency == 50)), 3, 'AbsTol', 1e-12);
end

function testNyquistIsNotDoubled(testCase)
fs = 1000;
n = 1000;
y = 4*(-1).^(0:n-1)';
[spectrum, frequency] = fft_c(y, fs);

verifyEqual(testCase, abs(spectrum(frequency == fs/2)), 4, 'AbsTol', 1e-12);
end

function testOddLengthAndFrequencyLimit(testCase)
fs = 99;
n = 99;
t = (0:n-1)'/fs;
y = 5*cos(2*pi*10*t);
[spectrum, frequency] = fft_c(y, fs, 20);

verifyLessThanOrEqual(testCase, frequency(end), 20);
verifyEqual(testCase, abs(spectrum(frequency == 10)), 5, 'AbsTol', 1e-12);
end
