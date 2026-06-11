# Output Verification Procedure

## MTS Setup

1. Turn on the MTS pressure.
2. Enable manual command.
3. Move the actuator until the force is approximately zero.
4. In the external command tab, make sure:
   setpoint = measured displacement


## MATLAB Run

1. Make sure all dashboard switches are down.
2. Run the MATLAB main script.
3. Click Run on target.
4. Make sure the command is zero.
5. If the command is not zero, use the Constant block to send to zero.
6. Select the right signal and the right parameters.

## External Command Run

1. Run external command in MTS.

## Starting the test

1. Set switch 2 up: zero measurement.
2. Check displacement and force measurement go to zero.
3. Set switch 2 down.

4. Set switch 3 up: simulation start.

   Optional pause:

   - Use switch 2 to pause.
   - Before turning simulation back on

   Optional manual command:

   - Disable control and send manual command if needed.
   - Decide the next action before re-enabling the simulation.

   optional changing signal (not during test):
   - pause
   - stop simulation
   - change signal
   - resume / unpause
   - continue / unstop

## Finishing the test
5. Set switch 3 down to pause.
6. Set switch 4 up: ramp to relative zero (initial position).
7. Stop Simulink.
8. Set switch 4 down.

## MTS External command stop
1. Stop External command.

## Saving results
2. In MATLAB, press space to save.


##############################################
##Analysis work flow:
###identification
1- run simulink on target with BLWN (without controller)
2- create_specimen_mat
3- run fromDatatoParametric

###controller design:
4- stabilility analysis