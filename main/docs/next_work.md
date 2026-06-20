# Pending
- Sap folder organization (only keep the files that i care about in sap folder and move others into utils_sap)
- sap building_rf should ask me about the specimen
- clear running files can be added to the cleanup to or separate cleaning
- close sap after finishing
- it should create ref_[specimen].mat
- ref and ref_all and nume_exp should ask about the specimen and load the corresponding ref_[specimen].mat if not existing ot should inform the user to run build_ref first
- now test the num_exp with the correct k
- now the rlation between the feedback and numerical is not 2 anymore, this number must be very clear.
- The axial force at the interface
- Fix the html

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
