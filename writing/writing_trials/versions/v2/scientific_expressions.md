# Scientific expressions for the manuscripts

Version 1. Source terms are preferred vocabulary, not permission to introduce additional claims.
An expression can be legitimate in another context and still be unnecessary here.
Ordinary words do not need to appear in this dictionary.

## Paper 1 vocabulary

Source: SCHM_Main_Manuscript_Rev1.docx in aab paper1/writing/submit/Paper Submit 02.
Paragraph identifiers refer to direct body paragraphs recorded in writing_trials/paper1_paragraphs.json.

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

## Paper 2 scope

The Paper 2 definitions and notation are in writing.md. They are not interchangeable with Paper 1.
Paper 2 uses the adaptive factor lambda and continuous scaling. Paper 1 uses controller switching.
For Paper 2 manuscript prose prefer "hybrid simulation", "experiment", and "initial".
Keep named blocks and symbols unchanged unless the source or author explicitly changes them.
