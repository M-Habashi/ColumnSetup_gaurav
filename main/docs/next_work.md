# NOW
- fix signal selector and its if condition
- Think about optimizing the phase lead or delay compensator 
    -- should it be autonomous?
    -- what plots to show in what colors
    -- what is the new order of folders
- Building FEM should be a separate folder from vHS and the compensator is probably another folder
- The final plot should plot the reference response with the measures and the error indicators
- compare the results based on a selectd window and show error indicators
- the vHS should include also num_PID_H_exp and compare the results in a table and in the figure
- vHS should show dc and maximum dm fm dc in a table
- button in simulink to flag specific times (maybe just constant logged to b chaged)
- hysterisis
- HS (find the scale automatically to achieve desired max displacement, change time scale, load from earthquakes, final accelerations to be sent is zero)
- virtual simulaitons (load the dc to dm model and the noise level)

# THings to test:
- New stiffness eestimator
- New optimized controller (careful)
- HS (different intensities / different time scales)
- Pause / Unpause HS
- Can I change HS speed fromsimulink?

# Next set of data
- data file for each P_inner value
- one file for the changing P_value but with known time of changing
- For AI let it experiment while the new where is every changing and what is the model at eacch region


# Pending
- close sap after finishing
- Fix the html to reflect correct information on the plots (we may remove the loads)
- check the assumptions of FEM clear
    - no shear deformation
    - floor diaphram unify x translation but doesn't prevent rotation
    - rotational stiffnesses
- can we print critical time delay from the hybris ss? and the ncf margin too? and  compare with Amin's recommendations? for different values of k factor too 


# Things to test
2- make reference model choice clear 
    - base rotational spring is chosen to match the experimental rotational stiffness
    - reference model floor height is selected sothat the zero bending moment (inflection point) is at the same height as the actual control point (40")
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
