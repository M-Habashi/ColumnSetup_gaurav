import re, json, html, os, sys, datetime
from latex2mathml.converter import convert

OUT = r"C:\Users\Victus\Desktop\folder_working\a purdue\aa reasearch\Gaurav Setup\ColumnSetup_gaurav\writing\manuscript2_journal.html"

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
    return f'<a href="#eq{EQ[k]}">({EQ[k]})</a>'

def inline(text):
    text = re.sub(r"\$(.+?)\$", lambda m: mml(m.group(1)), text)
    text = re.sub(r"\{eq:([A-Za-z0-9_]+)\}", lambda m: ref(m.group(1)), text)
    return text

def eqs_range(a, b):
    return f'<a href="#eq{EQ[a]}">({EQ[a]})</a>–<a href="#eq{EQ[b]}">({EQ[b]})</a>'

ICONS = {
    "save": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>',
    "track": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 6h10M4 11h7M4 16h4"/><path d="M13 20l.8-3.2 5.6-5.6 2.4 2.4-5.6 5.6z"/></svg>',
    "moon": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/></svg>',
    "sun": '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    "copy": '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="12" height="12"/><path d="M16 8V4H4v12h4"/></svg>',
    "check": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>',
    "trash": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></svg>',
    "comment": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 4h16v12H9l-5 4z"/><path d="M12 7v6M9 10h6"/></svg>',
}

parts = []
P = lambda t: parts.append(f"<p>{inline(t)}</p>")
H2 = lambda num, t, id_: parts.append(f'<h2 id="{id_}"><span class="secno">{num}</span>{t}</h2>')
E = lambda *a: parts.append(eq(*a))
RAW = parts.append

# ---------------------------------------------------------------- content
RAW('<p class="lead">' + inline(
    "The normalized coprime factor online stability indicator (NCF OSI) introduced in the authors’ previous study [2] "
    "quantifies the robustness of the actuator control loop in hybrid simulation to degradation of the specimen. This "
    "section describes how the indicator is estimated during the test from the desired displacement calculated by the "
    "numerical substructure and the measured actuator displacement. Three sources of evidence are combined at each "
    "frequency. The first is direct identification, $b_{\\mathrm{id}}$, of the closed loop from the measured signals. "
    "The second is output-power inference, $b_{\\mathrm{pow}}$, which detects a change in the loop from the change in "
    "measured output power. The third is the prior identification of the initial state, $b_{0}$, obtained "
    "before the test. Moreover, to keep the loop stable with an adequate margin as the specimen degrades while retaining "
    "as much tracking performance as possible, the controller output is scaled by the adaptive factor $\\lambda$, which is "
    "updated during the test from the estimated indicator. The derivation of the SISO margin and its relation to "
    "specimen damage are given in [2] and are restated here only as required by the estimator.") + '</p>')

H2("2.1", "Control loop and stability margin", "s1")
P("Figure 1 shows the hybrid simulation loop with the adaptive controller. The numerical substructure calculates the "
  "desired displacement $d(t)$, which is then passed through the phase-lead compensator to obtain $u(t)$. The controller "
  "$C(s)$ forms a command that is scaled by the adaptive factor $\\lambda\\in(0,1]$ and applied as $v(t)$ to the plant "
  "$H(s,k)$. The plant comprises the transfer system (servo-valve and actuator) and the specimen of stiffness $k$, and "
  "therefore includes control–structure interaction. The measured actuator displacement is $y(t)$, and the measured "
  "force $f_m(t)$ is returned to the numerical substructure.")
RAW('''<figure id="fig1"><svg role="img" aria-labelledby="f1t f1d" viewBox="0 0 1100 280">
<title id="f1t">Hybrid simulation loop with adaptive controller setup</title>
<desc id="f1d">The numerical substructure calculates the desired displacement d, which passes through the phase-lead compensator to give u. u enters a summing junction, the controller C, and the adaptive factor lambda, which produce the command v applied to the transfer system and specimen H(s,k). The measured displacement y is fed back to the junction, and the measured force f_m returns to the numerical substructure.</desc>
<defs><marker id="a1" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="context-stroke"/></marker></defs>
<g fill="none" stroke="currentColor" stroke-width="1.8">
<rect x="10" y="55" width="140" height="90"/><rect x="210" y="55" width="130" height="90"/><rect x="490" y="55" width="110" height="90"/>
<rect x="640" y="55" width="110" height="90"/><rect x="810" y="55" width="200" height="90"/><circle cx="430" cy="100" r="18"/>
<path d="M150 100 H207" marker-end="url(#a1)"/><path d="M340 100 H409" marker-end="url(#a1)"/>
<path d="M448 100 H487" marker-end="url(#a1)"/><path d="M600 100 H637" marker-end="url(#a1)"/>
</g>
<g fill="none" stroke-width="1.8">
<path d="M750 100 H807" stroke="#AC6420" marker-end="url(#a1)"/>
<path d="M1010 100 H1092" stroke="#007CA8" marker-end="url(#a1)"/><path d="M1045 100 V200 H430 V121" stroke="#007CA8" marker-end="url(#a1)"/>
<path d="M910 145 V250 H80 V148" stroke="#74058A" stroke-dasharray="7 5" marker-end="url(#a1)"/>
</g><circle cx="1045" cy="100" r="4" fill="#007CA8"/>
<g text-anchor="middle">
<text x="80" y="96" class="nt">Numerical</text><text x="80" y="120" class="nt">substructure</text>
<text x="178" y="86" class="it">d(t)</text>
<text x="275" y="96" class="nt">Phase-lead</text><text x="275" y="120" class="nt">compensator</text>
<text x="372" y="86" class="it">u(t)</text><text x="403" y="84" class="nt">+</text><text x="450" y="138" class="nt">−</text>
<text x="545" y="92" class="it">C(s)</text><text x="545" y="120" class="nt">Controller</text>
<text x="695" y="86" class="it">λ</text><text x="695" y="112" class="nt">Adaptive</text><text x="695" y="134" class="nt">factor</text>
<text x="779" y="86" class="it" fill="#AC6420">v(t)</text>
<text x="910" y="86" class="it">H(s, k)</text><text x="910" y="112" class="nt">Transfer system</text><text x="910" y="134" class="nt">and specimen</text>
<text x="1068" y="86" class="it" fill="#007CA8">y(t)</text>
<text x="700" y="191" class="nt" fill="#007CA8">Measured actuator displacement</text>
<text x="500" y="241" class="nt" fill="#74058A"><tspan class="it">f</tspan><tspan class="it" font-size="14" dy="5">m</tspan><tspan dy="-5">(t), measured force</tspan></text>
</g></svg>
<figcaption><b>Figure 1.</b> Hybrid simulation loop with adaptive controller setup.</figcaption></figure>''')
P("With $H(s,k)=Y(s)/V(s)$, the loop and closed-loop transfer functions are")
E("L", r"L(s,\lambda,k)=\lambda\,C(s)\,H(s,k),", "L(s,λ,k)=λ C(s) H(s,k)")
E("T", r"T(s,\lambda,k)=\frac{Y(s)}{U(s)}=\frac{L(s,\lambda,k)}{1+L(s,\lambda,k)},",
  "T(s,λ,k)=(Y(s))/(U(s))=(L(s,λ,k))/(1+L(s,λ,k))")
P("where $U(s)$ and $Y(s)$ are the Laplace transforms of $u(t)$ and $y(t)$. As in [2], the NCF margin [1] is evaluated "
  "with the plant $P=L$ and unit feedback $K=1$, for which the general definition reduces to")
