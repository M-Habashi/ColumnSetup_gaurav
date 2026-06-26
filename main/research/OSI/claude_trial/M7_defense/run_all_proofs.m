%% run_all_proofs -- run every Method-7 proof and print a PASS/FAIL summary.
% Each proof loads the data itself, verifies one claim with an assertion, prints
% the evidence, and saves a figure in ./figs. Theory is "proven programmatically"
% only if all five pass.
this_dir = fileparts(mfilename('fullpath'));  addpath(this_dir);
names = {'proof1_lock_tautology', 'proof2_resonance_grows', ...
         'proof3_spk_tracks_margin', 'proof4_frf_is_blind', 'proof5_method7_detects'};
res = false(1, numel(names));
for k = 1:numel(names)
    res(k) = run_one(fullfile(this_dir, [names{k} '.m']));   % isolated run
end

verdict = ["FAIL","PASS"];
fprintf('\n========================= PROOF SUMMARY =========================\n');
for k = 1:numel(names)
    fprintf('  %-26s : %s\n', names{k}, verdict(res(k)+1));
end
fprintf('  -----------------------------------------------\n');
fprintf('  ALL PROOFS: %s\n', verdict(all(res)+1));
fprintf('  figures saved in %s\n', fullfile(this_dir,'figs'));

%% ---- local function: run a proof script in an isolated workspace ----
function p = run_one(scriptfile)
    run(scriptfile);   % executes in THIS function's workspace; proof sets proof_pass
    p = proof_pass;
end
