function G_num = G_num(buildingCase)
%G_NUM SISO numerical-substructure transfer function.
%   G_NUM = G_NUM() returns the nominal Case 1 transfer function from the
%   delayed interface force to the first numerical displacement.
%
%   G_NUM = G_NUM(BUILDINGCASE) selects Case 1 through Case 4.  The full
%   numerical substructure has four inputs and nine outputs; this SISO
%   channel is output 1 / input 2, matching the active RTHS signal path.

if nargin < 1
    buildingCase = 1;
end
validateattributes(buildingCase, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 4}, mfilename, 'buildingCase');

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
caseFile = fullfile(projectRoot, 'Building cases', ...
    sprintf('Case_%d.mat', buildingCase));
caseData = load(caseFile);

% The numerical matrices are formed before the optional experimental-mass
% modification, exactly as in F1_input_file and SCRIPTED_BUILD_TRIAL.
m_e = 29.13;
k_e = 1190e3;
z_e = 0.0097;
M_e = zeros(caseData.n);
M_e(1, 1) = m_e;
K_e = zeros(caseData.n);
K_e(1, 1) = k_e;
C_e = zeros(caseData.n);
C_e(1, 1) = 2 * z_e * m_e * sqrt(k_e / m_e);

M_n = caseData.M - M_e;
K_n = caseData.K - K_e;
C_n = caseData.C - C_e;
iota = ones(caseData.n, 1);
A_num = [zeros(caseData.n), eye(caseData.n); ...
    -M_n \ K_n, -M_n \ C_n];
B_num = [zeros(caseData.n, 1), zeros(caseData.n); ...
    -(M_n \ caseData.M) * iota, -inv(M_n)];
C_num = [eye(caseData.n), zeros(caseData.n); ...
    zeros(caseData.n), eye(caseData.n); ...
    -M_n \ K_n, -M_n \ C_n];
D_num = [zeros(caseData.n, 1), zeros(caseData.n); ...
    zeros(caseData.n, 1), zeros(caseData.n); ...
    (-M_n \ caseData.M + eye(caseData.n)) * iota, -inv(M_n)];

sys_num = ss(A_num, B_num, C_num, D_num);
G_num = tf(sys_num(1, 2));
end