E("bncf", r"b_{\mathrm{NCF}}(\lambda,k)=\underset{\omega}{\inf}\;\delta\big(L(j\omega,\lambda,k)\big),",
  "b_(\"NCF\") (λ,k)=\"inf\"┬ω  δ(L(jω,λ,k))")
E("delta", r"\delta(L)=\frac{|1+L|}{\sqrt{2\left(1+|L|^{2}\right)}}.",
  "δ(L)=(|1+L|)/(√(2(1+|L|^2)))")
P("The function $\\delta$ is the chordal distance between $L(j\\omega)$ and the critical point $-1$. All branches of the "
  "estimator evaluate the capped distance")
E("phi", r"\phi(L)=\min\left\{\delta(L),\,\frac{1}{\sqrt{2}}\right\}.", "ϕ(L)=\"min\"{δ(L),1/√2}")
P("Because $|1+L|^{2}-(1+|L|^{2})=2\\,\\mathrm{Re}\\,L$, the distance exceeds $\\delta(0)=1/\\sqrt{2}$ only where "
  "$\\mathrm{Re}\\,L>0$, that is, where the loop response lies far from the critical point. The cap removes credit from "
  "these frequencies and bounds the reported indicator by $1/\\sqrt{2}$.")

H2("2.2", "Short-time spectral estimation", "s2")
P("The estimator is updated every $\\Delta t=0.125\\,\\mathrm{s}$ from the most recent $T_w=0.5\\,\\mathrm{s}$ of $u$ and "
  "$y$, so consecutive windows overlap by 75%. At $f_s=2048\\,\\mathrm{Hz}$, each window holds $N=f_sT_w=1024$ samples "
  "and the bin spacing is 2 Hz. With $n$ indexing the update and $r=0,\\dots,N-1$ the samples in the window, the "
  "Hann-windowed discrete Fourier transforms are")
E("dft", r"X_n(\omega_m)=\sum_{r=0}^{N-1}w[r]\,x_n[r]\,e^{-j2\pi mr/N},\qquad x\in\{u,y\},",
  "X_n (ω_m)=∑_(r=0)^(N−1)▒〖w[r] x_n [r] e^(−j2πmr/N)〗,  x∈{u,y}")
P("where $w[r]=\\tfrac{1}{2}\\{1-\\cos[2\\pi r/(N-1)]\\}$ and $\\omega_m=2\\pi mf_s/N$. The instantaneous auto- and "
  "cross-spectra")
E("spec", r"p_{uu,n}=|U_n|^{2},\qquad p_{yy,n}=|Y_n|^{2},\qquad p_{yu,n}=Y_n\,U_n^{*}",
  "p_(uu,n)=|U_n |^2,  p_(yy,n)=|Y_n |^2,  p_(yu,n)=Y_n U_n^*")
P("are unnormalized, because the normalization cancels in every ratio used below. The argument $\\omega_m$ is omitted "
  "for brevity. Following the averaging of modified periodograms [3] with exponential weighting [4], each spectrum is "
  "smoothed recursively and initialized by the first complete window:")
E("ewma", r"\bar{p}_{ab,n}(\omega)=(1-\eta_s)\,\bar{p}_{ab,n-1}(\omega)+\eta_s\,p_{ab,n}(\omega),\qquad ab\in\{uu,yy,yu\}.",
  "p̄_(ab,n) (ω)=(1−η_s) p̄_(ab,n−1) (ω)+η_s p_(ab,n) (ω), ab∈{uu,yy,yu}")
P("The analysis set retains the 2–100 Hz band and rejects line noise:")
E("omega", r"\Omega=\left\{\omega_m:\;2\le f_m\le 100\ \mathrm{Hz},\;f_m\notin[58,62]\ \mathrm{Hz}\right\},\qquad f_m=\frac{\omega_m}{2\pi},",
  "Ω={ω_m:2≤f_m≤100 \"Hz\", f_m∉[58,62]\" Hz\"},  f_m=(ω_m)/(2π)")
P("which leaves 47 bins. Hereafter $\\omega\\in\\Omega$, and the subscript $n$ denotes the operating condition "
  "$(\\lambda_n,k_n)$ at update $n$. The current stiffness $k_n$ is unknown and is not estimated.")

H2("2.3", "Direct identification branch", "s3")
P("The averaged spectra give the closed-loop estimate and the magnitude-squared coherence")
E("that", r"\hat{T}_n(j\omega)=\frac{\bar{p}_{yu,n}(\omega)}{\bar{p}_{uu,n}(\omega)},\qquad \gamma_n^{2}(\omega)=\frac{|\bar{p}_{yu,n}(\omega)|^{2}}{\bar{p}_{uu,n}(\omega)\,\bar{p}_{yy,n}(\omega)}.",
  "T̂_n (jω)=(p̄_(yu,n) (ω))/(p̄_(uu,n) (ω)),  γ_n^2 (ω)=(|p̄_(yu,n) (ω)|^2)/(p̄_(uu,n) (ω) p̄_(yy,n) (ω))")
P("The ratio is an unbiased estimate of $T(j\\omega,\\lambda_n,k_n)$ only if the output disturbance is uncorrelated with "
  "$u$. This is not guaranteed in hybrid simulation, because $u$ is computed from the measured force through the numerical "
  "substructure. High coherence is therefore treated as supporting evidence rather than proof of an unbiased estimate [5].")
P("The weight given to $\\hat{T}_n$ combines three factors. Command activity is detected from the window RMS "
  "$u_{\\mathrm{rms},n}=\\big(N^{-1}\\sum_r u_n[r]^{2}\\big)^{1/2}$:")
E("act", r"A_n=\begin{cases}1, & u_{\mathrm{rms},n}>\eta_A,\\ 0, & \text{otherwise}.\end{cases}",
  "A_n={■(1,&u_(\"rms\",n)>η_A@0,&\"otherwise\")┤")
P("The threshold $\\eta_A$ is approximately $4.54\\,\\sigma_{u,0}$, where $\\sigma_{u,0}$ is the command-noise standard "
  "deviation measured in a quiet record. Within an active window, bins that carry little command energy are discounted "
  "through the input leverage")
E("lev", r"\ell_n(\omega)=\frac{p_{\mathrm{rel},n}(\omega)}{p_{\mathrm{rel},n}(\omega)+p_{\mathrm{floor}}},\qquad p_{\mathrm{rel},n}(\omega)=\frac{\bar{p}_{uu,n}(\omega)}{\max_{\nu\in\mathcal{B}}\bar{p}_{uu,n}(\nu)},",
  "ℓ_n (ω)=(p_(\"rel\",n) (ω))/(p_(\"rel\",n) (ω)+p_(\"floor\") ),  p_(\"rel\",n) (ω)=(p̄_(uu,n) (ω))/(\"max\"┬(ν∈ℬ)  p̄_(uu,n) (ν))")
P("where $\\mathcal{B}$ is the full 2–100 Hz grid. The confidence")
E("conf", r"c_n(\omega)=A_n\,\gamma_n^{2}(\omega)\,\ell_n(\omega),\qquad 0\le c_n(\omega)\le 1,",
  "c_n (ω)=A_n γ_n^2 (ω) ℓ_n (ω), 0≤c_n (ω)≤1")
P("is a weighting factor, not a probability. Where it is small, the measurement is replaced by the initial-state prior at the "
  "current adaptive factor. With $L_0(j\\omega)=C(j\\omega)H(j\\omega,k_0)$ the full-gain loop identified at the initial "
  "stiffness $k_0$, the prior is")
E("prior", r"L_{\mathrm{pr},n}(j\omega)=\lambda_n L_0(j\omega),\qquad T_{\mathrm{pr},n}(j\omega)=\frac{L_{\mathrm{pr},n}(j\omega)}{1+L_{\mathrm{pr},n}(j\omega)}.",
  "L_(\"pr\",n) (jω)=λ_n L_0 (jω),  T_(\"pr\",n) (jω)=(L_(\"pr\",n) (jω))/(1+L_(\"pr\",n) (jω))")
