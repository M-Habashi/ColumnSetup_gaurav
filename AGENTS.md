# Agent Instructions

- We are working inside `C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn` now. For any command that needs to run outside that folder, ask the user for permission first. Git operations and reading/updating `AGENTS.md` are allowed from the repo root without asking.
- For plots, use this color guidance: desired displacement uses black with a thick dashed line, command displacement uses Copperwood `#AC6420`, measured displacement uses blue `#007CA8`, and force uses purple `#74058A`. Other available palette colors are green `#39BF5E` and red `#901500`.
- For any MATLAB/Simulink experiment-code change, ask the user before running the visual inspection procedure. If the user confirms, run `main_ColumnSetup.m`, run the Simulink model on target, continue the main script after the Simulink run finishes so results are saved, run the visualization helper script, and send the resulting plot screenshot in the chat.
- Visual inspection also includes capturing and sending screenshots of every Simulink subsystem relevant to the edited model/workflow.
- For Simulink visual inspection screenshots, prefer computer-use/GUI screenshots of the actual Simulink windows because MATLAB programmatic exports can miss or blur block details. Open each relevant subsystem, zoom/fit so block names and signal paths are readable, capture the screen, and send the screenshots in the chat. Use programmatic exports only as a fallback when computer-use is unavailable.
- If the user replies `yes 1 min`, run the visual inspection for 1 minute and stop the target manually/programmatically after 1 minute. If the user replies only `yes`, run the full configured simulation.
- Visual inspection file locations: main script is `main_ColumnSetup.m`; main Simulink model is `model_ColumnSetup_00.slx`; visualization helper is `helpers\visualization\visualize_saved_results.m`; Speedgoat helper scripts are in `helpers\helper_speedgoat`; helper Simulink models are in `helpers\helper_simulink`; visual inspection screenshots can be saved in `visual_inspection`.
- Send visual inspection images directly in the chat, including the output result plot and subsystem screenshots, not only the file paths.
- If the user asks to verify/vrify, treat that as explicit permission to run the physical Speedgoat workflow. It is considered safe and does not need an additional confirmation prompt.
- Output verification procedure:
  1. Work in `C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn`.
  2. In MATLAB, run `dbstop in main_ColumnSetup at 210`, then run `main_ColumnSetup.m`.
  3. Wait until MATLAB stops at line 210 (`pause`). At this point offsets are read, `model_ColumnSetup_00` is open, and the main script is waiting for the target run.
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
     outputImagePath = fullfile(projectFolder, 'visual_inspection', 'output_verification_result.png');
     print(gcf, outputImagePath, '-dpng', '-r150')
     ```
  7. Send `visual_inspection\output_verification_result.png` directly in the chat. Also report the saved MAT filename, duration, sample count, `fs`, `dt`, and `RMS(dd - dm)` from the visualization output.
  8. If the user asks for a full verification, use the configured `tend` instead of `60`. If the user says `yes 1 min`, use `tend = 60`.
- Computer Use troubleshooting notes from prior visual-inspection attempts: if Computer Use says `native pipe path is unavailable`, retry after a short delay and reconnect/reset once before giving up. If it can screenshot MATLAB but input fails with `failed to activate captured window`, ask the user to click/foreground MATLAB and then retry. If MATLAB is not listed, launch it by `C:\Program Files\MATLAB\R2020b\bin\matlab.exe` and wait for `MATLAB R2020b - academic use`.
- Whenever opening an instance/session/window through MCP, close it again after finishing with it.
- Do not run physical Speedgoat/actuator workflows for discussion-only prompts unless the user explicitly requests it.
Try to minimize code changes and prefer compact and direct codes
no need to inout vrifiction or error handling or edge cases study. assume the user is an engineer knows how to deal with default matlab errors
use built in funciotns if available rather than building custom ones from scratch unless you thing building our own is going to be outperform or make the code cleaner and easier to understand
simpler solutions are better solutions
