# Agent Instructions

- We are working inside `C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn` now. For any command that needs to run outside that folder, ask the user for permission first. Git operations and reading/updating `AGENTS.md` are allowed from the repo root without asking.
- For plots, use this color guidance: desired displacement uses black with a thick dashed line, command displacement uses Copperwood `#AC6420`, measured displacement uses blue `#007CA8`, and force uses purple `#74058A`. Other available palette colors are green `#39BF5E` and red `#901500`.
- For any MATLAB/Simulink experiment-code change, ask the user before running the visual inspection procedure. If the user confirms, run `main_ColumnSetup.m`, run the Simulink model on target, continue the main script after the Simulink run finishes so results are saved, run the visualization helper script, and send the resulting plot screenshot in the chat.
- Visual inspection also includes capturing and sending screenshots of every Simulink subsystem relevant to the edited model/workflow.
- If the user replies `yes 1 min`, run the visual inspection for 1 minute and stop the target manually/programmatically after 1 minute. If the user replies only `yes`, run the full configured simulation.
- Visual inspection file locations: main script is `main_ColumnSetup.m`; main Simulink model is `model_ColumnSetup_00.slx`; visualization helper is `helpers\visualization\visualize_saved_results.m`; Speedgoat helper scripts are in `helpers\helper_speedgoat`; helper Simulink models are in `helpers\helper_simulink`; visual inspection screenshots can be saved in `visual_inspection`.
- Send visual inspection images directly in the chat, including the output result plot and subsystem screenshots, not only the file paths.
- Do not run physical Speedgoat/actuator workflows for discussion-only prompts unless the user explicitly requests it.
Try to minimize code changes and prefer compact and direct codes
no need to inout vrifiction or error handling or edge cases study. assume the user is an engineer knows how to deal with default matlab errors
use built in funciotns if available rather than building custom ones from scratch unless you thing building our own is going to be outperform or make the code cleaner and easier to understand
simpler solutions are better solutions
