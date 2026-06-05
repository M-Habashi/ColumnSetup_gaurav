# Agent Instructions

- We are working inside `C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn` now. For any command that needs to run outside that folder, ask the user for permission first. Git operations and reading/updating `AGENTS.md` are allowed from the repo root without asking.
- For plots, use this color guidance: desired displacement uses black with a thick dashed line, command displacement uses Copperwood `#AC6420`, measured displacement uses blue `#007CA8`, and force uses purple `#74058A`. Other available palette colors are green `#39BF5E` and red `#901500`.
- For any MATLAB/Simulink experiment-code change, ask the user before running the visual inspection procedure. If the user confirms, run `main_ColumnSetup.m`, run the Simulink model on target, continue the main script after the Simulink run finishes so results are saved, run the visualization helper script, and send the resulting plot screenshot in the chat.
- Visual inspection also includes capturing and sending screenshots of every Simulink subsystem relevant to the edited model/workflow.
- For Simulink visual inspection screenshots, prefer computer-use/GUI screenshots of the actual Simulink windows because MATLAB programmatic exports can miss or blur block details. Open each relevant subsystem, zoom/fit so block names and signal paths are readable, capture the screen, and send the screenshots in the chat. Use programmatic exports only as a fallback when computer-use is unavailable.
- If the user replies `yes 1 min`, run the visual inspection for 1 minute and stop the target manually/programmatically after 1 minute. If the user replies only `yes`, run the full configured simulation.
- Visual inspection file locations: main script is `main_ColumnSetup.m`; main Simulink model is `model_ColumnSetup_00.slx`; visualization helper is `helpers\visualization\visualize_saved_results.m`; Speedgoat helper scripts are in `helpers\helper_speedgoat`; helper Simulink models are in `helpers\helper_simulink`.
- Store all temporary verification/test artifacts under repo-level `.codex`, for example `.codex\verification\<task_name>\`. This includes baseline/after MAT files, plots, comparison metrics, and Simulink screenshots. If the MATLAB workflow first writes a verification MAT file under `saved_results`, copy/move the needed evidence into `.codex\verification\<task_name>\` and remove duplicate temporary verification files from the step folder.
- Send visual inspection images directly in the chat, including the output result plot and subsystem screenshots, not only the file paths.
- If the user asks to verify/vrify, treat that as explicit permission to run the physical Speedgoat workflow. It is considered safe and does not need an additional confirmation prompt.
- Output verification procedure:
  1. Work in `C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn`.
  2. In MATLAB, run `dbstop in main_ColumnSetup at 201`, then run `main_ColumnSetup.m`.
  3. Wait until MATLAB stops at line 201 (`pause`). At this point offsets are read, `model_ColumnSetup_00` is open, and the main script is waiting for the target run.
  4. Run the physical Speedgoat target from MATLAB:
     ```matlab
     tend = 60; % use 60 for a quick verification; use the configured tend for a full run
     slbuild(model);
     tg = slrealtime;
     tg.load(model)
     tg.start('AutoImportFileLog', true, 'StopTime', tend);
     T = timer('TimerFcn', @(~,~)disp('*** Output verification target run complete. ***'), 'StartDelay', tend + 5);
     start(T); wait(T); delete(T);
     pause off
     dbcont
     pause on
     dbclear in main_ColumnSetup
     ```
  5. Confirm `savedfile_flag` exists. The saved MAT file path is in `file_name`.
  6. Run the visualization on the exact saved file:
     ```matlab
     projectFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn';
     cd(projectFolder)
     outputVerificationFile = fullfile(projectFolder, file_name);
     run(fullfile(projectFolder, 'helpers', 'visualization', 'visualize_saved_results.m'))
     outputFolder = fullfile(fileparts(projectFolder), '.codex', 'verification', 'output_verification');
     if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end
     outputImagePath = fullfile(outputFolder, 'output_verification_result.png');
     print(gcf, outputImagePath, '-dpng', '-r150')
     ```
  7. Send `.codex\verification\output_verification\output_verification_result.png` directly in the chat. Also report the saved MAT filename, duration, sample count, `fs`, `dt`, and `RMS(dd - dm)` from the visualization output.
  8. If the user asks for a full verification, use the configured `tend` instead of `60`. If the user says `yes 1 min`, use `tend = 60`.
- When comparing baseline/after physical runs for a model cleanup, save the baseline MAT/plot, after MAT/plot, comparison metrics, and subsystem screenshots under `.codex\verification\<task_name>\` rather than a `test` or `visual_inspection` folder inside the step folder.
- When the user asks to compare a current run with a fixed baseline, keep using that baseline until the user explicitly says to update it. Report the comparison as signal-to-signal values in one table with `Channel`, `RMS(current - baseline)`, and `Normalized change (%)` columns. Compute normalized change as `100 * RMS(current - baseline) / max(RMS(baseline), RMS(current))` for that channel. Include channels `dd`, `dc`, `vc`, `dm`, `fm`, and `am`. Do not include duration, sample count, `fs`, `dt`, or `RMS(dd - dm)` summary tables unless the user explicitly asks for them.
- Before reporting a fixed-baseline physical comparison, first ensure the current run sends the same command signal as the fixed baseline. If needed, replay the baseline `dd` through `time_history`, set `test_signal = 1`, and match the command-path gain/limit semantics for the verification run only; confirm `RMS(current dd - baseline dd)` and `RMS(current dc - baseline dc)` are approximately zero before interpreting `dm`, `fm`, or `am`.
- If a fixed-baseline comparison includes a channel that is intentionally no longer logged after a Mux cleanup, keep the channel row and report `NaN` for its metrics rather than failing or changing the fixed baseline.
- If the user says `baseline compare`, treat it as a request to run the current Simulink model on the physical Speedgoat target for 1 minute, compare the saved run against the fixed baseline, keep the baseline unchanged, and report only the signal-to-signal comparison table described above.
- MATLAB MCP can lose connection after a long Speedgoat run while the file log is importing; first reconnect with a small MATLAB query and check for the expected saved MAT file before rerunning the physical system.
- In `mcp__matlab.evaluate_matlab_code`, avoid relying on local helper functions defined later in the same evaluated snippet for quick metric generation. Use inline MATLAB code or a real `.m` script instead.
- MATLAB MCP workspace rule: variables created inside an `mcp__matlab.evaluate_matlab_code` snippet are not enough for this Simulink workflow. `model_ColumnSetup_00.slx` block/configuration parameter evaluation resolves many symbols from the MATLAB base workspace, including `model`, `dt`, `tend`, chirp settings, gains, channel structs, `time_history`, and `ini_v`. Before any compile/build/update-diagram action such as `slbuild`, `set_param(model,'SimulationCommand','update')`, or `tg.load(model)`, initialize the base workspace first.
- Preferred initialization before build/compile work: run `main_ColumnSetup.m` up to its pause/breakpoint so the real script defines the base workspace, then build/load from that same MATLAB session. For no-target edit verification, use `dbstop in main_ColumnSetup at <pause line>`, run the script, wait at the pause, then perform `slbuild` or model checks.
- If you intentionally build/check without running `main_ColumnSetup.m`, explicitly `assignin('base', ...)` every setup variable the model expects, then run a preflight check before the first build. Minimum preflight:
  ```matlab
  req = {'model','dt','tend','f_init','f_final','tend_chirp','f1','tend_BLWN','time_history','tend_time_history','ini_v','ch','command_channel_selector','sat_limit'};
  missing = req(~cellfun(@(v) evalin('base', sprintf('exist(''%s'',''var'')', v)), req));
  assert(isempty(missing), ['Missing base workspace variables: ' strjoin(missing, ', ')])
  ```
- Do not call `slbuild` repeatedly to discover one missing base variable at a time. If a build/update fails with "Unrecognized function or variable" for a setup symbol, stop and initialize/check the full base workspace before retrying.
- For MATLAB Function blocks in Simulink models, fixed workspace values such as `dt` can be used directly for simpler diagrams, but declare them as MATLAB Function block `Parameter` data so update/codegen resolves them reliably; use an explicit Constant input only if inference still fails.
- Running `analysis\system_id\fromDataToParametric.m` rewrites both `models\fit` and `models\paarametric` outputs. If a task only changes or verifies the standalone fit, preserve or restore the parametric `.mat` files so verification does not leave unrelated physical-ID output churn.
- Dashboard switches that must be usable when opening `model_ColumnSetup_00.slx` directly should bind to a model-workspace variable, not only a base-workspace variable. For example, store `zero_measurements_enable` in the model workspace, set the controlled Constant block `Value` to `zero_measurements_enable`, and set the dashboard binding `VarName='zero_measurements_enable'`, `WksType='model'`.
- For SLRT dashboard switches that must toggle while the target is running, avoid the model-parameter `PageSwitching` storage class for the live flag. Store the flag as a model-workspace `Simulink.Parameter` with `CoderInfo.StorageClass = 'ExportedGlobal'` so toggling it updates a direct global scalar instead of causing a calibration page switch.
- If a command/tool fails in a way that could recur, update this markdown file before retrying more than once or before giving the final answer. The update must be a concrete reusable rule: name the failing command/context, the trigger/error symptom, the correct next action, and any quick pre-check. If a related rule already exists but did not prevent the mistake, strengthen that rule instead of adding a vague duplicate.
- Computer Use troubleshooting notes from prior visual-inspection attempts: if Computer Use says `native pipe path is unavailable`, retry after a short delay and reconnect/reset once before giving up. If it can screenshot MATLAB but input fails with `failed to activate captured window`, ask the user to click/foreground MATLAB and then retry. If MATLAB is not listed, launch it by `C:\Program Files\MATLAB\R2020b\bin\matlab.exe` and wait for `MATLAB R2020b - academic use`.
- Whenever opening an instance/session/window through MCP, close it again after finishing with it.
- Do not run physical Speedgoat/actuator workflows for discussion-only prompts unless the user explicitly requests it.
- For MATLAB/Simulink model or experiment-code changes in this repo, physical Speedgoat target runs are generally permitted and recommended for verification; do not ask for extra confirmation before a target run unless the prompt is discussion-only or the requested operation is unusual/destructive.
Try to minimize code changes and prefer compact and direct codes
no need to inout vrifiction or error handling or edge cases study. assume the user is an engineer knows how to deal with default matlab errors
use built in funciotns if available rather than building custom ones from scratch unless you thing building our own is going to be outperform or make the code cleaner and easier to understand
simpler solutions are better solutions
