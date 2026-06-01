# Output Verification

Use output verification when the goal is to prove that the active step workflow can run on the Speedgoat target, resume MATLAB, save `logsout` into `saved_results`, and render the saved output plot in the chat.

## Fast Procedure

1. Start MATLAB in the active step folder, for example:

   ```text
   C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn
   ```

2. Run:

   ```matlab
   run(fullfile('..', '.codex', 'verification', 'run_output_verification.m'))
   ```

3. The helper runs `main_ColumnSetup.m`. That script reads offsets, opens the Simulink model, prints the Run-on-Target instructions, and pauses.
4. In Simulink, use the `REAL-TIME` tab and click `Run on Target`.
5. Wait until the target simulation finishes. For a one-minute check, stop the target after 60 s before resuming MATLAB.
6. Return to MATLAB and press any key so `main_ColumnSetup.m` continues.
7. The main script imports `logsout`, saves the MAT file under `saved_results\yyyymmdd`, closes the model, and creates its quick-look figure.
8. The helper then runs `helpers\visualization\visualize_saved_results.m` on the exact MAT file that was just saved and exports:

   ```text
   visual_inspection\output_verification_result.png
   ```

9. Send `visual_inspection\output_verification_result.png` directly in the chat.

## What Matters

- Run this helper from the step folder that contains `main_ColumnSetup.m`.
- The saved result is identified from the `file_name` variable created by the main script, not by guessing the newest MAT file.
- The visualization helper can still be run manually. If `outputVerificationFile` exists in the MATLAB workspace, it skips the file-selection prompt and plots that file.
- Output verification does not require Simulink subsystem screenshots. Those belong to visual inspection after code/model changes.
- Do not run this physical Speedgoat/actuator workflow for discussion-only prompts. Run it only when the user explicitly requests output verification or confirms it.
