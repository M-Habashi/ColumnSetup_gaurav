import re, json, html, os, sys, datetime
from urllib.parse import quote_plus
from latex2mathml.converter import convert


ARGMIN_BAD = '<mo /><mrow><mi>a</mi><mi>r</mi><mi>g</mi><mspace width="0.167em" /><mi>m</mi><mi>i</mi><mi>n</mi></mrow>'

def mml(tex, block=False):
    m = convert(tex, display="block" if block else "inline")
    return m.replace(ARGMIN_BAD, '<mo>arg&#x2009;min</mo>')

EQ = {}      # key -> number
WORD = {}    # "eqN" -> UnicodeMath
def eq(key, tex, word):
    n = len(EQ) + 1
    EQ[key] = n
    WORD[f"eq{n}"] = word
    return (f'<div class="equation" id="eq{n}"><div class="expression">{mml(tex, True)}</div>'
            f'<span class="eqno">({n})</span></div>')

def ref(k):
    return f'Equation <a href="#eq{EQ[k]}">({EQ[k]})</a>'

def inline(text):
    text = re.sub(r"\$(.+?)\$", lambda m: mml(m.group(1)), text)
    return text

def eqs_range(a, b):
    return f'<a href="#eq{EQ[a]}">({EQ[a]})</a>–<a href="#eq{EQ[b]}">({EQ[b]})</a>'

parts = []
P = lambda t: parts.append(f"<p>{inline(t)}</p>")
H2 = lambda num, t, id_: parts.append(f'<h2 id="{id_}"><span class="secno">{num}</span>{t}</h2>')
E = lambda *a: parts.append(eq(*a))
RAW = parts.append
H1 = lambda num, t, id_: parts.append(f'<h1 id="{id_}"><span class="secno">{num}</span>{t}</h1>')

def trow(cells, tag="td"):
    return "<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in cells) + "</tr>"

# ---------------------------------------------------------------- content

H1("2", "Problem formulation", "sec2")
H2("2.1", "Motivation", "s21")
P("Hybrid simulation relies on the transfer system to impose the computed displacements on the specimen. When the "
  "outer controller loop loses stability, the actuator drives the specimen far beyond its intended response. Such "
  "instability creates safety hazards for laboratory personnel. In addition, it can damage the specimen and expensive "
  "equipment such as the actuator and servo-valve. An unstable test is also usually terminated early, so the "
  "experiment fails and must be repeated with a new specimen. {citet:maghareh} noted that a failure in part of the "
  "physical substructure can drastically change its dynamics. They also noted that such a change affects the safety "
  "and integrity of the experiment.")
P("{citet:gomaa} showed that specimen degradation can cause this instability. As the specimen degrades, its "
  "stiffness decreases and the same control action produces a larger response. The resulting gain amplification "
  "reduces the stability margin of the outer controller loop. However, that finding was obtained from a virtual "
  "hybrid simulation. This section therefore examines whether the same mechanism appears in a physical experiment.")
H2("2.2", "Experimental setup", "s22")
P("Figure 1 shows the experimental setup. The specimen is a steel column. Its base is anchored to a concrete block "
  "with four Hilti anchors, and its top is connected to the actuator. An MTS hydraulic actuator with a capacity of "
  "10 kip imposes the lateral displacement at the top of the column. The internal LVDT of the actuator measures this "
  "displacement. A Speedgoat real-time target sends the command to the actuator at 2048 Hz.")
RAW('<figure id="fig_setup"><img src="figures/fig_setup.jpg" alt="Steel column specimen anchored to a concrete block and loaded laterally by an MTS actuator" style="width:60%;max-width:100%;display:block;margin:0 auto;background:#fff"/><figcaption><b>Figure 1.</b> Experimental setup: steel column specimen anchored to a concrete block and loaded laterally by a hydraulic actuator.</figcaption></figure>')
P("Damage is introduced through the anchorage. As the specimen is pushed, the concrete around the anchors cracks. "
  "This cracking is an early stage of concrete breakout. The breakout cone did not form, and the cracks were not "
  "yet visible, so the damage is partial. The base nevertheless loses part of its rotational stiffness. "
  "Consequently, the lateral stiffness at the actuator control point decreases.")
P("No numerical substructure is involved in the tests of this section. The reference $u(t)$ is a prescribed "
  "displacement, so only the outer controller loop is closed. Figure 2 shows this loop. The outer controller $C(s)$ "
  "acts on the tracking error $u(t)-y(t)$ and sends the command $v(t)$ to the plant $H(s,k)$. The measured "
  "displacement $y(t)$ is then fed back to the controller.")
RAW('''<figure id="fig_loop"><svg role="img" aria-labelledby="flt fld" viewBox="0 0 560 130">
<title id="flt">Outer controller loop used in the tests of Section 2</title>
<desc id="fld">The reference u enters a summing junction, where the measured displacement y is subtracted. The tracking error enters the controller C(s), which sends the command v to the transfer system and specimen H(s,k). The output y is fed back to the summing junction.</desc>
<style>#fig_loop svg text{font-size:13px}#fig_loop svg .lb{font-size:14px}</style>
<defs><marker id="fla" markerWidth="7" markerHeight="7" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="context-stroke"/></marker></defs>
<g fill="#CCCCCC" stroke="#000" stroke-width="0.8"><rect x="170" y="30" width="90" height="46"/><rect x="320" y="30" width="130" height="46"/></g>
<circle cx="115" cy="53" r="9" fill="#fff" stroke="#000" stroke-width="0.8"/>
<g fill="none" stroke-width="1.1">
<path d="M30 53 H104" stroke="#404040" marker-end="url(#fla)"/>
<path d="M124 53 H168" stroke="#404040" marker-end="url(#fla)"/>
<path d="M260 53 H318" stroke="#000" stroke-width="1.4" marker-end="url(#fla)"/>
<path d="M450 53 H540" stroke="#1689BA" marker-end="url(#fla)"/>
<path d="M495 53 V110 H115 V64" stroke="#1689BA" marker-end="url(#fla)"/>
</g>
<circle cx="495" cy="53" r="2.4" fill="#1689BA"/>
<g text-anchor="middle" fill="#000">
<text x="215" y="50" class="it lb">C(s)</text><text x="215" y="66">Controller</text>
<text x="385" y="45" class="it lb">H(s, k)</text><text x="385" y="60">Transfer system</text><text x="385" y="73">and specimen</text>
<text x="60" y="45" class="it lb">u(t)</text><text x="102" y="42">+</text><text x="106" y="80">−</text>
<text x="289" y="45" class="it lb">v(t)</text><text x="525" y="45" class="it lb">y(t)</text>
</g></svg>
<figcaption><b>Figure 2.</b> Outer controller loop used in the tests of this section.</figcaption></figure>''')
H2("2.3", "Initial and damaged systems", "s23")
P("The plant $H(s,k)$ was identified in two specimen states. In the initial state, the lateral stiffness of the "
  "specimen was $k_0=7.20$ MN/m. After the anchorage was damaged, the lateral stiffness fell to 5.38 MN/m, or "
  "$0.75\\,k_0$. The two plants are denoted $H_0$ and $H_d$ hereafter.")
P("In each state, band-limited white noise up to 80 Hz was applied through the loop of Figure 2 with the same $C(s)$. The transfer "
  "function from the command $v(t)$ to the measured displacement $y(t)$ was then estimated between 0.1 and 80 Hz. "
  "Frequencies with coherence below 0.8 were excluded. A parametric model was fitted to each estimate, with five "
  "poles for $H_0$ and six for $H_d$.")
H2("2.4", "Effect of degradation on stability", "s24")
P("Consider again the loop of Figure 2. The controller $C(s)$ is the same in both states, and only the specimen "
  "changes. The open-loop transfer function is therefore $L_0=CH_0$ in the initial state and $L_d=CH_d$ in the "
  "damaged state. Figure 3 compares the two frequency responses and the chordal distance used by the NCF margin.")
RAW('<figure id="fig_ol"><img src="figures/fig_open_loop.svg" alt="Open-loop magnitude, phase and chordal distance for the initial and damaged systems" style="width:70%;max-width:100%;display:block;margin:0 auto;background:#fff"/><figcaption><b>Figure 3.</b> Open-loop frequency response of the outer controller loop and its chordal distance for the initial and damaged systems. Markers show the minima, and the dotted line shows the 0.4 guideline.</figcaption></figure>')
P("The 25% loss of lateral stiffness raised the loop gain by a factor of about 2.4 below 10 Hz. However, the "
  "phase of the loop changed by less than 4° in this range. The loss of stiffness therefore mainly amplifies the loop "
  "gain rather than adding phase lag. Consequently, the chordal distance dips near 35–38 Hz, and the NCF margin falls "
  "from 0.59 to 0.34. Table 1 summarizes the two states. The damaged margin is below the 0.4 guideline recommended "
  "by {citet:gomaa}. These trends agree with the gain-amplification mechanism reported in {citep:gomaa}. They also "
  "support the assumption in Section 3.1.2 that degradation scales the open-loop gain by a real factor $g$.")
