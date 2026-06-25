# Output Verification Procedure

## MTS Setup

1. Turn on the MTS pressure.
2. Enable manual command.
3. Move the actuator until the force is approximately zero.
4. Turn off the manual command.
5. Check the interlock limits

## MATLAB Run
6. check the file name in the main script
7. check HS parametrs in the main script
8. Run the MATLAB main script.
9. Make sure all dashboard switches are down.
10. Click Run on target.
11. Make sure the dd is zero.
   [If the dd is not zero, use the Constant block to send to zero.]
12. switch to constant signal and change it to 2 and make sure you are reading the same in MTS. Then switch it back to 0
13. Select the right signal and the right parameters.
14. Set switch 1 up: zero measurement.
15. Check displacement and force measurement are zero.
16. Set switch 1 down.

## External Command Run
17. In the external command tab check target setpoint = measurement.
18. Check the external signal is zero
19. Run external command in MTS.

## Starting the test
20. Check the outer controller command is following dd (zero)
21. Switch 2 up → to run the outer controller
22. Set switch 3 up → simulation start.

## Finishing the test
23. Set switch 3 down to pause.
24. Set switch 4 up to ramp to initial position.

25. Stop external command from MTS
26. Set switch 2 down
27. Stop Simulink.
28. Set switch 4 down
29. In MATLAB command line, press space to save.

## Optional
   Optional pause:
   - Use switch 3 to pause / unpause smoothly.

   Optional if MTS interlock is triggered OR to change the signal:
   - In Simulink set switch 3 down
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


