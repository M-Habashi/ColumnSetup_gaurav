# Stability:
- Try to design the phase_lead as a notch to be more robust [the notch is arount the the crossover phase? what is that 35hz?]
- Try to penalty the control max command whileoptimizing the PL
- think about how can w update the authority gain
- understand and test claude M7, try to link it to NCF
- Test !!


# NOW
- compare the results based on a selectd window and show error indicators
- button in simulink to flag specific times (maybe just constant logged to b chaged)
- HS (find the scale automatically to achieve desired max displacement, change time scale, load from earthquakes, final accelerations to be sent is zero)
- virtual simulaitons (load the dc to dm model and the noise level)

# Things to test:
- OSI

# Pending
- check the assumptions of FEM clear
    - no shear deformation
    - floor diaphram unify x translation but doesn't prevent rotation
    - rotational stiffnesses

# Bugs