P("Measurement and prior are blended in the closed-loop domain, where the spectral estimate is formed, and the loop is "
  "recovered by inverting {eq:T}:")
E("blend", r"\tilde{T}_n(j\omega)=c_n\,\hat{T}_n(j\omega)+(1-c_n)\,T_{\mathrm{pr},n}(j\omega),\qquad \hat{L}_n(j\omega)=\frac{\tilde{T}_n(j\omega)}{1-\tilde{T}_n(j\omega)}.",
  "T̃_n (jω)=c_n T̂_n (jω)+(1−c_n ) T_(\"pr\",n) (jω),  L̂_n (jω)=(T̃_n (jω))/(1−T̃_n (jω))")
P("A well-supported measurement therefore governs $\\hat{L}_n$, while a weakly supported one leaves it close to the "
  "prior. The identified and prior margin curves are")
E("bid", r"b_{\mathrm{id},n}(\omega)=\operatorname{med}_3\left\{\phi\big(\hat{L}_n(j\omega)\big)\right\},\qquad b_{0,n}(\omega)=\phi\big(L_{\mathrm{pr},n}(j\omega)\big),",
  "b_(\"id\",n) (ω)=\"med\"_3 {ϕ(L̂_n (jω))},  b_(0,n) (ω)=ϕ(L_(\"pr\",n) (jω))")
P("where $\\operatorname{med}_3$ is a three-bin moving median over frequency that suppresses isolated spectral outliers.")

H2("2.4", "Output-power inference branch", "s4")
P("When the command is weak, $\\hat{T}_n$ is unreliable, but the measured output power still reflects the loop. The "
  "first three non-overlapping windows are assumed to represent the initial loop at full gain and define the initial reference "
  "power and the observed ratio")
E("qobs", r"p_{yy,0}(\omega)=\underset{h=1,2,3}{\operatorname{median}}\left|Y_h^{(0)}(\omega)\right|^{2},\qquad q_{\mathrm{obs},n}(\omega)=\frac{\bar{p}_{yy,n}(\omega)}{p_{yy,0}(\omega)},",
  "p_(yy,0) (ω)=\"median\"┬(h=1,2,3)  |Y_h^((0)) (ω)|^2,  q_(\"obs\",n) (ω)=(p̄_(yy,n) (ω))/(p_(yy,0) (ω))")
P("where $Y_h^{(0)}$ is the transform of $y$ in reference window $h$. If $y$ is dominated by an equivalent output "
  "disturbance whose spectrum is unchanged from the reference period, the output is shaped by the sensitivity "
  "$1/(1+L)$, and a candidate loop $\\lambda_n g L_0$ predicts the ratio")
E("qmod", r"q_{\mathrm{mod},n}(\omega,g)=\left|\frac{1+L_0(j\omega)}{1+\lambda_n g\,L_0(j\omega)}\right|^{2}.",
  "q_(\"mod\",n) (ω,g)=〖|(1+L_0 (jω))/(1+λ_n g L_0 (jω))|〗^2")
P("The positive scalar $g$ is an effective change in loop magnitude, not an estimate of $k$. It is fitted in each bin "
  "by matching the ratios on a logarithmic scale:")
E("gfit", r"g_{\mathrm{fit},n}(\omega)=\underset{g\in\mathcal{G}}{\operatorname{arg\,min}}\;\left|\log\,q_{\mathrm{obs},n}(\omega)-\log\,q_{\mathrm{mod},n}(\omega,g)\right|,",
  "g_(\"fit\",n) (ω)=\"arg min\"┬(g∈𝒢)  |log q_(\"obs\",n) (ω)−log q_(\"mod\",n) (ω,g)|")
P("where $\\mathcal{G}$ holds 25 logarithmically spaced values from 0.5 to 6. Because each bin is fitted independently, "
  "the curve $g(\\omega)$ is an inference model rather than an identified transfer function. The fitted change is "
  "retained in a logarithmic memory initialized at $\\bar{g}_0=1$:")
E("gmem", r"\log\,\bar{g}_n(\omega)=(1-\eta_g)\log\,\bar{g}_{n-1}(\omega)+\eta_g\log\,g_{\mathrm{tar},n}(\omega).",
  "log ḡ_n (ω)=(1−η_g) log ḡ_(n−1) (ω)+η_g log g_(\"tar\",n) (ω)")
P("While the command is active ($A_n=1$), the target is $g_{\\mathrm{tar},n}=g_{\\mathrm{fit},n}$. Recovery is judged "
  "from the band-median ratio")
E("rband", r"r_{\Omega,n}=\underset{\omega\in\Omega}{\operatorname{median}}q_{\mathrm{obs},n}(\omega).",
  "r_(Ω,n)=\"median\"┬(ω∈Ω)  q_(\"obs\",n) (ω)")
P("When $r_{\\Omega,n}<1$, the output power has fallen below the initial reference, and the memory decays toward "
  "$\\bar{g}=1$ with $g_{\\mathrm{tar},n}=1$ and $\\eta_g$ replaced by $\\eta_r$. Otherwise $\\bar{g}_n$ is held, so a "
  "detected change remains represented while the excitation is weak. The output-power margin curve uses the same capped "
  "distance as {eq:bid}:")
E("bres", r"b_{\mathrm{pow},n}(\omega)=\operatorname{med}_3\left\{\phi\big(\lambda_n\bar{g}_n(\omega)L_0(j\omega)\big)\right\}.",
  "b_(\"pow\",n) (ω)=\"med\"_3 {ϕ(λ_n ḡ_n (ω) L_0 (jω))}")

H2("2.5", "Per-frequency fusion and reported indicator", "s5")
P("The output-power branch is trusted in proportion to the size of the inferred change,")
E("det", r"d_n(\omega)=\operatorname{clip}_{[0,1]}\left(\frac{\bar{g}_n(\omega)-1}{g_{\mathrm{det}}-1}\right),",
  "d_n (ω)=\"clip\"_([0,1]) ((ḡ_n (ω)−1)/(g_(\"det\")−1))")
P("which rises linearly from zero at $\\bar{g}_n=1$ to one at $\\bar{g}_n=g_{\\mathrm{det}}$. The three branches are "
  "weighted at each frequency by")
E("w", r"w_{\mathrm{id},n}=c_n,\qquad w_{\mathrm{pow},n}=(1-c_n)\,d_n,\qquad w_{0,n}=(1-c_n)(1-d_n),",
  "w_(\"id\",n)=c_n,  w_(\"pow\",n)=(1−c_n ) d_n,  w_(0,n)=(1−c_n )(1−d_n )")
P("which are nonnegative and sum to one. Direct identification receives the share supported by the measurement, the "
  "output-power branch receives the remainder in proportion to its detection weight, and the prior receives what neither "
  "measurement supports (Table 2). The fused margin curve is")
E("beta", r"\beta_n(\omega)=w_{\mathrm{id},n}\,b_{\mathrm{id},n}(\omega)+w_{\mathrm{pow},n}\,b_{\mathrm{pow},n}(\omega)+w_{0,n}\,b_{0,n}(\omega).",
  "β_n (ω)=w_(\"id\",n) b_(\"id\",n) (ω)+w_(\"pow\",n) b_(\"pow\",n) (ω)+w_(0,n) b_(0,n) (ω)")
P("Fusion is performed bin by bin, before any reduction over frequency, so margins evaluated at different frequencies "
  "are never combined. The idle case needs no special treatment: when the command is inactive, $c_n=0$ in every bin, "
  "an unchanged loop reads its gain-scaled prior, and a bin with a remembered change continues to report it.")
