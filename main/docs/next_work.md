# Understand
- forgtting? memory?
- recovery
- fix naming
- discuss the novel phase lead

# Stability:
- Try to design the phase_lead as a notch to be more robust [the notch is arount the the crossover phase? what is that 35hz?]
- Try to penalty the control max command whileoptimizing the PL
- think about how can w update the authority gain
- understand and test claude M7, try to link it to NCF
- Test !!


# NOW
- first what are the wierd question of robust optimizer?
- optimize both rths and outer loops ncf with different targets (optimizing outer can be simply optimizing the auth factor)
- understand the notch opt code can we make it more stable?
- how does it consider robust damaged ncf
- organize rths ibnputs in the main script
- in the reminder report only file names and show intensity and time scale
- add the osi switch to the procedure
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
