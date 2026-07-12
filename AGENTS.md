# Agent Instructions

## Package Management

- For JavaScript/Node package installs, use `pnpm` instead of `npm`.

## Working Scope

- Work inside `C:\Users\Victus\Desktop\folder_working\a purdue\aa reasearch\Gaurav Setup\ColumnSetup_gaurav\main` unless the task explicitly requires the repository root.
- Ask the user before running commands outside `main`. Git operations and reading/updating repository-level instruction files are allowed from the repository root without asking.
- Treat `master` as the main branch for this repository.
- When running repository-level Git checks such as `git diff --check`, run them from the `ColumnSetup_gaurav` repository root.
- When a PowerShell command runs from the repository root, address project files as `main\...`.

## Always-On Project Rules

- Every time an HTML file is created or edited, load and follow the `uncodixify` skill, then run its validator on the changed HTML until it exits successfully.
- When the user asks to commit and push, do not run unit tests or other validation checks. Review the diff only to choose a proper commit message, then commit the full requested worktree and push it.
- For plots, use this color guidance: desired displacement uses black with a thick dashed line, command displacement uses Copperwood `#AC6420`, measured displacement uses blue `#007CA8`, and force uses purple `#74058A`. Other available palette colors are green `#39BF5E` and red `#901500`.
- Always try to keep each signal's plot color and line style consistent across the repository. Before plotting a signal, search for existing plots of that signal and reuse their established styling; for example, reuse the existing `fm` force color and solid/dashed style when adding another `fm` plot.
- Do not run physical Speedgoat/actuator workflows for discussion-only prompts unless the user explicitly requests it.
- Minimize code changes and prefer compact, direct code.
- Do not add unnecessary verification, error handling, or edge-case studies. Assume the user is an engineer who can handle default MATLAB errors.
- Use built-in functions when available unless a custom implementation is clearly faster, cleaner, or easier to understand.
- Simpler solutions are better solutions.
- Saved test MAT files should store one top-level `result` struct. To convert old top-level-variable test result files, run `convert_saved_result_to_struct` from `main`; it scans `saved_results/tests/**/*.mat` and rewrites old files in the new struct format.
- MATLAB utilities under `main\helpers\utils` need three `fileparts` calls from `mfilename('fullpath')` to resolve the `main` project folder.

## RTHS Plot Notation

- `dm`: measured actuator displacement response from the experiment at the interface/control point, approximately the zero-moment point around mid-column.
- `dc`: controller command displacement saved from `logsout`.
- `fm`: measured force.
- `num FEM`: numerical substructure FEM without the experimental column; measured feedback force `fm` is used to step this model forward.
- `full FEM` or `reference FEM`: complete FEM model driven by the same ground excitation `a_g`.
- `x1_r`: full/reference FEM floor 1 response.
- `x1_n`: numerical-substructure FEM floor 1 response.
- `x2_r`: full/reference FEM floor 2 response.
- `x2_n`: numerical-substructure FEM floor 2 response.
- `x3_r`: full/reference FEM floor 3 response.
- `x3_n`: numerical-substructure FEM floor 3 response.
- `d_r`: full/reference FEM response at the interface/control point.
- `d_n` or `dd`: numerical-substructure interface/control-point displacement command.

## Deferred Detailed Instructions

- Load `MATLAB_MCP_TOOLING.md` only immediately before doing work that involves MATLAB, Simulink, Speedgoat/SLRT, SAP/FEM workflows, MCP tool execution, browser/uncodixify recovery, GitHub CLI work, or recovery from a recurring command/tool failure.
- Do not load `MATLAB_MCP_TOOLING.md` for planning-only, discussion-only, or general code-reading prompts.
- If a MATLAB/Simulink task reaches implementation or verification, read `MATLAB_MCP_TOOLING.md` before running MATLAB, Simulink, Speedgoat, SLRT, or related MCP tools.
- If a tool/command fails in a way that might match a known workspace issue, read `MATLAB_MCP_TOOLING.md` before retrying.
