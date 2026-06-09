# Output Verification Procedure

## MTS Setup

1. Turn on the MTS pressure.
2. Enable manual command.
3. Move the actuator until the force is approximately zero.
4. In the external command tab, make sure:
   setpoint = measured displacement


## MATLAB Run

1. Make sure all dashboard switches are down.
2. Run the MATLAB setup script.
3. Run the Simulink model on target.
4. Make sure the command is zero.
5. If the command is not zero, use the Constant block to send zero.
6. Select the right signal and the right parameters.

## External Command Run

1. Run external command.

## Output Verification Sequence

1. Set switch 2 up: zero measurement.
2. Confirm displacement measurement goes to zero again.
3. Set switch 2 down.

4. Set switch 3 up: simulation start.

   Optional pause:

   - Use switch 2 to pause.
   - Before turning simulation back on, check what needs to be verified.

   Optional manual command:

   - Disable control and send manual command if needed.
   - Decide the next action before re-enabling the simulation.

5. Set switch 3 down.
6. Set switch 4 up: ramp to relative zero, which is the initial position.
7. Stop Simulink.
8. Set switch 4 down.

## MTS MPT Pause

1. Pause MTS MPT.
2. Stop Simulink.
3. In MATLAB, press space to save.
