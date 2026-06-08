# Next in Simulink
0- Backup
1- at displays of the important parts (displacements d c m)
2- more cleanup and organization
3- color scop same as display and results
4- add virtual runn script with multiple checks (force displacements considering setpoint)
5- mass stiffness damping estimation
6- stability analysisand dsign controller
7- add controller to simulink and add switch to activat deactivate it and another switch to reset the I gain error to prevent jumps
8-online stiffness estimation (compare differeent methods, LSE, RLSE, TSE, RTSE, KF, UKF)
9- acceleration

# Bugs
1- stopping and resuming make the simulation scope buggy


# Next Work

1. Identification: test whether faster commands or slower MTS gains improve the experiment.
2. Accelerometer fixing.
3. Avoid the initial jump.
4. Pause workflow.
5. Save data while Simulink is running.
6. Ramp to the initial position.
7. Simulink controller.
8. Numerical model.
9. Two stability indicators: one for the numerical model and one for the experiment.
10. Stiffness estimation.
