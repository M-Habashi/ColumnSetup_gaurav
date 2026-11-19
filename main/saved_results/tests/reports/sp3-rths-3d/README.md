# SP3 RTHS 3D replay

Serve the reports directory as the web root and open `/sp3-rths-3d/`.
The app uses browser modules and relative asset URLs. It does not need a separate
build step or a change to the reports site's build settings.

The page replays test `sp3_r_2` from `20261111_1810_testing_OSI.mat`.
The browser data were exported from `sp3_r_2_anim_data.mat` by
`main/results_analysis/rths_animation/v3_spatial_replay/tools/export_replay.py`
in `M-Habashi/experimental_osi`. In `data/`, `run.json` describes the run,
`signals.bin` contains 200 Hz measured and replayed signals, and `frame.bin`
contains 30 Hz numerical frame states.

The timeline drives the model, plots and both clips. For the original camera,
the player reads the measured lab clock, subtracts the camera start time, and
divides by the 20× time scale to locate the frame in the condensed MP4. The
analysis film is already indexed by earthquake time. Outside the lab camera's
coverage, the player offers the analysis film for the rest of the record.

Three.js 0.185.0 and its used add-ons are vendored under `vendor/three`.
The DM Sans and IBM Plex Mono fonts are vendored under `vendor/fonts`.
The library and font licenses are included with the assets. Surface textures
are from Poly Haven (CC0).
