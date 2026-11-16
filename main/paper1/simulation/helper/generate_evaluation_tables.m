%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    Generate Evaluation Tables (J4, J5, J6)              %
%                    By Time Segments: t<7s, 7<t<12s, t>12s               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This script loads result files and calculates J4, J5, J6 metrics
% for different time segments, then prints LaTeX tables to command window.

%% Load result files
results_path = '..\Results\';

original = load([results_path, 'Original Benchmark_Nom_.mat']);
caseI = load([results_path, 'Case I_Nom_.mat']);
caseII = load([results_path, 'Case II_Nom_.mat']);
caseIII = load([results_path, 'Case III_Nom_.mat']);

%% Store all cases in a structure for easier processing
cases = {original, caseI, caseII, caseIII};

%% Calculate metrics for each case and time segment
% Initialize result arrays [n_cases x 4] for [seg1, seg2, seg3, overall]
J4_results = zeros(4, 4);
J5_results = zeros(4, 4);
J6_results = zeros(4, 4);

for i = 1:4
    data = cases{i};
    t = data.t;
    
    X_m_data = data.X_m.Data(:,1);
    Num_resp_data = data.Num_resp.Data;
    Ref_Resp = data.Ref_Resp;
    
    idx_seg1 = t < 7;
    idx_seg2 = (t >= 7) & (t < 12);
    idx_seg3 = t >= 12;
    
    % J4 (1st floor)
    J4_results(i,1) = 100 * norm(X_m_data(idx_seg1) - Ref_Resp(idx_seg1,1)) / norm(Ref_Resp(idx_seg1,1));
    J4_results(i,2) = 100 * norm(X_m_data(idx_seg2) - Ref_Resp(idx_seg2,1)) / norm(Ref_Resp(idx_seg2,1));
    J4_results(i,3) = 100 * norm(X_m_data(idx_seg3) - Ref_Resp(idx_seg3,1)) / norm(Ref_Resp(idx_seg3,1));
    J4_results(i,4) = 100 * norm(X_m_data - Ref_Resp(:,1)) / norm(Ref_Resp(:,1));

    % J5 (2nd floor)
    J5_results(i,1) = 100 * norm(Num_resp_data(idx_seg1,2) - Ref_Resp(idx_seg1,2)) / norm(Ref_Resp(idx_seg1,2));
    J5_results(i,2) = 100 * norm(Num_resp_data(idx_seg2,2) - Ref_Resp(idx_seg2,2)) / norm(Ref_Resp(idx_seg2,2));
    J5_results(i,3) = 100 * norm(Num_resp_data(idx_seg3,2) - Ref_Resp(idx_seg3,2)) / norm(Ref_Resp(idx_seg3,2));
    J5_results(i,4) = 100 * norm(Num_resp_data(:,2) - Ref_Resp(:,2)) / norm(Ref_Resp(:,2));

    % J6 (3rd floor)
    J6_results(i,1) = 100 * norm(Num_resp_data(idx_seg1,3) - Ref_Resp(idx_seg1,3)) / norm(Ref_Resp(idx_seg1,3));
    J6_results(i,2) = 100 * norm(Num_resp_data(idx_seg2,3) - Ref_Resp(idx_seg2,3)) / norm(Ref_Resp(idx_seg2,3));
    J6_results(i,3) = 100 * norm(Num_resp_data(idx_seg3,3) - Ref_Resp(idx_seg3,3)) / norm(Ref_Resp(idx_seg3,3));
    J6_results(i,4) = 100 * norm(Num_resp_data(:,3) - Ref_Resp(:,3)) / norm(Ref_Resp(:,3));
end

%% Print LaTeX tables to command window
print_latex_table('J4', 'Displacement normalized RMS error (1st floor)', J4_results);
print_latex_table('J5', 'Displacement normalized RMS error (2nd floor)', J5_results);
print_latex_table('J6', 'Displacement normalized RMS error (3rd floor)', J6_results);

%% Helper function to print LaTeX table
function print_latex_table(metric, description, results)
    fprintf('\n%% ============== %s Table ==============\n', metric);
    fprintf('\\begin{table}[htbp]\n');
    fprintf('\\centering\n');
    fprintf('\\caption{%s - %s}\n', metric, description);
    fprintf('\\begin{tabular}{llcccc}\n');
    fprintf('\\toprule\n');
    fprintf(' & & \\multicolumn{4}{c}{%s} \\\\\n', metric);
    fprintf('\\cmidrule(lr){3-6}\n');
    fprintf(' & & Segment 1 & Segment 2 & Segment 3 & \\\\\n');
    fprintf(' & & ($t < 7$s) & ($7 < t < 12$s) & ($t > 12$s) & Overall \\\\\n');
    fprintf('\\midrule\n');
    fprintf('Original Benchmark & & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', results(1,:));
    fprintf('\\midrule\n');
    fprintf(' & Case I & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', results(2,:));
    fprintf('Modified Benchmark & Case II & %.2f\\%% & %.2f\\%% & NA & NA \\\\\n', results(3,1:2));
    fprintf(' & Case III & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', results(4,:));
    fprintf('\\bottomrule\n');
    fprintf('\\end{tabular}\n');
    fprintf('\\end{table}\n');
end
