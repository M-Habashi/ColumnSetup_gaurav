# Reference evidence archive

Evidence records for manuscript citations. Writing instructions are maintained in [writing_guide.md](../md/writing_guide.md).

## Maghareh2020 — manuscript reference [2]

**Source:** A. Maghareh, Y. Fu, H. Montoya, J. Condori, Z. Wang, S. J. Dyke, and A. Montoya (2020), “A reflective framework for performance management (REFORM) of real-time hybrid simulation.” Frontiers in Built Environment 6, 568742. [DOI](https://doi.org/10.3389/fbuil.2020.568742) · [Full PDF](https://par.nsf.gov/servlets/purl/10217004)

**Verified:** 2026-10-01. Read the abstract, introduction (p. 2) and the section “State Estimation, Model Updating, and Uncertainty Quantification” (p. 4) from the PDF text.

**Exact quotation — p. 4, “State Estimation, Model Updating, and Uncertainty Quantification”:**

> a part of the physical substructure may experience a failure, drastically changing its dynamics. Such a change will impact the safety and integrity of the experiment.

**Supporting excerpt — p. 2, introduction:**

> the need for aggressive control to maintain stability and safety

**Citation role:** Section 2.1. Supports that a failure in the physical substructure drastically changes its dynamics and affects the safety and integrity of the experiment. This motivates monitoring stability as the specimen degrades.

**Use and limits:** The paper is a framework paper. It does not quantify equipment damage or test termination, so the manuscript sentences on equipment damage and early termination are not attributed to it. It does not analyze the outer controller loop or the NCF margin.

**Origin check:** Not needed. The claim is cited as the authors' statement, not as a first finding.

## Welch1967 — manuscript reference [7]

**Source:** P. D. Welch (1967), “The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms.” IEEE Transactions on Audio and Electroacoustics 15(2), 70–73. [DOI](https://doi.org/10.1109/TAU.1967.1161901) · [Full PDF](https://ocean.phys.msu.ru/courses/geoseries/1967%20Welch%2C%20The%20Use%20of%20Fast%20Fourier%20Transform%20for%20the%20Estimation%20of%20Power%20Spectra_%20A%20Method%20Based%20on%20Time%20Averaging%20Over%20Short%2C%20Modified%20Periodograms.pdf)

**Verified:** 2026-09-24. Read the abstract, introduction, method, variance discussion, FFT application, and cross-spectrum extension. Abstract quotation checked against the rendered PDF.

**Exact quotation — p. 70, abstract:**

> The method involves sectioning the record and averaging modified periodograms of the sections.

**Citation role:** Supports the windowed segment construction for power and cross spectra. Welch forms a modified periodogram from each windowed segment on p. 70 and extends the construction to cross spectra on p. 73. His equal averaging differs from our recursive update, which uses Roberts's recurrence. Welch's variance factors do not establish the performance of that update.

**Result verification — 2026-09-24:** Rechecked the variance derivation and rendered pages 71–72. For his stationary Gaussian model with a locally flat spectrum and the stated spectral-window assumptions, Welch relates estimator variance to segment count and correlation between periodograms. His nonoverlapping limit gives 1/K of the variance of a single segment's periodogram. For fixed record and segment lengths, 50% overlap with his specified window W1 gives 11/18 of the variance obtained without overlap.

**Exact excerpt — p. 72, “The Variances of the Estimates”:**

> an overall reduction in variance for fixed record length

**Use and limits:** The variance analysis supplies a reason for averaging. These quantitative results concern Welch's assumptions, windows, and equal averaging. They do not establish the performance of our Hann-windowed, exponentially weighted estimator during specimen degradation.

**Origin check:** This is a primary method paper. It cites earlier work by Welch (1961) and related complex-demodulation work. Those earlier papers have not been examined here, so no claim of earliest invention is supported.

## Roberts1959 — manuscript reference [4]

**Source:** S. W. Roberts (1959), “Control chart tests based on geometric moving averages.” Technometrics 1(3), 239–250. [DOI](https://doi.org/10.1080/00401706.1959.10489860) · [Full PDF](https://www.stat.cmu.edu/technometrics/59-69/VOL-01-03/v0103239.pdf)

**Verified:** 2026-09-24. Read the abstract, introduction, recurrence in Section 2, test comparisons, conclusion, and reference list. Quotation and recurrence checked against rendered pages 239–240.

**Exact quotation — p. 239, abstract:**

> A graphical procedure for generating geometric moving averages is described in which the most recent observation is assigned a weight r.

**Citation role:** Section 2, p. 240, Eq. (1) gives the geometric moving-average recurrence. Applying that recurrence to spectra is our adaptation. Roberts initializes at a nominal process mean, not our first complete window. His control-chart comparisons do not validate our spectral estimator's efficiency.

**Application check — 2026-09-25:** Rechecked the original recurrence and its expansion on p. 240, and compared them with `main/control_and_HS/OSI/sol_osi.m`, lines 188–196. At each update, the previous spectral average is multiplied by (1 - eta_s) and eta_s times the new spectrum is added. Thus, the contribution of earlier data decays at each subsequent update. With first-window initialization, that initial spectrum can still outweigh the newest spectrum during startup. For example, eta_s = 0.39 gives weights 0.61 and 0.39 at the second complete window. Decaying past contributions is the property used here. Roberts's control-chart detection results do not establish tracking or variance performance for this spectral adaptation.

**Origin check:** The introduction credits a graphical suggestion to J. W. Tukey and cites Roberts's 1958 zone-test paper. This supports citing Roberts's published recurrence, not claiming sole or earliest invention.

## WuWang2020 — power-based discrimination of operating regime (manuscript key `wu`)

**Source:** H. Wu, X. Wang (2020), “A mode-adaptive power-angle control method for transient stability enhancement of virtual synchronous generators.” IEEE Journal of Emerging and Selected Topics in Power Electronics 8(2), 1034–1049. [DOI](https://doi.org/10.1109/JESTPE.2020.2976791). The metadata was checked against Crossref.

**Verified:** Abstract only (2026-09-26). The open accepted manuscript at vbn.aau.dk sits behind a browser challenge.

**Exact quotation — abstract:**

> In this approach, the positive-feedback mode of the power-angle control of the VSG is detected and adaptively switched to the negative-feedback mode after large disturbances.

**Citation role:** Section 3.3 says the output-power branch “is inspired by” this work. The author supplied the specific claim, that they “used active-power deviation and its rate of change to discriminate changes in the transient operating regime”, and asked for it to be used without further checking (2026-09-26). That detail has not been verified against the body of the paper.

## BlackmanTukey1958 — Hann window (manuscript key `blackman`)

**Source:** R. B. Blackman, J. W. Tukey (1958), “The measurement of power spectra from the point of view of communications engineering — Part I.” The Bell System Technical Journal 37(1), 185–282. [DOI](https://doi.org/10.1002/j.1538-7305.1958.tb03874.x) · [Internet Archive](https://archive.org/details/bstj37-1-185)

**Verified:** 2026-09-26. Searched the full OCR text. Rendered p. 200 and checked the quotation against the page image. Also read the glossary entry and the discrete-smoothing form in Section B.

**Exact quotation — p. 200, Section 5 “Two particular window pairs”:**

> A simple and convenient compromise is represented by the lag window (whose use is called “hanning”)

The preceding sentences explain the compromise between concentrating the main lobe near f = 0 and keeping the side lobes low. The window is D₂(τ) = ½(1 + cos πτ/T_m) for |τ| < T_m.

**Glossary (OCR, not image-checked):** “Hanning — The operation of smoothing with weights 0.25, 0.50 and 0.25. (After Julius von Hann.)”

**Citation role:** Supports the raised-cosine shape and the name. Blackman and Tukey apply it as a *lag* window on the autocorrelation, or equivalently as 0.25/0.5/0.25 smoothing of the raw spectrum. Applying it as a data window to the samples before the DFT is our adaptation. Suitable verb: “presented … as a simple and convenient compromise”. Do not write “introduced”, because the text does not claim priority. Hamming appears as the alternative. The manuscript uses “presented by” (author decision, 2026-09-26).

**Origin check:** Not the origin. The phrase “whose use is called ‘hanning’” implies prior use. The weights are named after Julius von Hann (meteorology). The paper builds on Tukey (1949), “The Sampling Theory of Power Spectrum Estimates” (Woods Hole symposium, ONR NAVEXOS-P-735), Press and Tukey (1956), and an unpublished Hamming–Tukey memorandum, “Measuring Noise Color” (refs. 4 and 26, p. 193 and the reference list). None of these were read.

## DiMatteo2021 — running median over neighbouring frequencies (manuscript key `dimatteo`)

**Source:** S. Di Matteo, N. M. Viall, L. Kepko (2021), “Power spectral density background estimate and signal detection via the multitaper method.” Journal of Geophysical Research: Space Physics 126(2), e2020JA028748. [DOI](https://doi.org/10.1029/2020JA028748). Open access (CC BY), but Wiley, ESSOAr and NTRS refused scripted downloads on 2026-09-26.

**Verified:** NOT against the PDF. The author supplied the following summary of §4.1 on 2026-09-26:

> Strong signal peaks can bias a fitted PSD background upward; smoothing is proposed to reduce that influence. The next paragraphs define the Mann–Lees running median over 2w+1 frequency points, describe shorter windows at the frequency limits, and warn that the median can distort a steep spectrum. They say window width must be chosen carefully so smoothing does not erase the shape being estimated.

**Citation role:** Supports the running median over neighbouring frequencies used in Equation (17), with w = 1 (three points). The manuscript says “discussed by”, not “proposed by”.

**Origin check:** §4.1 credits the running median to Mann and Lees (1996), “Robust estimation of background noise and signal detection in climatic time series,” Climatic Change 33, 409–445. Not read. The author chose not to cite it (2026-09-26).

**To do:** Open the PDF, replace the summary with an exact §4.1 quotation and its page number, and check that the three-point window and the edge handling agree.

## Tukey1971 — running medians (manuscript key `tukey`, removed from the manuscript 2026-09-26)

**Source:** J. W. Tukey (1971), *Exploratory Data Analysis*, Limited Preliminary Edition, Vol. III, Chapter 29y “Less simple examples.” Reading, MA: Addison-Wesley. [Internet Archive item](https://archive.org/details/tukey-eda-preliminary) · [Chapter PDF](https://archive.org/download/tukey-eda-preliminary/Limited_Preliminary_Edition/Volume_III/29y_Less_Simple_Examples.pdf). The published 1977 edition (Chapter 7, “Smoothing sequences”) is access-restricted on the Internet Archive and has NOT been read.

**Verified:** 2026-09-26. Searched the OCR text of all 54 preliminary-edition chapters and handouts for running medians. Rendered PDF page 29y-47 and checked the quotation against the page image.

**Exact quotation — p. 29y-47, Section 29yH “How far have we come?”:**

> The process of fitting smooth curves alternates between smoothing by running medians and eye fitting smooth curves to points. The particular running median smoothing recommended is to first take medians of 5 and then to take medians of 3 of these (medians of 5) where this makes a difference.

**Supporting excerpt, OCR only and not checked against the image — Exhibit 9 discussion (about p. 29y-20):** “medians are found for each batch of three consecutive results of the 1st step”.

**Citation role:** Supports smoothing an ordered sequence by running medians, including medians of three consecutive values. Tukey recommends medians of 5 followed by medians of 3. He does not recommend medians of 3 alone. He applies them to curve fitting, not to spectral margin curves. Our use of medians of 3 over neighbouring frequency bins (`sol_osi.m` line 211, `movmedian(..., 3)` along frequency) is an adaptation.

**Origin check:** This text neither claims nor disproves that Tukey originated running medians. Do not write “proposed by Tukey” without a further origin check (for example Tukey 1974, “Nonlinear (nonsuperposable) methods for smoothing data”).

## Published examples of citation use

The following records support the five examples in writing_guide.md. Each relevant PDF page was rendered and visually checked on 2026-09-25. The claims verified here concern what the citing article says and how it uses the citation. The cited predecessors have not been independently verified for these examples. Their scientific claims are not evidence for Paper 2. Short complementary quotations below and the excerpts in write.md together stay within 25 quoted words per source.

### Shrestha2013

**Source:** B. Shrestha, H. Hao, and K. Bi (2013), “Pounding and Unseating Damage Mitigation on Bridge Structures subjected to Spatially Varying Ground Motions using Restrainers and Rubber Bumpers.” Australian Earthquake Engineering Society 2013 Conference, Tasmania, November 15–17. [Original PDF](https://www.aees.org.au/wp-content/uploads/2015/06/3-Shrestha-Bipin-Pounding.pdf). No DOI verified.

**Sections checked:** Abstract, introduction, Section 3, conclusion, and relevant references. Excerpt: PDF p. 6, unnumbered.

**Exact supporting excerpt — Section 3, PDF p. 6:**

> the latter method is thus computationally more efficient

**Connection:** The paragraph compares iteration requirements, attributes the favorable result to Bi and Hao (2012), and adopts their method for New Zealand design-spectrum-compatible inputs. This illustrates a result supporting a choice.

### Galmez2020

**Source:** Cristóbal Gálmez and Gastón Fermandois (2020), “Online Stability Analysis for Real-Time Hybrid Simulation Testing.” Frontiers in Built Environment 6:134. [DOI](https://doi.org/10.3389/fbuil.2020.00134) · [Original PDF](https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2020.00134/pdf).

**Sections checked:** Abstract, introduction, Section 3.2 Critical Delay Estimation, and adjacent Section 4.1. Excerpt location: printed p. 6.

**Exact supporting excerpt — Section 3.2, p. 6:**

> This critical delay serves as a reference

**Connection:** Gao and You's method supplies equivalent system properties and an eigenvalue-based critical delay. The paper obtains 8.5 ms for its model and uses it to interpret constant-delay simulations. The value belongs to that model, not to Paper 2.

### Ou2020

**Source:** Ge Ou, Ge Yang, Shirley Dyke, and Bin Wu (2020), “Investigation of Hybrid Simulation With Model Updating Compared to an Experimental Shake Table Test.” Frontiers in Built Environment 6:103. [DOI](https://doi.org/10.3389/fbuil.2020.00103) · [Original PDF](https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2020.00103/pdf).

**Sections checked:** Section 3.1 and the preceding case description, printed p. 4, including model equations.

**Exact supporting excerpt — Section 3.1, p. 4:**

> pinching and degradation

**Connection:** The case description attributes the nonlinear model to Baber and Wen (1981) and Baber and Noori (1985). The next paragraph identifies the physical effects it represents and connects them to Equations (7)–(16). This demonstrates model attribution linked to a modeling need, without transferring those capabilities to a different specimen model.

### Nugroho2021

**Source:** B. Nugroho, J. P. Monty, I. K. A. P. Utama, B. Ganapathisubramani, and N. Hutchins (2021), “Non-k-type behaviour of roughness when in-plane wavelength approaches the boundary layer thickness.” Journal of Fluid Mechanics 911, A1. [DOI](https://doi.org/10.1017/jfm.2020.875) · [Accepted manuscript PDF](https://eprints.soton.ac.uk/444123/1/nugroho_et_al_2020.pdf).

**Sections checked:** Section 2.6 Estimating skin friction, accepted-manuscript p. 8, checked in the downloaded PDF.

**Exact supporting excerpt — Section 2.6, p. 8:**

> outer layer similarity

**Connection:** Rough-wall measurements make the modified Clauser estimate uncertain, so the authors choose Monty et al.'s friction-velocity method with its outer-layer assumption. Their main conclusions remain unchanged with the alternative estimate. The preference is specific to this experiment.

### Rees2011

**Source:** D. Andrew S. Rees (2011), “The Effect of Local Thermal Nonequilibrium on the Stability of Convection in a Vertical Porous Channel.” Transport in Porous Media 87(2), 459–464. [DOI](https://doi.org/10.1007/s11242-010-9694-5) · [Author-hosted publisher PDF](https://people.bath.ac.uk/ensdasr/PAPERS/TOAPPEAR/ReesChannel-personal.pdf).

**Sections checked:** Abstract and Introduction, printed pp. 459–461. Main excerpt: p. 460, PDF page 4 because the file includes two cover pages.

**Exact supporting excerpt — Introduction, p. 460:**

> energy analysis of the linearised disturbance equations

**Connection:** Rees attributes an energy analysis and a linear-stability result to Gill (1969), then uses it to investigate separate solid and fluid temperatures. This connects a borrowed analysis to a new question.