P("The instantaneous indicator is the second-smallest value of $\\beta_n$ over $\\Omega$,")
E("binst", r"b_{\mathrm{inst},n}=\beta_{n,(2)}=\beta_n(\omega_{*,n}),", "b_(\"inst\",n)=β_(n,(2))=β_n (ω_(*,n))")
P("where $\\omega_{*,n}$ is the governing frequency. Discarding the lowest bin prevents a single outlier from governing "
  "the estimate, at the cost of attenuating a genuine minimum that is only one bin wide. The reported indicator is "
  "smoothed in time,")
E("bosi", r"b_{\mathrm{OSI},n}=(1-\eta_b)\,b_{\mathrm{OSI},n-1}+\eta_b\,b_{\mathrm{inst},n},",
  "b_(\"OSI\",n)=(1−η_b) b_(\"OSI\",n−1)+η_b b_(\"inst\",n)")
P("and is used by the adaptive law to update $\\lambda_{n+1}$. Figure 2 summarizes one update, and Table 1 lists the "
  "estimator parameters.")

RAW('''<figure id="fig2"><svg role="img" aria-labelledby="f2t f2d" viewBox="0 0 1000 480">
<title id="f2t">Structure of one estimator update</title>
<desc id="f2d">Windowed displacements u and y feed the spectral estimator. Its spectra feed the identification and output-power branches. A third branch is the initial-state prior scaled by lambda. The three margin curves are fused per frequency bin, reduced by the second-smallest value over the analysis band, and smoothed to give b_OSI, which drives the adaptive law that returns lambda.</desc>
<defs><marker id="a2" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="context-stroke"/></marker></defs>
<g fill="none" stroke="currentColor" stroke-width="1.6">
<rect x="56" y="150" width="208" height="100"/>
<rect x="320" y="30" width="280" height="90"/><rect x="320" y="155" width="280" height="90"/><rect x="320" y="280" width="280" height="90"/>
<rect x="680" y="150" width="180" height="100"/><rect x="680" y="300" width="180" height="70"/>
<rect x="320" y="400" width="280" height="56"/>
<path d="M10 180 H54" marker-end="url(#a2)"/>
<path d="M264 200 H318" marker-end="url(#a2)"/><path d="M285 200 V75 H318" marker-end="url(#a2)"/>
<path d="M600 75 H640 V180 H678" marker-end="url(#a2)"/><path d="M600 200 H678" marker-end="url(#a2)"/><path d="M600 325 H640 V220 H678" marker-end="url(#a2)"/>
<path d="M770 250 V298" marker-end="url(#a2)"/><path d="M860 335 H988" marker-end="url(#a2)"/>
<path d="M930 335 V428 H602" marker-end="url(#a2)"/><path d="M460 400 V372" marker-end="url(#a2)"/>
</g><path d="M10 220 H54" fill="none" stroke="#007CA8" stroke-width="1.6" marker-end="url(#a2)"/><circle cx="285" cy="200" r="3.5" fill="currentColor"/><circle cx="930" cy="335" r="3.5" fill="currentColor"/>
<g text-anchor="middle">
<text x="28" y="172" class="it">u</text><text x="28" y="212" class="it" fill="#007CA8">y</text>
<text x="160" y="190">Windowed DFT,</text><text x="160" y="214">averaged spectra</text><text x="160" y="238" class="nt">Eqs. (6)–(8)</text>
<text x="460" y="64">Direct identification</text><text x="460" y="90" class="nt">T̂, γ², c → b<tspan font-size="13" dy="4">id</tspan><tspan dy="-4">(ω)</tspan></text><text x="460" y="112" class="nt">Eqs. (10)–(16)</text>
<text x="460" y="189">Output-power inference</text><text x="460" y="215" class="nt">q<tspan font-size="13" dy="4">obs</tspan><tspan dy="-4">, ḡ → b</tspan><tspan font-size="13" dy="4">pow</tspan><tspan dy="-4">(ω)</tspan></text><text x="460" y="237" class="nt">Eqs. (17)–(22)</text>
<text x="460" y="314">Initial-state prior</text><text x="460" y="340" class="nt">λL<tspan font-size="13" dy="4">0</tspan><tspan dy="-4"> → b</tspan><tspan font-size="13" dy="4">0</tspan><tspan dy="-4">(ω)</tspan></text><text x="460" y="362" class="nt">Eqs. (14), (16)</text>
<text x="770" y="190">Per-bin fusion</text><text x="770" y="215" class="nt">β(ω)</text><text x="770" y="238" class="nt">Eqs. (23)–(25)</text>
<text x="770" y="330">Trim and smooth</text><text x="770" y="356" class="nt">Eqs. (26)–(27)</text>
<text x="460" y="434">Adaptive law</text>
<text x="620" y="66" class="it">w<tspan font-size="14" dy="4">id</tspan></text><text x="624" y="190" class="it">w<tspan font-size="14" dy="4">pow</tspan></text><text x="620" y="316" class="it">w<tspan font-size="14" dy="4">0</tspan></text>
<text x="958" y="322" class="nt">b<tspan font-size="13" dy="4">OSI</tspan></text>
<text x="484" y="392" class="it">λ</text>
</g></svg>
<figcaption><b>Figure 2.</b> One estimator update. Branch weights from Eq. (24) are marked on the arrows entering the fusion block, and the adaptive factor also enters the initial-state prior and the output-power model.</figcaption></figure>''')

def trow(cells, tag="td"):
    return "<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in cells) + "</tr>"

