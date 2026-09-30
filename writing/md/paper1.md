# Paper 1 — Context and vocabulary

Paper 1 is Gomaa et al., cited as [2]. It is background for Paper 2. Do not assume that its results or claims transfer to Paper 2 without checking their source and relevance.

- **Directory:** `C:\Users\Victus\Desktop\folder_working\a purdue\aa reasearch\aab paper1`
- **Manuscript:** `aab paper1/writing/submit/Paper Submit 02/SCHM_Main_Manuscript_Rev1.docx`
- **Paragraph identifiers** below refer to direct body paragraphs recorded in [paper1_paragraphs.json](../.agent/paper1_paragraphs.json).

## What Paper 1 showed

Delay-based indicators assess only the numerical substructure loop. Paper 1 showed that degradation threatens the **outer controller loop**, which those indicators miss.

**Why degradation causes instability:**
1. The outer controller is tuned to overcome the initial stiffness and to meet the tracking target.
2. When the specimen degrades, its stiffness decreases and it becomes easier to move.
3. The same control action then overshoots, and the response is amplified.
4. The dynamics of the outer controller loop change, and its stability margin shrinks.

This is a **gain amplification** mechanism, not a time delay. Flexible specimens (higher mass, lower stiffness-to-mass ratio) are more susceptible.

**Paper 1's indicator** is the NCF margin, b_g(C_out, T).
- It splits the loop into the outer controller C_out and the plant T.
- Its value is at most the scaled margin b_s(L).
- b ≥ 0.4 guarantees the usual gain- and phase-margin targets and is the practical guideline for experiments.
- It was computed online from a parametric model, updated with a stiffness factor α estimated by least squares from force and displacement.
- It was demonstrated numerically (virtual hybrid simulation of a modified benchmark), not experimentally.
- Intervention was a Lyapunov-guaranteed switch from a high-performance controller to a high-robustness one.

## Vocabulary

Source terms and verb phrases are preferred vocabulary, not permission to introduce additional claims. An expression can be legitimate in another context and still be unnecessary here. Ordinary words do not need to appear in this list.

| Expression | Meaning or use | Source paragraphs |
| --- | --- | --- |
| hybrid simulation | Partition of a structure into numerical and physical substructures | 11 |
| real-time hybrid simulation (RTHS) | The real-time method used in Paper 1 | 12 |
| numerical substructure | Numerically evaluated part of the structure | 11, 22 |
| physical substructure / specimen | Structural component represented physically | 11, 46, 48 |
| transfer system | System that imposes the computed response on the physical substructure | 22, 35–45 |
| servo-valve | Regulates hydraulic oil flow into actuator chambers | 38 |
| hydraulic actuator | Converts hydraulic energy into force or displacement imposed on the specimen | 40 |
| control-structure interaction | Physical coupling between actuator and experimental structure | 42 |
| inner loop controller | Typically the hardware PID supplied with the hydraulic system | 44 |
| outer loop controller / outer controller loop | The user-defined controller / the feedback loop containing it. A controller and a loop are different objects | 45, 55 |
| tracking performance | How well the imposed response follows the target | 56 |
| initial stiffness | Specimen stiffness before degradation | 56 uses original stiffness condition |
| stiffness degradation / loss of stiffness | Reduction in specimen stiffness | 51, 56 |
| corrective control action | Controller action responding to the tracking error | 56 |
| displacement response | Displacement resulting from the imposed control action | 56 |
| response amplification | Increase in the response relative to the initial condition | 56 |
| specimen mass | A property influencing amplification. This entry establishes no direction of influence | 56 |
| gain amplification | Mechanism suggested by the example's gain and delay margin trends | 55 |
| instability mechanism | Physical or dynamic mechanism leading to instability | 55–57 |
| stability indicator | Quantity used to assess stability or robustness | 54–57 |
| short-window linear approximation | Approximation used to analyze evolving degradation over short time windows | 52 |
| degradation factor | Parameter describing stiffness loss in the adopted model | 51 |
| controller switching | Paper 1's intervention between two controllers | 19, 57 |

## Scientific verb phrases and physical roles

These examples preserve standard relationships. They are not sentence templates to paste into every paragraph.

| Intended meaning | Natural expression | What to check | Source paragraphs |
| --- | --- | --- | --- |
| Measurement instrumentation | The specimen is instrumented with sensors | Sensors are measuring devices. They do not install instrumentation. Avoid making them the actor of "instrument the specimen" | 22 |
| Actuator excitation | Actuators excite the physical substructure / the physical substructure is excited by actuators | Either voice is appropriate. Keep the physical role unchanged | 22 |
| Numerical calculation | The numerical substructure computes the response / the numerical substructure is evaluated in real time | Use the expression that matches the intended claim. A response and a model are different objects | 22, 35 |
| Controller design | The controller is tuned to achieve the required tracking performance | The controller receives the tuning action. Do not force an active subject merely to avoid passive voice | 56 |

If a needed technical expression is absent, consult the relevant source or ask about the meaning. Do not rename a known block for variety. Ordinary connective prose remains free to vary.

## Differences from Paper 2

Paper 2 definitions and notation are in [paper2.md](paper2.md). They are not interchangeable with Paper 1. Paper 2 uses the adaptive factor λ and continuous scaling. Paper 1 uses controller switching. Keep named blocks and symbols unchanged unless the source or author explicitly changes them.
