# Computational block map

The executable model blocks are separated as follows:

| Model function | MATLAB implementation |
|---|---|
| Ground record / chirp / selector / scaling | `blk_ground_acceleration.m`, `blk_chirp_signal.m` |
| Numerical State-Space and force Unit Delay | `blk_numerical_substructure.m`, `blk_numerical_dynamics.m`, `blk_force_unit_delay.m` |
| Phase-lead A/D, DSS, D/A | `blk_ad_converter.m`, `blk_phase_lead_controller.m`, `blk_da_converter.m` |
| Original tracking A/D, DSS, D/A | `blk_ad_converter.m`, `blk_tracking_controller.m`, `blk_da_converter.m` |
| Converter primitives | `blk_saturation.m`, `blk_quantizer.m` |
| Tunable continuous PI A, B, and C | `scripted_build_trial.m`, `blk_pi_controller.m` |
| Controller blend, selection, and final switch | `blk_controller_blend.m`, `blk_controller_select.m`, `blk_control_switch.m` |
| Bouc-Wen moving-LSE alpha estimate, indicator functions, and rate hold | `blk_moving_lse_stiffness.m`, `blk_indicator_margin.m`, slow-task state in `scripted_engine.m` |
| Repeatable hysteretic A/B switch and continuous return timer | `blk_controller_switch_update.m` |
| Initial controller, switch target, and linear-ramp beta | `blk_beta_value.m` |
| Damage mode and legacy profile | `blk_damage_switch.m`, `blk_alpha_profile.m` |
| Degrading Bouc-Wen z/work evolution, major-sample update, and restoring force | `blk_bouc_wen_derivative.m`, `blk_bouc_wen_update.m`, `blk_bouc_wen_restoring_force.m` |
| Servo-valve Transfer Fcn | `blk_servo_valve_dynamics.m` |
| CSI Derivative and actuator Transfer Fcn | `blk_derivative_major.m`, `blk_derivative_minor.m`, `blk_actuator_dynamics.m` |
| Legacy/Bouc-Wen experimental dynamics | `blk_experimental_acceleration.m` |
| Experimental feedback-force products/sum | `blk_feedback_force.m` |
| Sensor noise, gain, and sum | `blk_sensor_noise.m`, `blk_sensor_output.m` |
| Time-simulation reference dynamics | `blk_reference_dynamics.m` |
| Fixed no-damage/linear-analysis reference `lsim` | `blk_reference_response.m` |
| Fixed-step ode4 scheduler | `blk_rk4_step.m`, optimized `scripted_rhs_hot.m`; `scripted_rhs.m` remains the one-block-call reference path |
| To Workspace / result evaluation / plots | `scripted_engine.m`, `blk_evaluation.m`, `blk_plot_rths.m`, `blk_plot_indicator.m` |

Routing-only blocks—Inport/Outport, Mux/Demux, Goto/From, Bus Creator,
Display, Scope, and Terminator—are represented by named variables and struct
fields. They contain no numerical transformation and therefore do not need
executable placeholder files.