T1 = [
    ("$\\Delta t$", "0.125 s", "—", "Update interval"),
    ("$T_w$, $N$", "0.5 s, 1024", "—", "Window length at $f_s=2048$ Hz"),
    ("$\\Omega$", "2–100 Hz, 47 bins", "—", "Analysis set, 58–62 Hz rejected"),
    ("$\\eta_s$", "0.39", "0.25 s", "Spectral averaging, {eq:ewma}"),
    ("$\\eta_A$", "0.0575", "—", "Activity threshold, recorded displacement units, {eq:act}"),
    ("$p_{\\mathrm{floor}}$", "$10^{-3}$", "—", "Input-leverage reference, {eq:lev}"),
    ("$\\mathcal{G}$", "0.5–6, 25 values", "—", "Candidate loop-magnitude changes, {eq:gfit}"),
    ("$\\eta_g$", "0.12", "1.0 s", "Output-power memory, accumulation, {eq:gmem}"),
    ("$\\eta_r$", "0.27", "0.4 s", "Output-power memory, recovery"),
    ("$g_{\\mathrm{det}}$", "1.75", "—", "Detection scale, {eq:det}"),
    ("$\\eta_b$", "0.39", "0.25 s", "Indicator smoothing, {eq:bosi}"),
]
RAW('<figure class="table" id="tab1"><figcaption><b>Table 1.</b> Estimator parameters. Smoothing coefficients follow '
    + inline("$\\eta=1-\\exp(-\\Delta t/\\tau)$") + ' from the listed time constant.</figcaption><table class="border-white/10">'
    + "<thead>" + trow(["Symbol", "Value", "$\\tau$", "Role"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in T1) + "</tbody></table></figure>")

T2 = [
    ("Direct identification", "Cross-spectrum of $u$ and $y$", "$c$", "Active, coherent, well-excited bins",
     "Disturbance uncorrelated with $u$"),
    ("Output-power inference", "$\\bar{p}_{yy}$ relative to initial reference", "$(1-c)\\,d$",
     "Weak excitation after a detected change", "Stationary disturbance and a magnitude-only change"),
    ("Initial-state prior", "$\\lambda_n L_0$", "$(1-c)(1-d)$", "No measured evidence", "Loop unchanged from the initial state"),
]
RAW('<figure class="table" id="tab2"><figcaption><b>Table 2.</b> Evidence sources fused in '
    + ref("beta") + '.</figcaption><table class="border-white/10">'
    + "<thead>" + trow(["Branch", "Evidence", "Weight", "Governs in", "Principal assumption"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in T2) + "</tbody></table></figure>")

H2("2.6", "Assumptions and limitations", "s6")
RAW('<ol class="assumptions">' + "".join(f"<li>{inline(t)}</li>" for t in [
    "The identification branch assumes that the output disturbance is uncorrelated with $u$. Feedback through the "
    "numerical substructure can violate this assumption and bias $\\hat{T}_n$ even at high coherence [5].",
    "The output-power branch assumes that the disturbance spectrum is unchanged from the reference period and that the "
    "first 1.5 s represent the initial loop at full gain. A change in disturbance intensity or in the command-driven "
    "response can alter $q_{\\mathrm{obs}}$ without any change in stability.",
    "The factor $g$ is real, so the output-power branch represents changes in loop magnitude but not in loop phase.",
    "Band limitation, trimming, and temporal smoothing mean that $b_{\\mathrm{OSI}}$ is not a guaranteed lower bound on "
    "the full-frequency margin $b_{\\mathrm{NCF}}$, and it follows abrupt changes with a delay set by $\\eta_b$.",
]) + "</ol>")

REFS = '''<li id="citation1">K. Glover and D. McFarlane, “Robust stabilization of normalized coprime factor plant descriptions with H<sub>∞</sub>-bounded uncertainty,” <i>IEEE Transactions on Automatic Control</i>, vol. 34, no. 8, pp. 821–830, 1989. <a href="https://doi.org/10.1109/9.29424">doi:10.1109/9.29424</a></li>
<li id="citation2">M. Gomaa, E. D. Patino, J. N. Villamizar, J. W. Condori Uribe, and S. J. Dyke, “An online stability indicator for real-time hybrid simulation emphasizing physical substructure degradation,” author manuscript.</li>
<li id="citation3">P. D. Welch, “The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms,” <i>IEEE Transactions on Audio and Electroacoustics</i>, vol. 15, no. 2, pp. 70–73, 1967. <a href="https://doi.org/10.1109/TAU.1967.1161901">doi:10.1109/TAU.1967.1161901</a></li>
<li id="citation4">S. W. Roberts, “Control chart tests based on geometric moving averages,” <i>Technometrics</i>, vol. 1, no. 3, pp. 239–250, 1959. <a href="https://doi.org/10.1080/00401706.1959.10489860">doi:10.1080/00401706.1959.10489860</a></li>
<li id="citation5">U. Forssell and L. Ljung, “Closed-loop identification revisited,” <i>Automatica</i>, vol. 35, no. 7, pp. 1215–1241, 1999. <a href="https://doi.org/10.1016/S0005-1098(99)00022-9">doi:10.1016/S0005-1098(99)00022-9</a></li>'''

body = "\n".join(parts)
body = re.sub(r"\[(\d)\]", r'[<a href="#citation\1">\1</a>]', body)

# ---------------------------------------------------------------- page
CSS = r"""
:root { color-scheme: light; --ink: #1c1c1c; --muted: #5a5a5a; --rule: #1c1c1c; --hair: #c9c9c9; --link: #0b5c7a; --paper: #fff; }
* { box-sizing: border-box; }
html { background: var(--paper); }
body { margin: 0; background: var(--paper); color: var(--ink); font: 17px/1.62 "STIX Two Text", Cambria, "Times New Roman", serif; }
.page { max-width: 780px; margin: 0 auto; padding: 36px 36px 96px; }
.runhead { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding-bottom: 7px; border-bottom: 1px solid var(--rule); font: 12.5px/1.4 "Segoe UI", Arial, sans-serif; letter-spacing: .02em; color: var(--muted); }
.runhead button { font: inherit; color: var(--ink); background: none; border: 1px solid var(--hair); padding: 2px 9px; cursor: pointer; }
h1 { font-size: 27px; line-height: 1.25; font-weight: 700; margin: 30px 0 10px; }
.meta { margin: 0 0 22px; font: 13px/1.5 "Segoe UI", Arial, sans-serif; color: var(--muted); }
.lead { padding: 14px 0; margin: 0 0 8px; border-top: 1px solid var(--hair); border-bottom: 1px solid var(--hair); font-size: 16px; }
h2 { font-size: 18px; line-height: 1.35; font-weight: 700; margin: 34px 0 10px; }
.secno { display: inline-block; min-width: 2.6em; }
p { margin: 0 0 12px; text-align: justify; hyphens: auto; }
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
math { font-family: "STIX Two Math", "Cambria Math", math; }
.equation { display: grid; grid-template-columns: 1fr auto auto; align-items: center; gap: 12px; margin: 14px 0 16px; }
.expression { overflow-x: auto; padding: 4px 0; text-align: center; }
.eqno { min-width: 34px; text-align: right; }
.copy-equation { visibility: hidden; width: 24px; height: 24px; padding: 4px; border: 1px solid var(--hair); background: none; color: var(--muted); cursor: pointer; }
.equation:hover .copy-equation, .copy-equation:focus-visible { visibility: visible; }
figure { margin: 26px 0; }
svg { display: block; width: 100%; height: auto; color: var(--ink); }
svg text { font: 22px "STIX Two Text", Cambria, "Times New Roman", serif; fill: currentColor; }
svg .it { font-style: italic; }
svg .nt { font-size: 18px; }
#fig1 svg text { font-size: 24px; }
#fig1 svg .nt { font-size: 20px; }
figcaption { font-size: 14.5px; line-height: 1.5; margin-top: 8px; }
.table figcaption { margin: 0 0 6px; }
table { width: 100%; border-collapse: collapse; font-size: 14.5px; line-height: 1.4; border-top: 1.5px solid var(--rule); border-bottom: 1.5px solid var(--rule); }
th { text-align: left; font-weight: 700; padding: 6px 10px 5px 0; border-bottom: 1px solid var(--rule); }
td { padding: 5px 10px 5px 0; vertical-align: top; }
tbody tr + tr td { border-top: 1px solid #ececec; }
.assumptions { counter-reset: a; list-style: none; padding: 0; margin: 0 0 12px; }
.assumptions li { counter-increment: a; position: relative; padding-left: 3em; margin-bottom: 8px; text-align: justify; }
.assumptions li::before { content: "(A" counter(a) ")"; position: absolute; left: 0; }
.references { margin-top: 38px; border-top: 1px solid var(--rule); }
.references h2 { font-size: 15px; margin: 12px 0 8px; }
.references ol { margin: 0; padding-left: 26px; font-size: 14.5px; line-height: 1.5; }
.references li { margin-bottom: 7px; }
.selection-status { position: fixed; left: 0; right: 0; bottom: 0; padding: 6px 20px; border-top: 1px solid var(--hair); background: var(--paper); color: var(--muted); font: 12.5px/1.4 "Segoe UI", Arial, sans-serif; text-align: center; pointer-events: none; }
/* optional dark screen-reading mode; print always uses paper */
body.bg-zinc-950 { --ink: #e4e4e7; --muted: #a1a1aa; --rule: #d4d4d8; --hair: rgba(255,255,255,.1); --link: #7cc4de; --paper: #09090b; }
body.bg-zinc-950 .border-white\/10 tbody tr + tr td { border-top-color: rgba(255,255,255,.1); }
.runhead .tools { display: flex; gap: 8px; align-items: center; }
mark.cmt { background: #fbe7a1; color: inherit; cursor: pointer; }
mark.cmt.open { background: #f5cf5c; }
.cmt-block { outline: 2px solid #f5cf5c; outline-offset: 3px; }
.cmt-pin { display: inline-block; margin: 0 2px; padding: 0 5px; border: 1px solid #AC6420; background: var(--paper); color: #AC6420; font: 700 11px/1.5 "Segoe UI", Arial, sans-serif; vertical-align: super; cursor: pointer; }
#cmt-add, #cmt-pop { position: absolute; z-index: 20; font: 13px/1.4 "Segoe UI", Arial, sans-serif; }
#cmt-add { width: 30px; height: 30px; padding: 5px; border: 1px solid var(--ink); background: var(--paper); color: var(--ink); cursor: pointer; }
#cmt-add:hover, #cmt-add:focus-visible { color: #AC6420; border-color: #AC6420; }
.ibtn { position: relative; width: 30px; height: 30px; padding: 5px; border: 1px solid var(--hair); background: none; color: var(--ink); cursor: pointer; }
.ibtn:hover, .ibtn:focus-visible, .ibtn.on { color: #AC6420; border-color: #AC6420; }
.ibtn svg, #cmt-add svg, .copy-equation svg { display: block; width: 100%; height: 100%; fill: none; stroke: currentColor; stroke-width: 2; stroke-linejoin: round; stroke-linecap: round; }
.badge { position: absolute; top: -7px; right: -7px; min-width: 16px; padding: 0 3px; background: #AC6420; color: #fff; font: 700 10px/16px "Segoe UI", Arial, sans-serif; text-align: center; }
#track-bar { display: flex; flex-wrap: wrap; gap: 14px; align-items: center; margin-top: 12px; padding: 8px 0; border-bottom: 1px solid var(--hair); font: 13px/1.4 "Segoe UI", Arial, sans-serif; color: var(--muted); }
#track-bar[hidden], #track-view[hidden], article[hidden] { display: none; }
#track-bar select { max-width: 250px; padding: 2px 4px; border: 1px solid var(--hair); background: var(--paper); color: var(--ink); font: inherit; }
ins { color: #007CA8; text-decoration: underline; text-decoration-thickness: 1px; }
del { color: #901500; text-decoration: line-through; }
ins math { background: rgba(0,124,168,.12); } del math { background: rgba(144,21,0,.12); }
.tr-mod, .tr-ins-block, .tr-del-block { position: relative; }
.tr-mod::before, .tr-ins-block::before, .tr-del-block::before { content: ""; position: absolute; left: -16px; top: 0; bottom: 0; border-left: 2px solid var(--muted); }
.tr-ins-block, .tr-ins-block svg { color: #007CA8; } .tr-ins-block { text-decoration: underline; text-decoration-thickness: 1px; }
.tr-del-block, .tr-del-block svg { color: #901500; } .tr-del-block { text-decoration: line-through; }
#cmt-pop { width: 340px; padding: 10px; border: 1px solid var(--rule); background: var(--paper); color: var(--ink); }
#cmt-pop .q { margin-bottom: 6px; color: var(--muted); max-height: 3.6em; overflow: hidden; }
#cmt-pop textarea { width: 100%; min-height: 84px; resize: vertical; font: inherit; color: inherit; background: var(--paper); border: 1px solid var(--hair); padding: 5px; }
#cmt-pop .row { display: flex; justify-content: space-between; margin-top: 6px; }

body.bg-zinc-950 mark.cmt { background: #5c4a12; }
@media (max-width: 640px) { body { font-size: 16px; } .page { padding: 22px 18px 80px; } p, .assumptions li { text-align: left; } }
@media print {
  .selection-status, .copy-equation, .runhead .tools, .cmt-pin, #cmt-add, #cmt-pop, #track-bar { display: none; }
  mark.cmt { background: none; }
  body { font-size: 10.5pt; --ink: #000; --paper: #fff; --muted: #333; --rule: #000; --link: #000; }
  .page { max-width: none; padding: 0; }
  h2 { break-after: avoid; } figure, .equation, table { break-inside: avoid; }
  @page { size: A4; margin: 22mm 20mm; }
}
"""

JS = r"""
const ICON = %s;
const wordEquations = %s;
const copyText = async text => {
  try { await navigator.clipboard.writeText(text); }
  catch {
    const t = document.createElement('textarea');
    t.value = text; t.style.position = 'fixed'; t.style.opacity = '0';
    document.body.appendChild(t); t.select();
    const ok = document.execCommand('copy'); t.remove();
    if (!ok) throw new Error('Clipboard copy was not available.');
  }
};
document.querySelectorAll('.equation').forEach(eq => {
  const number = eq.querySelector('.eqno').textContent;
  const text = wordEquations[eq.id];
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'copy-equation'; b.innerHTML = ICON.copy;
  b.title = 'Word: Alt+= → UnicodeMath → paste → Convert to Professional';
  b.setAttribute('aria-label', `Copy equation ${number} as UnicodeMath for Microsoft Word`);
  b.addEventListener('click', async () => {
    try { await copyText(text); b.innerHTML = ICON.check; } catch { b.title = 'Copy failed'; }
    setTimeout(() => { b.innerHTML = ICON.copy; }, 1400);
  });
  eq.insertBefore(b, eq.querySelector('.eqno'));
});
const theme = document.getElementById('theme');
theme.addEventListener('click', () => {
  const dark = document.body.classList.toggle('bg-zinc-950');
  theme.innerHTML = dark ? ICON.sun : ICON.moon;
  theme.title = dark ? 'Paper view' : 'Dark view';
});
const seg = new Intl.Segmenter('en', { granularity: 'word' });
const counter = document.getElementById('selected-word-count');
document.addEventListener('selectionchange', () => {
  let n = 0;
  for (const s of seg.segment(window.getSelection().toString())) if (s.isWordLike) n++;
  counter.textContent = n.toLocaleString('en');
});
""" % (json.dumps(ICONS), json.dumps(WORD, ensure_ascii=False, indent=2)) + r"""
// ---- review comments: stored in localStorage, exported as JSON for Claude
const article = document.querySelector('article');
const KEY = 'comments:' + location.pathname;
let comments = JSON.parse(localStorage.getItem(KEY) || '[]');
let openId = null, pending = null;
const addBtn = Object.assign(document.createElement('button'), { id: 'cmt-add', type: 'button', title: 'Add comment', hidden: true });
addBtn.setAttribute('aria-label', 'Add comment');
addBtn.innerHTML = ICON.comment;
const pop = Object.assign(document.createElement('div'), { id: 'cmt-pop', hidden: true });
pop.innerHTML = '<div class="q"></div><textarea placeholder="Type a comment. Click elsewhere or Ctrl+Enter to save."></textarea><div class="row"><button type="button" class="ibtn" data-a="del" title="Delete comment" aria-label="Delete comment">' + ICON.trash + '</button><button type="button" class="ibtn" data-a="save" title="Save comment" aria-label="Save comment">' + ICON.check + '</button></div>';
document.body.append(addBtn, pop);
const area = pop.querySelector('textarea');

const textNodes = () => {
  const w = document.createTreeWalker(article, NodeFilter.SHOW_TEXT, { acceptNode: n =>
    n.parentElement.closest('.cmt-pin, .copy-equation, title, desc') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT });
  const list = []; let pos = 0, n;
  while ((n = w.nextNode())) { list.push({ n, s: pos }); pos += n.data.length; }
  return { list, text: list.map(x => x.n.data).join('') };
};
const offsetOf = (list, container, offset) => {
  if (container.nodeType === 3) { const x = list.find(x => x.n === container); if (x) return x.s + offset; }
  const probe = document.createRange(); probe.setStart(container, offset);
  const x = list.find(x => probe.comparePoint(x.n, 0) >= 0);
  return x ? x.s : list.reduce((a, x) => a + x.n.data.length, 0);
};
const sectionOf = node => {
  let h = 'Opening';
  article.querySelectorAll('h2').forEach(e => { if (e.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) h = e.textContent; });
  return h;
};
const store = () => {
  localStorage.setItem(KEY, JSON.stringify(comments));
  const badge = document.getElementById('cmt-count');
  badge.textContent = comments.length; badge.hidden = !comments.length;
  document.getElementById('cmt-save').title = `Save comments file (${comments.length})`;
};

function paint(c) {
  const { list } = textNodes();
  const marks = [];
  for (const { n, s } of list) {
    const a = Math.max(c.start - s, 0), b = Math.min(c.end - s, n.data.length);
    if (a >= b) continue;
    const box = n.parentElement.closest('svg') ? n.parentElement.closest('figure') : n.parentElement.closest('math');
    if (box) { if (marks[marks.length - 1] !== box) marks.push(box); continue; }
    let t = n; if (a > 0) t = t.splitText(a); if (b - a < t.data.length) t.splitText(b - a);
    const m = document.createElement('mark'); m.className = 'cmt'; m.dataset.id = c.id; t.replaceWith(m); m.append(t); marks.push(m);
  }
  if (!marks.length) return false;
  marks.filter(m => m.tagName !== 'MARK').forEach(e => { e.classList.add('cmt-block'); e.dataset.cmt = c.id; });
  const pin = Object.assign(document.createElement('span'), { className: 'cmt-pin', title: c.text });
  pin.dataset.id = c.id; pin.setAttribute('role', 'button');
  pin.textContent = comments.indexOf(c) + 1;
  const last = marks[marks.length - 1];
  last.tagName === 'FIGURE' ? last.querySelector('figcaption').append(pin) : last.after(pin);
  return true;
}
function unpaint(id) {
  document.querySelectorAll(`mark.cmt[data-id="${id}"]`).forEach(m => { const p = m.parentNode; m.replaceWith(...m.childNodes); p.normalize(); });
  document.querySelectorAll(`[data-cmt="${id}"]`).forEach(e => { e.classList.remove('cmt-block'); delete e.dataset.cmt; });
  document.querySelectorAll(`.cmt-pin[data-id="${id}"]`).forEach(p => p.remove());
}
const renumber = () => document.querySelectorAll('.cmt-pin').forEach(p => { const c = comments.find(c => c.id === p.dataset.id); p.textContent = comments.indexOf(c) + 1; p.title = c.text; });

function anchorAll() {
  const { text } = textNodes();
  for (const c of comments) {
    let i = text.indexOf(c.prefix + c.quote + c.suffix);
    i = i >= 0 ? i + c.prefix.length : text.indexOf(c.quote);
    c.orphan = i < 0;
    if (!c.orphan) { c.start = i; c.end = i + c.quote.length; paint(c); }
  }
  store();
}

function place(el, rect) {
  el.hidden = false;
  el.style.left = Math.min(rect.left + scrollX, scrollX + innerWidth - el.offsetWidth - 12) + 'px';
  el.style.top = (rect.bottom + scrollY + 6) + 'px';
}
function openPop(c, rect) {
  closePop();
  openId = c.id;
  document.querySelectorAll(`mark.cmt[data-id="${c.id}"]`).forEach(m => m.classList.add('open'));
  pop.querySelector('.q').textContent = '“' + c.quote + '”';
  area.value = c.text;
  place(pop, rect); area.focus();
}
function closePop() {
  if (!openId) { pop.hidden = true; return; }
  const c = comments.find(c => c.id === openId);
  openId = null; pop.hidden = true;
  if (!c) return;
  const text = area.value.trim();
  if (!text) { remove(c); return; }
  c.text = text; c.updated = new Date().toISOString(); store(); renumber();
  document.querySelectorAll('mark.cmt.open').forEach(m => m.classList.remove('open'));
}
function remove(c) { unpaint(c.id); comments = comments.filter(x => x !== c); store(); renumber(); }

document.addEventListener('mouseup', e => {
  if (pop.contains(e.target) || e.target === addBtn) return;
  setTimeout(() => {
    const sel = getSelection();
    if (sel.isCollapsed || !article.contains(sel.anchorNode)) { addBtn.hidden = true; return; }
    const r = sel.getRangeAt(0), { list, text } = textNodes();
    const start = offsetOf(list, r.startContainer, r.startOffset), end = offsetOf(list, r.endContainer, r.endOffset);
    if (end <= start) { addBtn.hidden = true; return; }
    pending = { start, end, text, section: sectionOf(r.startContainer) };
    const line = [...r.getClientRects()].pop() || r.getBoundingClientRect();
    addBtn.hidden = false;
    addBtn.style.left = Math.min(article.getBoundingClientRect().right + 12, innerWidth - 42) + scrollX + 'px';
    addBtn.style.top = line.top + line.height / 2 - 15 + scrollY + 'px';
  });
});
document.addEventListener('mousedown', e => {
  if (pop.contains(e.target) || e.target === addBtn) return;
  const pin = e.target.closest('.cmt-pin, mark.cmt');
  if (pin) { e.preventDefault(); const c = comments.find(c => c.id === pin.dataset.id); if (openId !== c.id) openPop(c, pin.getBoundingClientRect()); return; }
  closePop(); addBtn.hidden = true;
});
addBtn.addEventListener('click', () => {
  const { start, end, text, section } = pending;
  const c = { id: 'c' + Date.now(), section, quote: text.slice(start, end), prefix: text.slice(Math.max(0, start - 40), start),
    suffix: text.slice(end, end + 40), start, end, text: '', created: new Date().toISOString() };
  comments.push(c); comments.sort((a, b) => a.start - b.start);
  getSelection().removeAllRanges(); addBtn.hidden = true;
  paint(c); renumber();
  openPop(c, document.querySelector(`.cmt-pin[data-id="${c.id}"]`).getBoundingClientRect());
});
pop.addEventListener('click', e => {
  const a = e.target.closest('[data-a]')?.dataset.a;
  if (a === 'save') closePop();
  if (a === 'del') { const c = comments.find(c => c.id === openId); openId = null; pop.hidden = true; remove(c); }
});
area.addEventListener('keydown', e => { if (e.key === 'Enter' && e.ctrlKey) closePop(); if (e.key === 'Escape') closePop(); });

const exportData = () => ({ page: location.pathname.split('/').pop(), exported: new Date().toISOString(),
  comments: comments.map((c, i) => ({ n: i + 1, section: c.section, quote: c.quote, prefix: c.prefix, suffix: c.suffix, comment: c.text, orphan: !!c.orphan })) });
document.getElementById('cmt-save').addEventListener('click', async () => {
  const json = JSON.stringify(exportData(), null, 2), name = 'manuscript2_journal_comments.json';
  if (window.showSaveFilePicker) {
    try {
      const h = await showSaveFilePicker({ suggestedName: name, types: [{ description: 'JSON', accept: { 'application/json': ['.json'] } }] });
      const w = await h.createWritable(); await w.write(json); await w.close(); return;
    } catch (err) { if (err.name === 'AbortError') return; }
  }
  const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(new Blob([json], { type: 'application/json' })), download: name });
  a.click(); URL.revokeObjectURL(a.href);
});
anchorAll();

// ---- version tracking: word-level comparison of any two saved versions
const V = window.MANUSCRIPT_VERSIONS || [];
const bar = document.getElementById('track-bar'), view = document.getElementById('track-view');
const selA = document.getElementById('tr-a'), selB = document.getElementById('tr-b'), trackBtn = document.getElementById('track');
V.forEach((v, i) => { const t = `v${v.v} · ${v.date}${v.note ? ' · ' + v.note : ''}`; selA.add(new Option(t, i)); selB.add(new Option(t, i)); });
selA.value = Math.max(V.length - 2, 0); selB.value = V.length - 1;
const TEXT = new Set(['P', 'H1', 'H2', 'H3', 'LI']);
const blocks = html => {
  const t = document.createElement('template'); t.innerHTML = html; const out = [];
  const walk = el => { for (const c of el.children) ['OL', 'UL', 'SECTION'].includes(c.tagName) ? walk(c) : out.push(c); };
  walk(t.content); return out;
};
const esc = x => x.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
const tokens = el => {
  const out = [];
  const rec = node => { for (const n of node.childNodes) {
    if (n.nodeType === 3) for (const m of n.data.matchAll(/\s*\S+\s*|\s+/g)) out.push({ k: m[0].trim() || ' ', h: esc(m[0]) });
    else if (n.nodeType === 1) ['MATH', 'A', 'SVG'].includes(n.tagName.toUpperCase()) || n.classList.contains('secno') ? out.push({ k: n.outerHTML, h: n.outerHTML }) : rec(n);
  } };
  rec(el); return out;
};
function lcs(ka, kb) {
  const n = ka.length, m = kb.length, L = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = ka[i] === kb[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
  const ops = []; let i = 0, j = 0;
  while (i < n && j < m) {
    if (ka[i] === kb[j]) ops.push({ t: '=', i: i++, j: j++ });
    else if (L[i + 1][j] >= L[i][j + 1]) ops.push({ t: '-', i: i++ });
    else ops.push({ t: '+', j: j++ });
  }
  while (i < n) ops.push({ t: '-', i: i++ });
  while (j < m) ops.push({ t: '+', j: j++ });
  return ops;
}
const words = el => new Set(el.textContent.toLowerCase().match(/\w+/g) || []);
const similar = (x, y) => { const a = words(x), b = words(y); let k = 0; a.forEach(w => b.has(w) && k++); return k / Math.max(a.size, b.size, 1); };
function modified(x, y) {
  const a = tokens(x), b = tokens(y), e = y.cloneNode(false);
  e.innerHTML = lcs(a.map(t => t.k), b.map(t => t.k)).map(o => o.t === '=' ? b[o.j].h : o.t === '-' ? `<del>${a[o.i].h}</del>` : `<ins>${b[o.j].h}</ins>`).join('');
  if (e.querySelector('ins, del')) e.classList.add('tr-mod');
  return [e];
}
const whole = (x, cls) => { const e = x.cloneNode(true); e.classList.add(cls); return e; };
function render() {
  const A = blocks(V[selA.value].html), B = blocks(V[selB.value].html), key = e => e.outerHTML.replace(/\s+/g, ' ');
  const out = []; let dels = [], adds = [];
  const flush = () => {
    const used = new Set(), pair = new Map();
    adds.forEach(y => {
      let best = -1, score = TEXT.has(y.tagName) ? 0.3 : 0.5;
      dels.forEach((x, k) => { if (!used.has(k) && x.tagName === y.tagName) { const q = similar(x, y); if (q > score) { score = q; best = k; } } });
      if (best >= 0) { used.add(best); pair.set(y, dels[best]); }
    });
    dels.forEach((x, k) => used.has(k) || out.push(whole(x, 'tr-del-block')));
    adds.forEach(y => { const x = pair.get(y);
      if (!x) out.push(whole(y, 'tr-ins-block'));
      else if (TEXT.has(y.tagName)) out.push(...modified(x, y));
      else out.push(whole(x, 'tr-del-block'), whole(y, 'tr-ins-block'));
    });
    dels = []; adds = [];
  };
  for (const o of lcs(A.map(key), B.map(key))) {
    if (o.t === '=') { flush(); out.push(B[o.j].cloneNode(true)); }
    else o.t === '-' ? dels.push(A[o.i]) : adds.push(B[o.j]);
  }
  flush();
  view.replaceChildren(...out);
  const n = sel => [...view.querySelectorAll(sel)].reduce((s, e) => s + (e.textContent.match(/\S+/g) || []).length, 0);
  document.getElementById('tr-stat').textContent = `${n('ins, .tr-ins-block')} words added, ${n('del, .tr-del-block')} words deleted`;
}
trackBtn.addEventListener('click', () => {
  const on = bar.hidden;
  bar.hidden = view.hidden = !on; article.hidden = on; trackBtn.classList.toggle('on', on);
  closePop(); addBtn.hidden = true;
  if (on) render();
});
selA.addEventListener('change', render); selB.addEventListener('change', render);
"""

ARTICLE = f"""
<h1>2. Online NCF stability indicator framework for adaptive control</h1>
<p class="meta">Section draft rewritten from manuscript2 for journal submission. Readers are assumed to be familiar with Ref. [<a href="#citation2">2</a>].</p>
{body}
<section class="references" aria-labelledby="refs"><h2 id="refs">References</h2><ol>
{REFS}
</ol></section>
"""

# ---- version store: a new snapshot is appended whenever the article changes
# usage: python build_manuscript2_journal.py "short note about this revision"
HERE = os.path.dirname(OUT)
VERS = os.path.join(HERE, "manuscript2_journal_versions.js")
HEAD = "window.MANUSCRIPT_VERSIONS = "
if os.path.exists(VERS):
    versions = json.loads(open(VERS, encoding="utf-8").read()[len(HEAD):].rstrip().rstrip(";"))
else:
    old = open(os.path.join(HERE, "manuscript2_html.html"), encoding="utf-8").read()
    stamp = datetime.datetime.fromtimestamp(os.path.getmtime(os.path.join(HERE, "manuscript2_html.html")))
    versions = [{"v": 0, "date": stamp.strftime("%Y-%m-%d %H:%M"), "note": "original manuscript2_html",
                 "html": old[old.index("<article>") + 9:old.index("</article>")]}]
if versions[-1]["html"] != ARTICLE:
    versions.append({"v": versions[-1]["v"] + 1, "date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
                     "note": sys.argv[1] if len(sys.argv) > 1 else "", "html": ARTICLE})
    open(VERS, "w", encoding="utf-8").write(HEAD + json.dumps(versions, ensure_ascii=False) + ";\n")
    print("saved version", versions[-1]["v"])

page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Online NCF stability indicator framework for adaptive control — Paper 2 draft</title>
<style>{CSS}</style>
</head>
<body>
<div class="page">
<header class="runhead"><span>Paper 2 · Methodology · Draft for internal review</span><span class="tools">
<button type="button" class="ibtn" id="cmt-save" title="Save comments file" aria-label="Save comments file">{ICONS["save"]}<span class="badge" id="cmt-count" hidden></span></button>
<button type="button" class="ibtn" id="track" title="Compare versions (track changes)" aria-label="Compare versions">{ICONS["track"]}</button>
<button type="button" class="ibtn" id="theme" title="Dark view" aria-label="Toggle dark view">{ICONS["moon"]}</button></span></header>
<div id="track-bar" hidden><label>From <select id="tr-a"></select></label><label>To <select id="tr-b"></select></label><span><ins>added</ins> · <del>deleted</del></span><span id="tr-stat"></span></div>
<div id="track-view" hidden></div>
<article>{ARTICLE}</article>
</div>
<footer class="selection-status" role="status" aria-live="polite">Selected words: <span id="selected-word-count">0</span></footer>
<script src="manuscript2_journal_versions.js"></script>
<script>{JS}</script>
</body>
</html>
"""
open(OUT, "w", encoding="utf-8").write(page)
print(len(EQ), "equations", OUT)
