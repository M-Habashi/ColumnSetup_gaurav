# Simulink Changes

## Change 1: OSI Authority Immediate-Drop Threshold

The OSI authority gain law now sets the severe/immediate-drop threshold as:

```matlab
down_immediate_margin = 0.25 * target_outer_ncf;
```

For the current target:

```matlab
target_outer_ncf = 0.3;
```

this gives:

```matlab
down_immediate_margin = 0.075;
```

This means normal below-target NCF values, such as `0.28`, are no longer treated as severe. They must persist for the configured confirmation count before the authority factor drops. Only very low NCF values trigger the immediate-drop path.

Clarification on where the authority factor is applied:

If the authority factor `a` is constant, multiplying the PID output by `a` is effectively the same linear loop as using a PID with gains `a*P`, `a*I`, and `a*D`.

They become different mainly when `a` changes while the test is running. Multiplying the PID output immediately scales everything the PID has already built up, including the integrator contribution. Scaling the PID gains changes how strongly the PID reacts from that point onward. So with adaptive authority, they can give different transients even if the steady linear effect is similar.
