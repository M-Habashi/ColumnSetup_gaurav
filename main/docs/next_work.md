# Things to test
1- make the assumptions of FEM clear
    - no shear deformation
    - floor diaphram unify x translation but doesn't prevent rotation
2- make reference model choice clear 
    - base rotational spring is chosen to match the experimental rotational stiffness
    - reference model floor height is selected sothat the zero bending moment (inflection point) is at the same height as the actual control point (40")
3- try to fix the blackbox fit
4- online stability indicator based on NCF margin.
    - Kalman filter where each point is a state
    - coherence based updating
5- think about controllr switching / blending
6- Try on the changing PID controller high and low frquency records



# Next
Phase 2:
1- add virtual run script with multiple checks (force displacements considering setpoint)
2- NUmerical substructure and hybrid simulation signal type with time scaling option in the signal picker
4- system updating (from command to dm) based on xfunc and weighted by coherence (bayessian updating) (high amp points that cause instability will appear obviously causing high coherence)
5- stability indication using the system and the controller
6- interpolate PID to keep a predefined stability margin

# Maybe
1- improve stiffness estimation to avoid significant drops when LSE fallbacks are used
2- acceleration
3- Save data while Simulink is running.

# Bugs