RAW('<figure class="table" id="tab_margins"><figcaption><b>Table 1.</b> Initial and damaged systems.</figcaption>'
    '<table class="border-white/10">'
    + "<thead>" + trow(["", "Initial", "Damaged"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in [
        ("Lateral stiffness", "7.20 MN/m, $k_0$", "5.38 MN/m, $0.75\\,k_0$"),
        ("Loop gain below 10 Hz", "1", "about 2.4"),
        ("NCF margin $b_{\\mathrm{NCF}}$", "0.59 (at 35 Hz)", "0.34 (at 38 Hz)"),
    ]) + "</tbody></table></figure>")
H2("2.5", "Problem statement", "s25")
P("These results expose a dilemma for a fixed outer controller. A controller tuned for the initial state becomes "
  "too aggressive once the specimen degrades. Conversely, a controller tuned for the damaged state sacrifices "
  "tracking in the initial state. The specimen state is also unknown during the experiment. The stability of the "
  "outer controller loop must therefore be quantified online from the available measurements. The controller must "
  "then be updated accordingly so the experiment is completed safely and successfully. Section 3 presents a "
  "framework that meets both requirements.")

H1("3", "Online NCF stability indicator framework for adaptive control", "sec3")
RAW('<p class="lead">' + inline(
    "The NCF online stability indicator (NCF OSI), proposed by {citet:gomaa}, "
    "quantifies the robustness of the closed-loop system as the physical plant changes during the experiment. The study "
    "showed that specimen stiffness degradation can drive the outer controller loop toward instability through a "
    "gain-amplification mechanism. In this study, we extend the analytical results to experimental implementation, "
    "discuss the challenges that arise, and propose ways to address them. The proposed framework comprises two "
    "parts: an online estimator of the indicator and an adaptive controller that gets updated accordingly. The "
    "indicator is estimated during the experiment from the desired displacement calculated by the numerical "
    "substructure and the measured actuator displacement by combining three estimator branches at each frequency, "
    "each weighted by the confidence in its output. The first is direct identification, $b_{\\mathrm{id}}$, which "
    "estimates the closed-loop transfer function of the outer controller loop from the desired displacement $u(t)$ "
    "to the measured actuator displacement $y(t)$, with the $H_1$ cross-spectral estimator {citep:bendat}. The second is "
    "output-power inference, $b_{\\mathrm{pow}}$, which can detect loop amplification at frequencies that cannot "
    "be reliably identified. This branch compares the output power measured during the experiment against the "
    "reference recorded before the excitation. The third is the prior identification of the initial state, $b_{0}$, "
    "which serves as a fallback when insufficient information is available. The adaptive controller then uses the "
    "estimated indicator to scale the controller output by the adaptive factor $\\lambda$, keeping the loop stable "
    "with an adequate margin as the specimen degrades while retaining as much tracking performance as possible. "
    "This section presents the framework and then its calibration.") + '</p>')

H2("3.1", "Framework Architecture", "s1")
P("In the hybrid simulation block diagram shown in Figure 4, the numerical substructure computes the desired displacement $d(t)$ "
  "from the ground acceleration and measured force $f_m(t)$. To compensate for transfer-system lag and improve tracking, "
  "a phase-lead compensator receives $d(t)$ and produces the reference $u(t)$. The outer controller $C(s)$ takes the "
  "tracking error $u(t)-y(t)$, where $y(t)$ is the measured actuator displacement. It scales its output by the adaptive "
  "factor $\\lambda\\in(0,1]$ to produce the command $v(t)$ sent to the plant $H(s,k)$.")
P("The plant comprises the transfer system and the specimen of stiffness $k$. The transfer system includes the "
  "inner-loop controller, servo-valve, and actuator. The control–structure interaction between the actuator and specimen is "
  "also included in the transfer-system dynamics. The measured force $f_m(t)$ is fed back to the numerical substructure and "
  "closes the numerical substructure loop, while the measured displacement $y(t)$ is fed back to the outer controller, "
  "closing the outer-controller loop.")
P("The NCF OSI block runs alongside the outer-controller loop and does not alter the signals within it. It collects "
  "the reference $u(t)$ and the measured displacement $y(t)$ over a moving window and estimates the NCF margin of "
  "the current loop at each update. The adaptive law then compares this estimate with a target margin and updates "
  "the adaptive factor $\\lambda$. A lower margin reduces $\\lambda$ to restore stability, while a sufficient margin "
  "lets $\\lambda$ recover toward one to retain tracking performance.")
RAW('''<figure id="fig1"><svg role="img" aria-labelledby="f1t f1d" viewBox="0 0 602 200" data-units="px">
<title id="f1t">Hybrid simulation loop with the NCF OSI framework setup</title>
<desc id="f1d">The numerical substructure computes the desired displacement d, which the phase-lead compensator turns into the reference u. The tracking error u minus d_m enters the controller C(s). The adaptive factor lambda scales its output to give the command v applied to the transfer system and specimen H(s,k), whose output is y. The measured displacement d_m returns to the summing junction. The measured force f_m returns to the numerical substructure. The NCF OSI collects the reference u and the measured displacement d_m and updates lambda.</desc>
<defs><marker id="f1a" markerWidth="7" markerHeight="7" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="context-stroke"/></marker></defs>
<g fill="#CCCCCC" stroke="#000" stroke-width="0.8">
<rect x="4" y="95" width="82" height="40"/><rect x="110" y="95" width="78" height="40"/><rect x="270" y="95" width="58" height="40"/>
<rect x="352" y="95" width="58" height="40"/><rect x="442" y="95" width="94" height="40"/>
<rect x="440" y="6" width="96" height="34" fill="#BEDCC6"/>
</g>
<circle cx="238" cy="115" r="8" fill="#fff" stroke="#000" stroke-width="0.8"/>
<g fill="none" stroke-width="1">
<path d="M86 115 H108" stroke="#404040" marker-end="url(#f1a)"/>
<path d="M188 115 H228" stroke="#404040" marker-end="url(#f1a)"/>
<path d="M246 115 H268" stroke="#404040" marker-end="url(#f1a)"/>
<path d="M328 115 H350" stroke="#404040" marker-end="url(#f1a)"/>
<path d="M410 115 H440" stroke="#000" stroke-width="1.3" marker-end="url(#f1a)"/>
<path d="M536 111 H600" stroke="#1689BA" marker-end="url(#f1a)"/>
<path d="M556 111 V168 H238 V125" stroke="#1689BA" marker-end="url(#f1a)"/>
<path d="M536 124 H574 V190 H45 V137" stroke="#A518AD" marker-end="url(#f1a)"/>
<path d="M216 115 V23 H438" stroke="#278A42" marker-end="url(#f1a)"/>
<path d="M556 111 V23 H538" stroke="#278A42" marker-end="url(#f1a)"/>
<path d="M470 40 V62 H381 V93" stroke="#278A42" marker-end="url(#f1a)"/>
</g>
<circle cx="556" cy="111" r="2.2" fill="#1689BA"/><circle cx="216" cy="115" r="2.2" fill="#278A42"/>
<g text-anchor="middle" fill="#000">
<text x="45" y="112">Numerical</text><text x="45" y="125">substructure</text>
<text x="149" y="112">Phase-lead</text><text x="149" y="125">compensator</text>
<text x="299" y="112" class="it">C(s)</text><text x="299" y="125">Controller</text>
<text x="381" y="106" class="it">λ</text><text x="381" y="119">Adaptive</text><text x="381" y="131">factor</text>
<text x="489" y="106" class="it">H(s, k)</text><text x="489" y="119">Transfer system</text><text x="489" y="131">and specimen</text>
<text x="488" y="27">NCF OSI</text>
</g>
<g fill="currentColor">
<text x="98" y="108" text-anchor="middle" class="it">d(t)</text>
<text x="200" y="108" text-anchor="middle" class="it">u(t)</text>
<text x="225" y="104" text-anchor="middle">+</text><text x="229" y="137" text-anchor="middle">−</text>
<text x="426" y="108" text-anchor="middle" class="it" font-weight="700">v(t)</text>
<text x="589" y="104" text-anchor="middle" class="it">y(t)</text>
<text x="394" y="163" text-anchor="middle" class="it">d<tspan dy="3" font-size="9">m</tspan></text>
<text x="300" y="185" text-anchor="middle" class="it">f<tspan dy="3" font-size="9">m</tspan></text>
</g>
<text x="426" y="57" text-anchor="middle" fill="#278A42" class="sm">update</text>
</svg>
<figcaption><b>Figure 4.</b> Hybrid simulation loop with the NCF OSI framework setup.</figcaption></figure>''')
P('The plant in Figure 4 is characterized by the transfer function $H(s,k)=Y(s)/V(s)$ from the command $v(t)$ '
  'to the measured actuator displacement $y(t)$. The open-loop transfer function and closed-loop response from '
  '$u(t)$ to $y(t)$ are')
E("L", r"L(s,\lambda,k)=\lambda\,C(s)\,H(s,k),", "L(s,λ,k)=λ C(s) H(s,k)")
E("T", r"T(s,\lambda,k)=\frac{Y(s)}{U(s)}=\frac{L(s,\lambda,k)}{1+L(s,\lambda,k)},",
  "T(s,λ,k)=(Y(s))/(U(s))=(L(s,λ,k))/(1+L(s,λ,k))")
P('Here $U(s)$ and $Y(s)$ are the Laplace transforms of $u(t)$ and $y(t)$. The NCF stability margin '
  'of the outer controller loop is evaluated for the loop $L$ under unity feedback {citep:glover}:')
E("bncf", r"b_{\mathrm{NCF}}(L)=\inf_{\omega}\frac{|1+L(j\omega)|}{\sqrt{2\big(1+|L(j\omega)|^{2}\big)}}.",
  "b_(\"NCF\") (L)=\"inf\"┬ω  (|1+L(jω)|)/√(2(1+|L(jω)|^2)).")
P('As the specimen changes during a hybrid simulation, the loop $L(j\\omega)$ changes with it. {eq:bncf} '
  'could be applied directly only if $L(j\\omega)$ were identified with high confidence at every frequency, but '
  'online measurements rarely support this across the full band. The NCF OSI is therefore estimated from three '
  'complementary branches, direct identification $b_{\\mathrm{id}}$, output-power inference $b_{\\mathrm{pow}}$ '
  'and prior identification of the initial state $b_0$, which the following sections develop in turn.')

H2("3.1.1", "Direct identification branch, " + inline("$b_{\\mathrm{id}}$"), "s2")
P('Identifying the closed-loop transfer function requires the autospectrum of reference $u(t)$ and the cross '
  'spectrum of measured actuator displacement $y(t)$ with $u(t)$. The autospectrum of $y(t)$ is also needed to '
  'calculate coherence, which helps set the confidence weight at each frequency. A moving window lets these '
  'spectra follow changes in the specimen during the experiment.')
P('Each window contains $N=f_sT_w$ samples of $u(t)$ and $y(t)$, where $f_s$ is the sampling frequency and '
  '$T_w$ is the window duration. Updates occur at intervals $\\Delta t$, so consecutive windows overlap when '
  '$\\Delta t<T_w$. The update index is $n$, and $r=0,\\dots,N-1$ indexes samples within each window. The '
  'Hann-windowed discrete Fourier transforms are')
E("dftu", r"U_n(\omega_m)=\sum_{r=0}^{N-1}w[r]\,u_n[r]\,e^{-j2\pi mr/N},",
  "U_n (ω_m)=∑_(r=0)^(N−1)▒〖w[r] u_n [r] e^(−j2πmr/N)〗,")
E("dfty", r"Y_n(\omega_m)=\sum_{r=0}^{N-1}w[r]\,y_n[r]\,e^{-j2\pi mr/N},",
  "Y_n (ω_m)=∑_(r=0)^(N−1)▒〖w[r] y_n [r] e^(−j2πmr/N)〗,")
P('where $u_n[r]$ and $y_n[r]$ are the samples of window $n$, and $\\omega_m=2\\pi mf_s/N$ is the angular frequency of '
  'bin $m$. The samples of each window are weighted by the Hann window presented by {citet:blackman}:')
E("hann", r"w[r]=\frac{1}{2}\left[1-\cos\!\left(\frac{2\pi r}{N-1}\right)\right].",
  "w[r]=1/2 [1−cos((2πr)/(N−1))].")
P('{citet:welch} proposed estimating the power spectrum by averaging, with equal weight, the squared Fourier '
  'magnitudes of overlapping windowed segments of a record. Cross spectra are estimated in the same way from products '
  'of paired Fourier transforms, with one transform conjugated. In the present study, the plant changes as the '
  'specimen degrades, so recent windows should carry more weight than earlier ones. Each window therefore provides '
  'one raw estimate of the autospectra of $u$ and $y$ and the cross spectrum of $y$ with $u$:')
E("puu", r"p_{uu,n}(\omega_m)=|U_n(\omega_m)|^{2},", "p_(uu,n) (ω_m)=|U_n (ω_m)|^2,")
E("pyy", r"p_{yy,n}(\omega_m)=|Y_n(\omega_m)|^{2},", "p_(yy,n) (ω_m)=|Y_n (ω_m)|^2,")
E("pyu", r"p_{yu,n}(\omega_m)=Y_n(\omega_m)\,U_n^{*}(\omega_m),", "p_(yu,n) (ω_m)=Y_n (ω_m) U_n^* (ω_m),")
P('where the superscript $*$ denotes the complex conjugate. These raw estimates are averaged with the geometric moving average proposed by {citet:roberts}, which '
  'updates an average from its previous value and the newest observation. Earlier spectra are retained, but their '
  'contributions decay as new windows arrive. This reduces scatter between updates while still following changes in '
  'the plant. The first complete window initializes the average. At each subsequent update, $\\eta_s$ '
  'weights the new spectrum and $1-\\eta_s$ weights the previous average:')
E("ewuu", r"\bar{p}_{uu,n}(\omega_m)=(1-\eta_s)\,\bar{p}_{uu,n-1}(\omega_m)+\eta_s\,p_{uu,n}(\omega_m),",
  "p̄_(uu,n) (ω_m)=(1−η_s) p̄_(uu,n−1) (ω_m)+η_s p_(uu,n) (ω_m),")
E("ewyy", r"\bar{p}_{yy,n}(\omega_m)=(1-\eta_s)\,\bar{p}_{yy,n-1}(\omega_m)+\eta_s\,p_{yy,n}(\omega_m),",
  "p̄_(yy,n) (ω_m)=(1−η_s) p̄_(yy,n−1) (ω_m)+η_s p_(yy,n) (ω_m),")
E("ewyu", r"\bar{p}_{yu,n}(\omega_m)=(1-\eta_s)\,\bar{p}_{yu,n-1}(\omega_m)+\eta_s\,p_{yu,n}(\omega_m).",
  "p̄_(yu,n) (ω_m)=(1−η_s) p̄_(yu,n−1) (ω_m)+η_s p_(yu,n) (ω_m).")
P('The NCF OSI is evaluated over $\\Omega$, the set of frequencies considered in the analysis.')

P("At each selected frequency, the loop response can be identified directly from the reference $u$ and the measured response $y$. The averaged "
  "spectra give the $H_1$ estimate of the closed-loop frequency response {citep:bendat} and the magnitude-squared coherence")
E("that", r"\hat{T}_n(j\omega)=\frac{\bar{p}_{yu,n}(\omega)}{\bar{p}_{uu,n}(\omega)},",
  "T̂_n (jω)=(p̄_(yu,n) (ω))/(p̄_(uu,n) (ω)),")
E("coh", r"\gamma_n^{2}(\omega)=\frac{|\bar{p}_{yu,n}(\omega)|^{2}}{\bar{p}_{uu,n}(\omega)\,\bar{p}_{yy,n}(\omega)}.",
  "γ_n^2 (ω)=(|p̄_(yu,n) (ω)|^2)/(p̄_(uu,n) (ω) p̄_(yy,n) (ω)).")
P("Inverting {eq:T} gives the identified loop:")
E("lhat", r"\hat{L}_n(j\omega)=\frac{\hat{T}_n(j\omega)}{1-\hat{T}_n(j\omega)}.",
  "L̂_n (jω)=(T̂_n (jω))/(1−T̂_n (jω)).")
P("Here, the identified loop is smoothed with the running median over neighbouring frequencies discussed by "
  "{citet:dimatteo}, so the median is taken over each frequency and its two neighbours. The smoothed "
  "loop $\\hat{L}_{\\mathrm{s},n}$ is hence given by")
E("lmed", r"\hat{L}_{\mathrm{s},n}(j\omega_m)=\underset{i\in\{m-1,\,m,\,m+1\}}{\operatorname{median}}\;\hat{L}_n(j\omega_i).",
  "L̂_(\"s\",n) (jω_m)=\"median\"┬(i∈{m−1,m,m+1})  L̂_n (jω_i).")
P("The identified margin then follows from {eq:bncf}:")
E("bid", r"b_{\mathrm{id},n}=b_{\mathrm{NCF}}\big(\hat{L}_{\mathrm{s},n}\big).",
  "b_(\"id\",n)=b_(\"NCF\") (L̂_(\"s\",n)).")
P("The quality of this estimate varies with time and frequency for two reasons. First, the command can be too weak "
  "for the measured response to rise above the sensor noise. Second, even an active command concentrates its energy "
  "in a limited band set by the ground motion and the structural modes, so bins outside that band carry little "
  "information.")
P("Each bin therefore receives an identification weight $w_{\\mathrm{id},n}$ between zero and one, built from three "
  "factors. "
  "The first is command activity $A_n$, detected from the root mean square of the window:")
E("act", r"A_n=\begin{cases}1, & \operatorname{RMS}(u_n)>\eta_A\,\sigma_u,\\ 0, & \text{otherwise},\end{cases}",
  "A_n={■(1,&\"RMS\"(u_n)>η_A σ_u,@0,&\"otherwise\",)┤")
P("where $\\operatorname{RMS}(u_n)$ is the root mean square of the command samples in the considered window $n$, "
  "$\\sigma_u$ is the standard deviation of the command noise measured in a quiet record, and $\\eta_A$ is a "
  "hyperparameter to be tuned. The second factor is the input leverage $\\ell_n$, which reduces "
  "the weight of bins that carry little command energy. The command power in each bin is first normalized by its "
  "maximum over $\\Omega$:")
E("prel", r"\ell_{\mathrm{raw},n}(\omega)=\frac{\bar{p}_{uu,n}(\omega)}{\max_{\nu\in\Omega}\bar{p}_{uu,n}(\nu)}.",
  "ℓ_(\"raw\",n) (ω)=(p̄_(uu,n) (ω))/(\"max\"┬(ν∈Ω)  p̄_(uu,n) (ν)).")
P("The raw leverage cannot serve as the weight directly. It is proportional to the bin power, so a bin with one "
  "tenth of the peak power would receive one tenth of the weight even though its estimate is still reliable. The "
  "weight should instead stay close to one while a bin carries enough command power and fall toward zero only when "
  "it carries too little. The hyperparameter $\\ell_{\\mathrm{floor}}$ sets this boundary:")
E("lev", r"\ell_n(\omega)=\frac{\ell_{\mathrm{raw},n}(\omega)}{\ell_{\mathrm{raw},n}(\omega)+\ell_{\mathrm{floor}}},",
  "ℓ_n (ω)=(ℓ_(\"raw\",n) (ω))/(ℓ_(\"raw\",n) (ω)+ℓ_(\"floor\") ),")
P("which stays close to one in bins with $\\ell_{\\mathrm{raw},n}\\gg\\ell_{\\mathrm{floor}}$ and decreases smoothly "
  "toward zero in bins with $\\ell_{\\mathrm{raw},n}\\ll\\ell_{\\mathrm{floor}}$. A bin with command power equal to "
  "$\\ell_{\\mathrm{floor}}$ times the peak receives half weight. The third factor is the coherence, which completes the weight")
E("conf", r"w_{\mathrm{id},n}(\omega)=A_n\,\gamma_n^{2}(\omega)\,\ell_n(\omega).",
  "w_(\"id\",n) (ω)=A_n γ_n^2 (ω) ℓ_n (ω).")
P("This weight sets the share of this branch in the fusion of Section 3.1.3.")

H2("3.1.2", "Output-power inference branch", "s3")
P("Direct identification fails when the command is weak or does not excite the relevant frequency band. Even then, a "
  "degrading specimen can still drive the system toward instability. However, the change in output power relative to "
  "the initial state can reveal loop amplification even at frequencies without strong excitation. This change therefore "
  "provides a second source of evidence for a reduction in the stability margin. This method is inspired by {citet:wu}, "
  "who used active-power deviation and its rate of change to discriminate changes in the transient operating regime "
  "of a virtual synchronous generator. To quantify this change, the averaged "
  "output power is compared with its initial reference:")
E("qobs", r"q_{\mathrm{obs},n}(\omega)=\frac{\bar{p}_{yy,n}(\omega)}{p_{yy,0}(\omega)},",
  "q_(\"obs\",n) (ω)=(p̄_(yy,n) (ω))/(p_(yy,0) (ω)),")
P("where $q_{\\mathrm{obs},n}$ is the observed power ratio, which measures the change in output power at each frequency "
  "relative to the initial state. The averaged autospectrum of $y$ is $\\bar{p}_{yy,n}$ from {eq:ewyy}, and "
  "$p_{yy,0}$ is the reference autospectrum of $y$ recorded in the initial state.")
P("The output-power branch detects a change by comparing the present output power with a reference from the initial state. "
  "A single window of output power fluctuates strongly, so a reference taken from one window could bias every later comparison. "
  "The reference autospectrum is therefore the median of three raw autospectra recorded in the initial state. "
  "These are taken at 0.5, 1.0 and 1.5 s, with $\\lambda=1$:")
E("pyyref", r"p_{yy,0}(\omega)=\operatorname{med}\{p_{yy,n_1}(\omega),\,p_{yy,n_2}(\omega),\,p_{yy,n_3}(\omega)\},",
  "p_(yy,0) (ω)=\"med\"{p_(yy,n_1) (ω),p_(yy,n_2) (ω),p_(yy,n_3) (ω)},")
P("where $n_1$, $n_2$ and $n_3$ are the corresponding updates. The median discards one unusually loud or quiet window.")
P("According to the observation discussed in {citet:gomaa} and the experimental verification presented in "
  "Section 2.4, the change due to specimen degradation can be represented by an amplification $g$ of the open-loop gain. "
  "Consequently, a candidate loop $\\lambda_n g L_0$ predicts the ratio")
E("qmod", r"q_{\mathrm{model},n}(\omega,g)=\left|\frac{1+L_0(j\omega)}{1+\lambda_n g\,L_0(j\omega)}\right|^{2},",
  "q_(\"model\",n) (ω,g)=〖|(1+L_0 (jω))/(1+λ_n g L_0 (jω))|〗^2,")
P("where $q_{\\mathrm{model},n}$ is the predicted power ratio, and $L_0(j\\omega)=C(j\\omega)H_0(j\\omega)$ is the loop of "
  "the prior identification of the initial state. The amplification is then selected as the candidate in $\\mathcal{G}$ "
  "that minimizes the logarithmic difference between the observed and predicted ratios:")
E("gfit", r"\hat{g}_n(\omega)=\underset{g\in\mathcal{G}}{\operatorname{arg\,min}}\;\left|\log q_{\mathrm{obs},n}(\omega)-\log q_{\mathrm{model},n}(\omega,g)\right|,",
  "ĝ_n (ω)=\"arg min\"┬(g∈𝒢)  |log q_(\"obs\",n) (ω)−log q_(\"model\",n) (ω,g)|,")
P("where $\\hat{g}_n$ is the selected amplification, and $\\mathcal{G}$ is a grid of candidate values of $g$.")
P("The predicted ratio in {eq:qmod} assumes that only the loop has changed since the reference was recorded. "
  "At frequencies without excitation, however, the output consists mainly of sensor noise. Its power is estimated "
  "from few windows and therefore scatters. The reference is also the median of only three windows. Consequently, "
  "$\\hat{g}_n$ can indicate an amplification that does not exist, and the estimated margin would decrease without "
  "degradation.")
P("The identified margin $b_{\\mathrm{id},n}$ cannot correct this error, because it is valid only at the excited "
  "frequencies. Degradation, however, changes the loop at all frequencies. At the excited frequencies, it appears as "
  "an increase in the magnitude of the identified loop. Section 2.4 observed such an increase by a factor of about 2.4. "
  "A real amplification inferred from output power should therefore be accompanied by an increase in the identified "
  "loop. The factor $\\rho_n$ measures this increase and thus confirms whether the amplification indicated by "
  "$\\hat{g}_n$ is real.")
P("The factor $\\rho_n$ is the real scale that best fits the prior loop $\\lambda_n L_0$ to the identified loop "
  "$\\hat{L}_n$ in the weighted least-squares sense:")
E("rhols", r"\rho_n=\underset{\rho\in\mathbb{R}}{\operatorname{arg\,min}}\sum_{\omega\in\Omega}w_{\mathrm{id},n}^{2}(\omega)\,\big|\hat{L}_n(j\omega)-\rho\,\lambda_n L_0(j\omega)\big|^{2}.",
  "ρ_n=\"arg min\"┬(ρ∈ℝ) ∑_(ω∈Ω)▒〖w_(\"id\",n)^2 (ω) |L̂_n (jω)−ρ λ_n L_0 (jω)|^2〗.")
P("The factor is real, consistent with the real amplification $g$ in {eq:qmod}. Each term of the sum expands as")
E("rhoexp", r"\big|\hat{L}_n-\rho\lambda_n L_0\big|^{2}=|\hat{L}_n|^{2}-2\rho\operatorname{Re}\{\lambda_n L_0^{*}\hat{L}_n\}+\rho^{2}|\lambda_n L_0|^{2}.",
  "|L̂_n−ρ λ_n L_0|^2=|L̂_n|^2−2ρ Re{λ_n L_0^* L̂_n}+ρ^2 |λ_n L_0|^2.")
P("Setting the derivative with respect to $\\rho$ to zero gives")
E("rho", r"\rho_n=\frac{\operatorname{Re}\{\sum_{\omega\in\Omega}w_{\mathrm{id},n}^{2}(\omega)\,\lambda_n L_0^{*}(j\omega)\,\hat{L}_n(j\omega)\}}{\sum_{\omega\in\Omega}w_{\mathrm{id},n}^{2}(\omega)\,|\lambda_n L_0(j\omega)|^{2}}.",
  "ρ_n=(Re{∑_(ω∈Ω)▒〖w_(\"id\",n)^2 (ω) λ_n L_0^* (jω) L̂_n (jω)〗})/(∑_(ω∈Ω)▒〖w_(\"id\",n)^2 (ω) |λ_n L_0 (jω)|^2〗).")
P("The weight $w_{\\mathrm{id},n}$ lets the well-identified excited frequencies dominate. "
  "The identified loop $\\hat{L}_n$ is taken before frequency-median smoothing. "
  "For an unchanged specimen $\\rho_n\\approx1$, whereas for the damaged specimen of Section 2 $\\rho_n\\approx2.4$.")
P("The confirmation $c_n$ sets how much the amplification inferred from output power is trusted. It depends on the "
  "loop increase $\\rho_n$ identified at the excited frequencies:")
E("confirm", r"c_n=\frac{\rho_n-1}{\rho_{\mathrm{th}}-1},\qquad c_n\in[\epsilon,\,1],",
  "c_n=(ρ_n−1)/(ρ_(\"th\")−1),  c_n∈[ε,1],")
P("where $\\rho_{\\mathrm{th}}$ is the confirmation threshold. Once $\\rho_n$ reaches $\\rho_{\\mathrm{th}}$, $c_n$ "
  "equals one, and the amplification inferred from output power is fully trusted. The lower bound $\\epsilon=0.1$ is "
  "a safety minimum. It accounts for amplification that cannot be observed at any excited frequency, such as "
  "amplification from unmodeled dynamics or higher-mode effects. The accepted amplification is")
E("gaccept", r"\tilde{g}_n(\omega)=1+c_n\big(\hat{g}_n(\omega)-1\big),",
  "g̃_n (ω)=1+c_n (ĝ_n (ω)−1),")
P("where $\\tilde{g}_n$ replaces $\\hat{g}_n$ in the averaging equation, {eq:gmem}.")
P("The accepted amplification at update $n$ inherits the scatter of $q_{\\mathrm{obs},n}$ and therefore varies between "
  "updates. To reduce this scatter while following the degrading specimen, successive accepted amplifications are averaged "
  "recursively. As for the spectra in Equations ({n:ewuu})–({n:ewyu}), more weight is placed on recent values. The average is formed on a "
  "logarithmic scale:")
E("gmem", r"\log\hat{g}_{\mathrm{s},n}(\omega)=(1-\eta_g)\log\hat{g}_{\mathrm{s},n-1}(\omega)+\eta_g\log\tilde{g}_n(\omega),",
  "log ĝ_(\"s\",n) (ω)=(1−η_g) log ĝ_(\"s\",n−1) (ω)+η_g log g̃_n (ω),")
P("where $\\hat{g}_{\\mathrm{s},n}$ is the smoothed amplification, and $\\eta_g$ is the averaging factor that weights the "
  "newest accepted amplification. {eq:bncf} then gives the margin of this branch:")
E("bres", r"b_{\mathrm{pow},n}=b_{\mathrm{NCF}}\big(\lambda_n\hat{g}_{\mathrm{s},n}L_0\big),",
  "b_(\"pow\",n)=b_(\"NCF\") (λ_n ĝ_(\"s\",n) L_0),")
P("where $b_{\\mathrm{pow},n}$ is the output-power margin.")
P("To reduce false positives and chattering at small changes, the evidence from this branch is weighted by the size "
  "of the smoothed amplification up to the threshold $g_{\\mathrm{th}}$:")
E("det", r"d_n(\omega)=\frac{\hat{g}_{\mathrm{s},n}(\omega)-1}{g_{\mathrm{th}}-1},\qquad d_n(\omega)\in[0,1],",
  "d_n (ω)=(ĝ_(\"s\",n) (ω)−1)/(g_(\"th\")−1),  d_n (ω)∈[0,1],")
P("where $d_n$ is the detection weight, limited to the interval $[0,1]$, and $g_{\\mathrm{th}}$ is the amplification "
  "threshold above which the evidence is fully trusted. Consequently, the detection weight rises linearly from zero at "
  "$\\hat{g}_{\\mathrm{s},n}=1$ to one at $\\hat{g}_{\\mathrm{s},n}=g_{\\mathrm{th}}$. Together with the identification "
  "weight, it sets the weight of this branch:")
E("w", r"w_{\mathrm{pow},n}=(1-w_{\mathrm{id},n})\,d_n,",
  "w_(\"pow\",n)=(1−w_(\"id\",n) ) d_n,")
P("where $w_{\\mathrm{pow},n}$ is the weight of the output-power branch, and $w_{\\mathrm{id},n}$ is the identification "
  "weight from {eq:conf}. Consequently, this branch receives the share left by direct identification, in proportion to "
  "the detected amplification.")
P("Unlike direct identification, which reflects both losses and gains in the stability margin, the output-power "
  "branch detects only open-loop gain amplification. Consequently, once the adaptive controller restores stability "
  "and the output power returns to its initial level, this branch cannot reflect a recovered loop. A recovery step is "
  "therefore introduced. While the median of $q_{\\mathrm{obs},n}$ over $\\Omega$ remains below one, the smoothed "
  "amplification is reduced gradually:")
E("gdecay", r"\log\hat{g}_{\mathrm{s},n}(\omega)=r_g\,\log\hat{g}_{\mathrm{s},n-1}(\omega),",
  "log ĝ_(\"s\",n) (ω)=r_g log ĝ_(\"s\",n−1) (ω),")
P("where $r_g$ is the recovery factor, with $0<r_g<1$. The reduction stops once the output power rises above its "
  "initial reference. As a result, the output power itself limits how far the amplification is released.")

H2("3.1.3", "Per-frequency fusion and reported indicator", "s4")
P("The third branch is the margin of the prior identification of the initial state, evaluated with the current "
  "adaptive factor:")
E("b0", r"b_{0,n}=b_{\mathrm{NCF}}\big(\lambda_nL_0\big).",
  "b_(0,n)=b_(\"NCF\") (λ_n L_0).")
P("At each frequency, the three branches now provide three margin estimates, which are combined according to the "
  "evidence behind each. The prior receives the weight left by the two measured branches:")
E("w0", r"w_{0,n}=(1-w_{\mathrm{id},n})(1-d_n).",
  "w_(0,n)=(1−w_(\"id\",n) )(1−d_n ).")
P("The three margins are then combined with these weights at each frequency bin:")
E("beta", r"\beta_n(\omega)=w_{\mathrm{id},n}\,b_{\mathrm{id},n}(\omega)+w_{\mathrm{pow},n}\,b_{\mathrm{pow},n}(\omega)+w_{0,n}\,b_{0,n}(\omega).",
  "β_n (ω)=w_(\"id\",n) b_(\"id\",n) (ω)+w_(\"pow\",n) b_(\"pow\",n) (ω)+w_(0,n) b_(0,n) (ω)")
P("Fusion is performed bin by bin, before any reduction over frequency, so margins evaluated at different frequencies "
  "are never combined. This choice also handles the idle case without special treatment. When the command is inactive, "
  "$w_{\\mathrm{id},n}=0$ in every bin. An unchanged loop then reads its gain-scaled prior, and a bin with a remembered change "
  "continues to report it.")
P("To drive the adaptive controller, the fused curve is reduced to a single value. The NCF OSI margin is taken as "
  "the lowest value of $\\beta_n$ over $\\Omega$:")
E("bosi", r"b_{\mathrm{OSI},n}=\min_{\omega\in\Omega}\beta_n(\omega),",
  "b_(\"OSI\",n)=\"min\"┬(ω∈Ω)  β_n (ω),")
P("where $b_{\\mathrm{OSI},n}$ is the NCF OSI margin at update $n$, and $\\Omega$ is the set of frequencies considered in "
  "evaluating the NCF OSI. The adaptive law then uses it to update $\\lambda_{n+1}$. Figure 5 summarizes one complete "
  "update, from the measured signals to the adaptive factor, and Table 2 lists the estimator parameters.")

H2("3.1.4", "Adaptive factor update", "s5")
P("The NCF OSI estimated in Section 3.1.3 provides the margin needed to adjust the adaptive controller factor "
  "$\\lambda$. When the margin falls below a specified target, $\\lambda$ is reduced to maintain the stability "
  "of the system. This reduction is intended to counteract the gain amplification caused by specimen degradation, "
  "as discussed earlier in Section 2.")
P("To achieve this while retaining as much tracking performance as possible, $\\lambda$ is updated from the "
  "difference between the estimated margin and a target margin:")
E("lerr", r"e_n=b_{\mathrm{OSI},n}-b_{\mathrm{tar}},",
  "e_n=b_(\"OSI\",n)−b_(\"tar\"),")
P("where $e_n$ is the margin error, and $b_{\\mathrm{tar}}$ is the target NCF margin. A negative error indicates "
  "insufficient margin, and a positive error indicates spare margin.")
P("Reducing and restoring the adaptive factor carry different risks. "
  "A slow reduction leaves the loop exposed while the margin is insufficient. "
  "Conversely, a fast recovery can raise $\\lambda$ back toward instability before the estimate settles. "
  "The adaptive factor is therefore reduced and restored at different rates:")
E("lam", r"\lambda_{n+1}=\begin{cases}\lambda_n\exp(\kappa e_n),&e_n<0,\\\lambda_n\exp(\mu\kappa e_n),&e_n\ge0,\end{cases}\qquad\lambda_{n+1}\in[\lambda_{\min},1],",
  "λ_(n+1)={■(λ_n exp(κ e_n),&e_n<0,@λ_n exp(μ κ e_n),&e_n≥0,)┤  λ_(n+1)∈[λ_\"min\",1],")
P("where $\\mu=0.32$ is the ratio of the recovery rate to the reduction rate. "
  "Consequently, $\\lambda$ falls at full rate when the margin is below the target and recovers about three times more slowly. "
  "The adaptation gain is $\\kappa$, and $\\lambda_{\\min}$ is the smallest permitted adaptive factor.")

RAW('''<figure id="fig2"><svg role="img" aria-labelledby="f2t f2d" viewBox="0 0 1000 575">
<title id="f2t">Structure of one estimator update</title>
<desc id="f2d">Windowed displacements u and y feed a windowed FFT that forms the averaged autospectra and cross spectrum. These spectra feed the direct identification and output-power branches. A third branch is the initial-state prior. The adaptive factor lambda, shown in green, feeds the output-power and initial-state prior branches. The three margin curves are fused per frequency bin with the weights w_id, w_pow and w_0, and the minimum of the fused curve over the analysis band gives b_OSI, which updates the adaptive factor lambda.</desc>
<defs>
<marker id="a2" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#000"/></marker>
<marker id="a2l" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#2A9A48"/></marker>
<marker id="a2y" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#007CA8"/></marker>
</defs>
<g fill="none" stroke="#000" stroke-width="1.5">
<rect x="40" y="175" width="190" height="110" rx="10"/>
<rect x="340" y="30" width="270" height="110" rx="10"/>
<rect x="340" y="175" width="270" height="110" rx="10"/>
<rect x="340" y="320" width="270" height="110" rx="10"/>
<rect x="700" y="175" width="180" height="110" rx="10"/>
<rect x="700" y="320" width="180" height="110" rx="10"/>

<path d="M2 211.7 H38" marker-end="url(#a2)"/>
<path d="M230 230 H280 V85 H338" marker-end="url(#a2)"/>
<path d="M280 211.7 H338" marker-end="url(#a2)"/>
<path d="M610 85 H655 V202.5 H698" marker-end="url(#a2)"/>
<path d="M610 230 H698" marker-end="url(#a2)"/>
<path d="M610 375 H655 V257.5 H698" marker-end="url(#a2)"/>
<path d="M790 285 V318" marker-end="url(#a2)"/>
<path d="M880 375 H992" marker-end="url(#a2)"/>

</g>
<path d="M2 248.3 H38" fill="none" stroke="#007CA8" stroke-width="1.5" marker-end="url(#a2y)"/>
<g fill="none" stroke="#2A9A48" stroke-width="1.8">
<rect x="340" y="465" width="270" height="100" rx="10" fill="#EAF7EE"/>
<path d="M940 375 V515 H612" marker-end="url(#a2l)"/>
<path d="M340 515 H310 V248.3"/>
<path d="M310 248.3 H338" marker-end="url(#a2l)"/>
<path d="M310 375 H338" marker-end="url(#a2l)"/>
</g>
<circle cx="280" cy="211.7" r="3.5" fill="#000"/><circle cx="940" cy="375" r="3.5" fill="#000"/>
<circle cx="310" cy="375" r="3" fill="#2A9A48"/>
<g text-anchor="middle" dominant-baseline="central" style="fill:#000">
<text x="14" y="197" class="it" style="font-size:22px">u</text>
<text x="14" y="234" class="it" style="font-size:22px;fill:#007CA8">y</text>
<text x="135" y="203" style="font-size:20px">Windowed FFT</text>
<text x="135" y="231" style="font-size:19px"><tspan class="it">p̄</tspan><tspan style="font-size:13px" dy="5">uu</tspan><tspan dy="-5">, </tspan><tspan class="it">p̄</tspan><tspan style="font-size:13px" dy="5">yy</tspan><tspan dy="-5">, </tspan><tspan class="it">p̄</tspan><tspan style="font-size:13px" dy="5">yu</tspan></text>
<text x="135" y="259" style="font-size:15px;fill:#6b6b6b">Equations ({n:dftu})–({n:ewyu})</text>
<text x="475" y="58" style="font-size:20px">Direct identification</text>
<text x="475" y="86" style="font-size:19px"><tspan class="it">L̂</tspan><tspan style="font-size:13px" dy="5">s</tspan><tspan dy="-5">, </tspan><tspan class="it">w</tspan><tspan style="font-size:13px" dy="5">id</tspan><tspan dy="-5"> → </tspan><tspan class="it">b</tspan><tspan style="font-size:13px" dy="5">id</tspan><tspan dy="-5">(ω)</tspan></text>
<text x="475" y="114" style="font-size:15px;fill:#6b6b6b">Equations ({n:that})–({n:conf})</text>
<text x="475" y="203" style="font-size:20px">Output-power inference</text>
<text x="475" y="231" style="font-size:19px"><tspan class="it">q</tspan><tspan style="font-size:13px" dy="5">obs</tspan><tspan dy="-5">, </tspan><tspan class="it">ĝ</tspan><tspan style="font-size:13px" dy="5">s</tspan><tspan dy="-5"> → </tspan><tspan class="it">b</tspan><tspan style="font-size:13px" dy="5">pow</tspan><tspan dy="-5">(ω)</tspan></text>
<text x="475" y="259" style="font-size:15px;fill:#6b6b6b">Equations ({n:qobs})–({n:gdecay})</text>
<text x="475" y="348" style="font-size:20px">Initial-state prior</text>
<text x="475" y="376" style="font-size:19px"><tspan class="it">L</tspan><tspan style="font-size:13px" dy="5">0</tspan><tspan dy="-5"> → </tspan><tspan class="it">b</tspan><tspan style="font-size:13px" dy="5">0</tspan><tspan dy="-5">(ω)</tspan></text>
<text x="475" y="404" style="font-size:15px;fill:#6b6b6b">Equation ({n:b0})</text>
<text x="790" y="203" style="font-size:20px">Per-bin fusion</text>
<text x="790" y="231" style="font-size:19px" class="it">β(ω)</text>
<text x="790" y="259" style="font-size:15px;fill:#6b6b6b">Equations ({n:w0})–({n:beta})</text>
<text x="790" y="348" style="font-size:20px">Minimum over Ω</text>
<text x="790" y="376" style="font-size:19px"><tspan class="it">b</tspan><tspan style="font-size:13px" dy="5">OSI</tspan></text>
<text x="790" y="404" style="font-size:15px;fill:#6b6b6b">Equation ({n:bosi})</text>
<text x="475" y="487" style="font-size:20px">Adaptive factor</text>
<text x="475" y="515" class="it" style="font-size:19px">λ</text>
<text x="475" y="543" style="font-size:15px;fill:#6b6b6b">Equation ({n:lam})</text>
<text x="634" y="70" class="it" style="font-size:18px">w<tspan style="font-size:12px;font-style:normal" dy="5">id</tspan></text>
<text x="640" y="215" class="it" style="font-size:18px">w<tspan style="font-size:12px;font-style:normal" dy="5">pow</tspan></text>
<text x="634" y="360" class="it" style="font-size:18px">w<tspan style="font-size:12px;font-style:normal" dy="5">0</tspan></text>
<text x="960" y="358" class="it" style="font-size:18px">b<tspan style="font-size:12px;font-style:normal" dy="5">OSI</tspan></text>

</g></svg>
<figcaption><b>Figure 5.</b> Flowchart for calculating the NCF OSI margin <i>b</i><sub>OSI</sub>. The reference <i>u</i> and measured displacement <i>y</i> provide spectra for direct identification and output-power inference. These estimates are combined with the initial-state prior, and the resulting margin updates the adaptive factor <i>λ</i>.</figcaption></figure>''')


T1 = [
    ("$\\Delta t$", "0.125 s", "—", "Design", "Update interval"),
    ("$T_w$, $N$", "0.5 s, 1024", "—", "Design", "Window length at $f_s=2048$ Hz"),
    ("$\\Omega$", "2–80 Hz, 37 bins", "—", "Design", "Analysis set, 58–62 Hz rejected"),
    ("$\\eta_s$", "0.39", "0.25 s", "Calibrated", "Spectral averaging, Equations ({n:ewuu})–({n:ewyu})"),
    ("$\\eta_A$", "4.54", "—", "Calibrated", "Activity threshold relative to command noise, {eq:act}"),
    ("$\\ell_{\\mathrm{floor}}$", "$10^{-3}$", "—", "Calibrated", "Input-leverage reference, {eq:lev}"),
    ("$\\mathcal{G}$", "0.5–6, 25 values", "—", "Design", "Candidate loop-magnitude changes, {eq:gfit}"),
    ("$\\epsilon$", "0.1", "—", "Design", "Minimum confirmation, Equation ({n:confirm})"),
    ("$\\rho_{\\mathrm{th}}$", "1.5", "—", "Calibrated", "Confirmation threshold, Equation ({n:confirm})"),
    ("$\\eta_g$", "0.12", "1.0 s", "Calibrated", "Output-power memory, accumulation, {eq:gmem}"),
    ("$r_g$", "0.73", "0.4 s", "Calibrated", "Recovery factor per update, {eq:gdecay}"),
    ("$b_{\\mathrm{tar}}$", "0.40", "—", "Design", "Target NCF margin, Equation ({n:lerr})"),
    ("$\\kappa$", "0.625", "—", "Calibrated", "Adaptation gain per update, Equation ({n:lam})"),
    ("$\\mu$", "0.32", "—", "Calibrated", "Ratio of the recovery rate to the reduction rate of $\\lambda$"),
    ("$\\lambda_{\\min}$", "0.20", "—", "Design", "Smallest adaptive factor, Equation ({n:lam})"),
    ("$g_{\\mathrm{th}}$", "1.75", "—", "Calibrated", "Amplification threshold, {eq:det}"),
]


H2("3.2", "Calibration", "s32")
P("The framework of Section 3.1 contains 16 parameters, listed in Table 2. Seven of them are design values set by the "
  "test and the analysis. The window duration $T_w$ and the update interval $\\Delta t$ are defined in Section 3.1.1. "
  "The window duration of 0.5 s gives a frequency resolution of 2 Hz, which also sets the lower bound of $\\Omega$. "
  "The update interval of 0.125 s sets how often the indicator and $\\lambda$ are updated. The upper bound of "
  "$\\Omega$, 80 Hz, matches the band over which the plants were identified in Section 2.3. "
  "The grid $\\mathcal{G}$ spans the amplifications expected from degradation. The target $b_{\\mathrm{tar}}=0.4$ "
  "follows the guideline of {citet:gomaa}, and $\\lambda_{\\min}$ keeps part of the controller active.")
P("The remaining nine are hyperparameters. They set how quickly the indicator follows a change, how much evidence "
  "each branch requires, and how strongly the adaptive factor responds. Their values depend on the laboratory, the "
  "equipment, the specimen and its material. They therefore cannot be fixed from theory and must be calibrated "
  "against cases with a known margin.")
RAW('<figure class="table" id="tab1"><figcaption><b>Table 2.</b> Estimator parameters. Smoothing coefficients follow '
    + inline("$\\eta=1-\\exp(-\\Delta t/\\tau)$") + ' from the listed time constant.</figcaption><table class="border-white/10">'
    + "<thead>" + trow(["Symbol", "Value", "$\\tau$", "Type", "Role"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in T1) + "</tbody></table></figure>")
P("The two plants identified in Section 2 provide such cases. Because both models are known, the true NCF margin "
  "can be computed at every update and compared with the estimate. To impose damage numerically, both models "
  "receive the same command $v(t)$, and their outputs are mixed:")
E("mix", r"y(t)=\big[1-\delta(t)\big]\,y_0(t)+\delta(t)\,y_d(t),", "y(t)=[1−δ(t)] y_0 (t)+δ(t) y_d (t),")
P("where $y_0$ and $y_d$ are the outputs of $H_0$ and $H_d$, and $\\delta(t)\\in[0,1]$ is the damage index. Here "
  "$\\delta=0$ represents the initial state and $\\delta=1$ represents the damaged state. While $\\delta$ is "
  "constant, superposition makes this mixture equivalent to the plant $(1-\\delta)H_0+\\delta H_d$. The true margin "
  "therefore follows from {eq:bncf} applied to $\\lambda C\\big[(1-\\delta)H_0+\\delta H_d\\big]$. The mixture "
  "interpolates the responses of the two states and does not represent an intermediate stiffness.")
P("The calibration cases combine three features. The first is the damage history. Each case lasts 120 s. Sudden "
  "damage steps $\\delta$ from zero to one at 40 s and back to zero at 80 s. Gradual damage ramps $\\delta$ up "
  "between 20 and 50 s and back down between 70 and 100 s. The second feature is the excitation band. The "
  "reference $u(t)$ is band-limited white noise with an RMS of 0.15 mm. Sensor noise with a standard deviation of "
  "0.05 mm is added to the measured displacement.")
P("Wideband excitation covers 2 to 80 Hz and therefore includes the frequencies of the minimum margin, near "
  "35–38 Hz. Narrowband excitation covers only 2 to 10 Hz. Direct identification then cannot observe the change at "
  "those frequencies, and only output-power inference can detect it. The third feature is the adaptive factor. With "
  "$\\lambda$ fixed at one, the cases test whether the indicator estimates the margin correctly. With $\\lambda$ "
  "active, the same cases test whether the loop is held at the target while tracking is retained. Table 3 lists the "
  "resulting eight cases.")
RAW('<figure class="table" id="tab_cases"><figcaption><b>Table 3.</b> Calibration cases.</figcaption>'
    '<table class="border-white/10">'
    + "<thead>" + trow(["Case", "Damage history", "Excitation", "Adaptive factor"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in [
        ("1", "Sudden", "Wideband, 2–80 Hz", "Fixed, $\\lambda=1$"),
        ("2", "Gradual", "Wideband, 2–80 Hz", "Fixed, $\\lambda=1$"),
        ("3", "Sudden", "Narrowband, 2–10 Hz", "Fixed, $\\lambda=1$"),
        ("4", "Gradual", "Narrowband, 2–10 Hz", "Fixed, $\\lambda=1$"),
        ("5", "Sudden", "Wideband, 2–80 Hz", "Active"),
        ("6", "Gradual", "Wideband, 2–80 Hz", "Active"),
        ("7", "Sudden", "Narrowband, 2–10 Hz", "Active"),
        ("8", "Gradual", "Narrowband, 2–10 Hz", "Active"),
    ]) + "</tbody></table></figure>")
P("Figures 6 and 7 show the cases with $\\lambda$ fixed and active. Each column shows one case in three panels. The "
  "first shows the command and the measured displacement. The second shows the damage index $\\delta$. The third "
  "compares the estimated $b_{\\mathrm{OSI}}$ with the true margin and $b_{\\mathrm{tar}}$, and shows $\\lambda$ "
  "in the adaptive cases.")
RAW('<figure id="fig_cal_fixed"><img src="figures/fig_calibration_fixed.png" alt="Calibration cases 1 to 4 with the adaptive factor fixed" style="width:100%;max-width:100%;display:block;margin:0 auto;background:#fff"/><figcaption><b>Figure 6.</b> Calibration cases 1–4 with the adaptive factor fixed at one.</figcaption></figure>')
RAW('<figure id="fig_cal_adapt"><img src="figures/fig_calibration_adaptive.png" alt="Calibration cases 5 to 8 with the adaptive factor active" style="width:100%;max-width:100%;display:block;margin:0 auto;background:#fff"/><figcaption><b>Figure 7.</b> Calibration cases 5–8 with the adaptive factor active.</figcaption></figure>')
P("Four simple metrics summarize each case after the first 5 s. The estimation error is the mean of "
  "$|b_{\\mathrm{OSI}}-b_{\\mathrm{NCF}}|$. The roughness is the median of the second difference of "
  "$b_{\\mathrm{OSI}}$, multiplied by 1000, so steady changes are not penalized. The travel is the total variation "
  "of $\\lambda$, which measures how much the controller is adjusted. The unsafe time is the percentage of time "
  "with $b_{\\mathrm{NCF}}<b_{\\mathrm{tar}}-0.02$. Table 4 lists the results.")
RAW('<figure class="table" id="tab_metrics"><figcaption><b>Table 4.</b> Calibration metrics with '
    + inline("$b_{\\mathrm{tar}}=0.4$") + '.</figcaption><table class="border-white/10">'
    + "<thead>" + trow(["Case", "Estimation error", "Roughness", "Travel of $\\lambda$", "Unsafe time (%)"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in [
        ("1", "0.016", "11.2", "—", "34.8"), ("2", "0.016", "11.6", "—", "25.1"),
        ("3", "0.075", "0.003", "—", "34.8"), ("4", "0.073", "2.2", "—", "25.1"),
        ("5", "0.017", "11.2", "2.54", "3.4"), ("6", "0.017", "11.4", "2.14", "0.0"),
        ("7", "0.075", "0.003", "0.03", "34.8"), ("8", "0.073", "2.3", "0.33", "25.1"),
    ]) + "</tbody></table></figure>")
P("Each case constrains particular hyperparameters. The wideband cases set the spectral averaging $\\eta_s$, the "
  "activity threshold $\\eta_A$ and the leverage reference $\\ell_{\\mathrm{floor}}$ of direct identification. The "
  "narrowband cases set the output-power parameters. Their damage onset sets $g_{\\mathrm{th}}$ and $\\eta_g$, and "
  "their return to the initial state sets $r_g$. The adaptive cases set the adaptation gain $\\kappa$. The values in "
  "Table 2 were tuned on a wider benchmark, which also included a closed-loop experimental record and a replay of a "
  "recorded hybrid simulation. The eight cases above illustrate their behavior.")

H1("", "Appendix A. Assumptions and limitations", "appA")
P("The estimator relies on four assumptions, and each one limits how the reported indicator should be interpreted.")
RAW('<ol class="assumptions">' + "".join(f"<li>{inline(t)}</li>" for t in [
    "The identification branch assumes that the output disturbance is uncorrelated with $u$. Feedback through the "
    "numerical substructure can violate this assumption and bias $\\hat{T}_n$ even at high coherence.",
    "The output-power branch assumes that the disturbance spectrum is unchanged from the reference period and that the "
    "first 1.5 s represent the initial loop at full gain. A change in disturbance intensity or in the command-driven "
    "response can therefore alter $q_{\\mathrm{obs}}$ without any change in stability.",
    "The factor $g$ is real. The output-power branch therefore captures changes in loop magnitude but not in loop phase.",
    "Band limitation means that $b_{\\mathrm{OSI}}$ is not a guaranteed lower bound on the full-frequency margin "
    "$b_{\\mathrm{NCF}}$, because frequencies outside $\\Omega$ are not evaluated.",
]) + "</ol>")

REFS = {  # key -> (in-text name, year, entry). Cite as {citet:key} "Name [n]" or {citep:key} "[n]". Numbered by first appearance.
    "glover": ("Glover and McFarlane", "1989", 'Glover, K., and McFarlane, D. (1989), “Robust stabilization of normalized coprime factor plant descriptions with H<sub>∞</sub>-bounded uncertainty,” <i>IEEE Transactions on Automatic Control</i>, 34(8), 821–830. DOI: 10.1109/9.29424'),
    "gomaa": ("Gomaa et al.", "in press", 'Gomaa, M., Patino, E. D., Villamizar, J. N., Condori Uribe, J. W., and Dyke, S. J. (in press), “An online stability indicator for real-time hybrid simulation emphasizing physical substructure degradation,” author manuscript.'),
    "welch": ("Welch", "1967", 'Welch, P. D. (1967), “The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms,” <i>IEEE Transactions on Audio and Electroacoustics</i>, 15(2), 70–73. DOI: 10.1109/TAU.1967.1161901'),
    "roberts": ("Roberts", "1959", 'Roberts, S. W. (1959), “Control chart tests based on geometric moving averages,” <i>Technometrics</i>, 1(3), 239–250. DOI: 10.1080/00401706.1959.10489860'),
    "bendat": ("Bendat and Piersol", "2010", 'Bendat, J. S., and Piersol, A. G. (2010), <i>Random Data: Analysis and Measurement Procedures</i>, 4th ed., Wiley, Hoboken, NJ.'),
    "blackman": ("Blackman and Tukey", "1958", 'Blackman, R. B., and Tukey, J. W. (1958), “The measurement of power spectra from the point of view of communications engineering — Part I,” <i>The Bell System Technical Journal</i>, 37(1), 185–282. DOI: 10.1002/j.1538-7305.1958.tb03874.x'),
    "dimatteo": ("Di Matteo et al.", "2021", 'Di Matteo, S., Viall, N. M., and Kepko, L. (2021), “Power spectral density background estimate and signal detection via the multitaper method,” <i>Journal of Geophysical Research: Space Physics</i>, 126(2), e2020JA028748. DOI: 10.1029/2020JA028748'),
    "maghareh": ("Maghareh et al.", "2020", 'Maghareh, A., Fu, Y., Montoya, H., Condori, J., Wang, Z., Dyke, S. J., and Montoya, A. (2020), “A reflective framework for performance management (REFORM) of real-time hybrid simulation,” <i>Frontiers in Built Environment</i>, 6, 568742. DOI: 10.3389/fbuil.2020.568742'),
    "wu": ("Wu and Wang", "2020", 'Wu, H., and Wang, X. (2020), “A mode-adaptive power-angle control method for transient stability enhancement of virtual synchronous generators,” <i>IEEE Journal of Emerging and Selected Topics in Power Electronics</i>, 8(2), 1034–1049. DOI: 10.1109/JESTPE.2020.2976791'),
}

body = "\n".join(parts)

# ---------------------------------------------------------------- page
ARTICLE = f"""
<p class="meta">Manuscript draft. Readers are assumed to be familiar with {{citet:gomaa}}.</p>
{body}
<section class="references" aria-labelledby="refs"><h2 id="refs">References</h2><ol>
{{REFS}}
</ol></section>
"""
CITED = []
def cite(m):  # numbered by first appearance: narrative "Name [n]" or bare "[n]"
    keys = m.group(2).split(",")
    for k in keys:
        if k not in CITED: CITED.append(k)
    nums = "[" + ", ".join(f'<a class="cite" href="#ref-{k}">{CITED.index(k) + 1}</a>' for k in keys) + "]"
    return (" and ".join(REFS[k][0] for k in keys) + " " + nums) if m.group(1) == "t" else nums
ARTICLE = re.sub(r"\{eq:([A-Za-z0-9_]+)\}", lambda m: ref(m.group(1)), ARTICLE)
ARTICLE = re.sub(r"\{n:(\w+)\}", lambda m: str(EQ[m.group(1)]), ARTICLE)
ARTICLE = re.sub(r"\{cite([tp]):([a-z0-9_,]+)\}", cite, ARTICLE)
def scholar(t):  # title links to a Google Scholar search, DOI stays plain text
    m = re.search(r"“(.+?)(,?)”|<i>(.+?)</i>", t)
    title = m.group(1) or m.group(3)
    a = (f'<a href="https://scholar.google.com/scholar?q={quote_plus(re.sub("<[^>]+>", "", title))}" '
         f'target="_blank" rel="noopener">{title}</a>')
    return t.replace(m.group(0), f"“{a}{m.group(2)}”" if m.group(1) else f"<i>{a}</i>", 1)
ARTICLE = ARTICLE.replace("{REFS}", "\n".join(f'<li id="ref-{k}">{scholar(REFS[k][2])}</li>'
                                              for k in CITED))

# ---- content store read by the review app (writing/review-app builds manuscript2_journal.html)
# usage: python build_manuscript2_journal.py "short note about this revision"
# A new version is appended whenever the article changes.
HERE = os.path.dirname(os.path.abspath(__file__))
VERS = os.path.join(HERE, "manuscript2_journal_versions.js")
HEAD = "window.MANUSCRIPT_VERSIONS = "
if os.path.exists(VERS):
    versions = json.loads(open(VERS, encoding="utf-8").readline()[len(HEAD):].rstrip().rstrip(";"))
else:
    old = open(os.path.join(HERE, "manuscript2_html.html"), encoding="utf-8").read()
    stamp = datetime.datetime.fromtimestamp(os.path.getmtime(os.path.join(HERE, "manuscript2_html.html")))
    versions = [{"v": 0, "date": stamp.strftime("%Y-%m-%d %H:%M"), "note": "original manuscript2_html",
                 "html": old[old.index("<article>") + 9:old.index("</article>")]}]
args = [a for a in sys.argv[1:] if not a.startswith("--")]
if versions[-1].get("author") == "user" and versions[-1]["html"] != ARTICLE and "--merged" not in sys.argv:
    sys.exit(f"v{versions[-1]['v']} holds edits made in the review page. Port them into this script, "
             "then rerun with --merged.")
if versions[-1]["html"] != ARTICLE:
    versions.append({"v": versions[-1]["v"] + 1, "date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
                     "note": args[0] if args else "", "html": ARTICLE})
    print("saved version", versions[-1]["v"])
open(VERS, "w", encoding="utf-8").write(HEAD + json.dumps(versions, ensure_ascii=False) + ";\n"
                                         + "window.MANUSCRIPT_WORD = " + json.dumps(WORD, ensure_ascii=False) + ";\n")
print(len(EQ), "equations,", len(versions), "versions")
