# Output Verification Procedure

## MTS Setup

1. Turn on the MTS pressure.
2. Enable manual command.
3. Move the actuator until the force is approximately zero.
4. Turn off the manual command.
5. Check the interlock limits

## MATLAB Run
6. check the file name in the main script
5. Run the MATLAB main script.
6. Make sure all dashboard switches are down.
7. Click Run on target.
8. Make sure the dd is zero.
   [If the dd is not zero, use the Constant block to send to zero.]
9. Select the right signal and the right parameters.
10. Set switch 1 up: zero measurement.
11. Check displacement and force measurement are zero.
12. Set switch 1 down.

## External Command Run
13. in the external command tab check target setpoint = measurement.
14. check the external signal is zero
15. Run external command in MTS.

## Starting the test
16. Check the outer controller command is following dd (zero)
16. Switch 2 up → to run the outer controller
16. Set switch 3 up: simulation start.

## Finishing the test
17. Set switch 3 down to pause.
18. Set switch 4 up to ramp to initial position.

19. Stop external command from MTS
21. Set switch 2 down
20. Stop Simulink.
21. Set switch 4 down
21. In MATLAB command line, press space to save.

## Optional
   Optional pause:
   - Use switch 3 to pause / unpause smoothly.

   Optional if MTS interlock is triggered OR to chang the signal:
   - In Simulink set both switch 3 down 
   - In Simulink set switch 4 up to stop simulation
   - In MTS turn on pressure (if triggered directly → increase gains)
   - In MTS use manual command to move to initial position
   - In MTS make sure: target stepoint = measurement AND external command = zero
   - In Simulink zero measurement
   - In simulink turn off the controller then turn on the controller
   - In MTS run external command
   - In Simulink set switch 4 down
   - IN Simulink set switch 3 up

   Retuning:
   - Pause
   - set the square signal setpoint and amplitude
   - switch the signal type to square
   - tune
   - switch back to the correct signal
   - resume


