# Delay Compensator Simulink Setup

This setup inserts the optimized phase-lead compensator directly after the Hybrid Simulation numerical `dd` output, before the signal selector sends `dd` to the controller.

## Saved Compensator

The compensator file is:

```text
saved_results/delay_comp/phase_lead_dd_optimized.mat
```

It contains the continuous-time transfer function:

```matlab
G_T(s) = k_T*(s + z1)/(s + p1)
```

with:

```matlab
k_T = 17.0822354308;
z1 = 2*pi*1.20050665816;   % rad/s
p1 = 2*pi*20.5073373709;   % rad/s
```

This gives unity DC gain because `k_T*z1/p1 = 1`.

## Workspace Variables

Run `main_ColumnSetup.m` and select the delay-compensator MAT file when prompted. The main script loads the continuous transfer function and creates these workspace variables for Simulink:

```matlab
delay_comp_tf
delay_comp_tf_discrete
delay_comp_num
delay_comp_den
delay_comp_file
delay_comp_name
```

Use only these variables in Simulink:

```matlab
Numerator   = delay_comp_num
Denominator = delay_comp_den
SampleTime  = dt
```

## Manual Simulink Edit

Use MATLAB/Simulink R2020b for the model edit if possible.

1. Open `model_ColumnSetup_00.slx`.
2. Go to `Signal Generation`.
3. Find the line from `Hybrid Simulation` to `Multiport Switch`.
4. Insert a `Discrete Transfer Fcn` block on this line.
5. Rename the block to `HS Delay Compensator`.
6. Set the block parameters:

```matlab
Numerator:      delay_comp_num
Denominator:    delay_comp_den
Initial states: 0
Sample time:    dt
```

7. Wire it as:

```text
Hybrid Simulation/dd -> HS Delay Compensator -> Multiport Switch input 7
```

8. Do not place the compensator after the `Multiport Switch`; it should affect only the Hybrid Simulation path.
9. Save the model.

## Quick Check

After running `main_ColumnSetup.m` up to the model-open step, confirm:

```matlab
delay_comp_tf
delay_comp_num
delay_comp_den
```

The selected compensator should be printed in the command window before the Simulink model is opened.
