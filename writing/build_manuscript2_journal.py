import re, json, html, os, sys, datetime
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
    return f'<a href="#eq{EQ[k]}">({EQ[k]})</a>'

def inline(text):
    text = re.sub(r"\$(.+?)\$", lambda m: mml(m.group(1)), text)
    text = re.sub(r"\{eq:([A-Za-z0-9_]+)\}", lambda m: ref(m.group(1)), text)
    return text

def eqs_range(a, b):
    return f'<a href="#eq{EQ[a]}">({EQ[a]})</a>–<a href="#eq{EQ[b]}">({EQ[b]})</a>'

parts = []
P = lambda t: parts.append(f"<p>{inline(t)}</p>")
H2 = lambda num, t, id_: parts.append(f'<h2 id="{id_}"><span class="secno">{num}</span>{t}</h2>')
E = lambda *a: parts.append(eq(*a))
RAW = parts.append

# ---------------------------------------------------------------- content
RAW('<p class="lead">' + inline(
    "The normalized coprime factor online stability indicator (NCF OSI) demonstrated by Gomaa et al. [2] was introduced to "
    "quantify the robustness of the closed-loop system as the plant changes during the experiment. The study showed that stiffness "
    "degradation of the specimen can drive the outer controller loop toward instability through a gain amplification "
    "mechanism. In this study, we extend the analytical study to experimental "
    "implementation, discuss the challenges that arise in the experiment, and propose how to address them. The proposed "
    "framework comprises two parts, an online estimator of the indicator and an adaptive controller that gets updated accordingly. The "
    "indicator is estimated during the experiment from the desired displacement calculated by the numerical substructure "
    "and the measured actuator displacement by combining three estimator branches at each frequency, each weighted by "
    "the confidence in its evidence. The first is direct identification, $b_{\\mathrm{id}}$, which estimates the "
    "closed-loop frequency response of the outer controller loop, from the desired displacement $u(t)$ to the measured "
    "actuator displacement $y(t)$, with the $H_1$ cross-spectral estimator [6]. The second is output-power inference, "
    "$b_{\\mathrm{pow}}$, which can detect amplification of the loop at frequencies that cannot be reliably identified. "
    "This branch compares the output power measured during the experiment against the reference recorded before the "
    "excitation. The third is the prior identification of the initial state, $b_{0}$, which serves as a fallback when "
    "no sufficient information is available. The adaptive controller then utilizes the estimated indicator to scale "
    "the controller output by the adaptive factor $\\lambda$ to keep the loop stable "
    "with an adequate margin as the specimen degrades while retaining as much tracking performance as possible. The "
    "evaluation of the framework is discussed in detail in this section.") + '</p>')

H2("2.1", "Control loop and stability margin", "s1")
P("In the hybrid simulation block diagram shown in Figure 1, the numerical substructure computes the desired displacement $d(t)$ "
  "from the ground acceleration and measured force $f_m(t)$. To compensate for the transfer-system lag and improve tracking, a "
  "phase-lead compensator receives $d(t)$ to produce the reference $u(t)$. The outer controller $C(s)$ takes the "
  "tracking error $u(t)-y(t)$, where $y(t)$ is the measured actuator displacement. Its output is scaled by the adaptive "
  "factor $\\lambda\\in(0,1]$ to produce the command $v(t)$ sent to the plant $H(s,k)$.")
P("The plant comprises the transfer system and the specimen of stiffness $k$. The transfer system includes the "
  "inner-loop controller, servo-valve and actuator. The control–structure interaction between the actuator and specimen is "
  "also included in the transfer-system dynamics. The measured force $f_m(t)$ is fed back to the numerical substructure and "
  "closes the numerical substructure loop, while the measured displacement $y(t)$ provides feedback to the outer controller "
  "and closes the outer controller loop.")
RAW('''<figure id="fig1"><svg role="img" aria-labelledby="f1t f1d" viewBox="0 0 1100 280">
<title id="f1t">Hybrid simulation loop with the NCF OSI framework setup</title>
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
<figcaption><b>Figure 1.</b> Hybrid simulation loop with the NCF OSI framework setup.</figcaption></figure>''')
P("When the specimen degrades, its stiffness decreases and the dynamics of the outer controller loop, from $u(t)$ to "
  "$y(t)$, change [2]. The indicator therefore evaluates this loop. With $H(s,k)=Y(s)/V(s)$, its open-loop and closed-loop transfer "
  "functions are")
E("L", r"L(s,\lambda,k)=\lambda\,C(s)\,H(s,k),", "L(s,λ,k)=λ C(s) H(s,k)")
E("T", r"T(s,\lambda,k)=\frac{Y(s)}{U(s)}=\frac{L(s,\lambda,k)}{1+L(s,\lambda,k)},",
  "T(s,λ,k)=(Y(s))/(U(s))=(L(s,λ,k))/(1+L(s,λ,k))")
P("where $U(s)$ and $Y(s)$ are the Laplace transforms of $u(t)$ and $y(t)$. As in [2], the distance of this loop from "
  "instability is measured by the NCF margin [1]. Unlike [2], which separates the outer controller from the plant, the "
  "whole loop is lumped here into the plant $P=L$ with unit feedback $K=1$. The general definition of the margin then "
  "reduces to")
E("bncf", r"b_{\mathrm{NCF}}(\lambda,k)=\underset{\omega}{\inf}\;\delta\big(L(j\omega,\lambda,k)\big),",
  "b_(\"NCF\") (λ,k)=\"inf\"┬ω  δ(L(jω,λ,k))")
E("delta", r"\delta(L)=\frac{|1+L|}{\sqrt{2\left(1+|L|^{2}\right)}}.",
  "δ(L)=(|1+L|)/(√(2(1+|L|^2)))")
P("The function $\\delta$ is the chordal distance between $L(j\\omega)$ and the critical point $-1$. A small "
  "$\\delta$ at any frequency therefore signals a loop close to instability. All branches of the estimator evaluate a "
  "capped form of this distance,")
E("phi", r"\phi(L)=\min\left\{\delta(L),\,\frac{1}{\sqrt{2}}\right\}.", "ϕ(L)=\"min\"{δ(L),1/√2}")
P("Because $|1+L|^{2}-(1+|L|^{2})=2\\,\\mathrm{Re}\\,L$, the distance exceeds $\\delta(0)=1/\\sqrt{2}$ only where "
  "$\\mathrm{Re}\\,L>0$. Such frequencies lie far from the critical point and say nothing about the margin. The cap "
  "removes their spurious credit and bounds the reported indicator by $1/\\sqrt{2}$.")

H2("2.2", "Short-time spectral estimation", "s2")
P("The margin in {eq:bncf} requires the loop response at each frequency. Because this response changes as the "
  "specimen degrades, it must be obtained from the measured signals while the experiment runs. The estimator "
  "analyses short windows of $u$ and $y$ and updates its estimate every "
  "$\\Delta t=0.125\\,\\mathrm{s}$. Each update uses the most recent $T_w=0.5\\,\\mathrm{s}$ of data, so consecutive "
  "windows overlap by 75%. At $f_s=2048\\,\\mathrm{Hz}$, each window holds $N=f_sT_w=1024$ samples, which gives a bin "
  "spacing of 2 Hz. With $n$ indexing the update and $r=0,\\dots,N-1$ the samples in the window, the Hann-windowed "
  "discrete Fourier transforms are")
E("dft", r"X_n(\omega_m)=\sum_{r=0}^{N-1}w[r]\,x_n[r]\,e^{-j2\pi mr/N},\qquad x\in\{u,y\},",
  "X_n (ω_m)=∑_(r=0)^(N−1)▒〖w[r] x_n [r] e^(−j2πmr/N)〗,  x∈{u,y}")
P("where $w[r]=\\tfrac{1}{2}\\{1-\\cos[2\\pi r/(N-1)]\\}$ and $\\omega_m=2\\pi mf_s/N$. From these transforms, the "
  "instantaneous auto- and cross-spectra are")
E("spec", r"p_{uu,n}=|U_n|^{2},\qquad p_{yy,n}=|Y_n|^{2},\qquad p_{yu,n}=Y_n\,U_n^{*}",
  "p_(uu,n)=|U_n |^2,  p_(yy,n)=|Y_n |^2,  p_(yu,n)=Y_n U_n^*")
P("These spectra are left unnormalized because the normalization cancels in every ratio used below, and the argument "
  "$\\omega_m$ is omitted for brevity. A single window is too noisy to use directly. Each spectrum is therefore smoothed "
  "recursively, following the averaging of modified periodograms [3] with exponential weighting [4], and initialized "
  "by the first complete window:")
E("ewma", r"\bar{p}_{ab,n}(\omega)=(1-\eta_s)\,\bar{p}_{ab,n-1}(\omega)+\eta_s\,p_{ab,n}(\omega),\qquad ab\in\{uu,yy,yu\}.",
  "p̄_(ab,n) (ω)=(1−η_s) p̄_(ab,n−1) (ω)+η_s p_(ab,n) (ω), ab∈{uu,yy,yu}")
P("The analysis is limited to the 2–100 Hz band monitored by the indicator, and the bins affected by line noise are "
  "excluded:")
E("omega", r"\Omega=\left\{\omega_m:\;2\le f_m\le 100\ \mathrm{Hz},\;f_m\notin[58,62]\ \mathrm{Hz}\right\},\qquad f_m=\frac{\omega_m}{2\pi},",
  "Ω={ω_m:2≤f_m≤100 \"Hz\", f_m∉[58,62]\" Hz\"},  f_m=(ω_m)/(2π)")
P("which leaves 47 bins. Hereafter $\\omega\\in\\Omega$, and the subscript $n$ denotes the operating condition "
  "$(\\lambda_n,k_n)$ at update $n$. The current stiffness $k_n$ is unknown and is not estimated.")

H2("2.3", "Direct identification branch", "s3")
P("The loop response can be identified directly from the reference $u$ and the measured response $y$. The averaged "
  "spectra give the $H_1$ estimate of the closed-loop frequency response [6] and the magnitude-squared coherence")
E("that", r"\hat{T}_n(j\omega)=\frac{\bar{p}_{yu,n}(\omega)}{\bar{p}_{uu,n}(\omega)},\qquad \gamma_n^{2}(\omega)=\frac{|\bar{p}_{yu,n}(\omega)|^{2}}{\bar{p}_{uu,n}(\omega)\,\bar{p}_{yy,n}(\omega)}.",
  "T̂_n (jω)=(p̄_(yu,n) (ω))/(p̄_(uu,n) (ω)),  γ_n^2 (ω)=(|p̄_(yu,n) (ω)|^2)/(p̄_(uu,n) (ω) p̄_(yy,n) (ω))")
P("This estimate is unbiased only if the output disturbance is uncorrelated with $u$. In hybrid simulation, this "
  "condition is not guaranteed, because $u$ is computed from the measured force through the numerical substructure. "
  "High coherence is therefore treated as supporting evidence rather than proof of an unbiased estimate [5].")
P("Because this estimate can be poor, each bin receives a confidence between zero and one. The confidence combines "
  "three factors. The first is command activity, detected from the window RMS "
  "$u_{\\mathrm{rms},n}=\\big(N^{-1}\\sum_r u_n[r]^{2}\\big)^{1/2}$:")
E("act", r"A_n=\begin{cases}1, & u_{\mathrm{rms},n}>\eta_A,\\ 0, & \text{otherwise}.\end{cases}",
  "A_n={■(1,&u_(\"rms\",n)>η_A@0,&\"otherwise\")┤")
P("The threshold $\\eta_A$ is approximately $4.54\\,\\sigma_{u,0}$, where $\\sigma_{u,0}$ is the command-noise standard "
  "deviation measured in a quiet record. The second factor is the input leverage. Even within an active window, some "
  "bins carry little command energy, and these bins are discounted through")
E("lev", r"\ell_n(\omega)=\frac{p_{\mathrm{rel},n}(\omega)}{p_{\mathrm{rel},n}(\omega)+p_{\mathrm{floor}}},\qquad p_{\mathrm{rel},n}(\omega)=\frac{\bar{p}_{uu,n}(\omega)}{\max_{\nu\in\mathcal{B}}\bar{p}_{uu,n}(\nu)},",
  "ℓ_n (ω)=(p_(\"rel\",n) (ω))/(p_(\"rel\",n) (ω)+p_(\"floor\") ),  p_(\"rel\",n) (ω)=(p̄_(uu,n) (ω))/(\"max\"┬(ν∈ℬ)  p̄_(uu,n) (ν))")
P("where $\\mathcal{B}$ is the full 2–100 Hz grid. The third factor is the coherence, which completes the confidence")
E("conf", r"c_n(\omega)=A_n\,\gamma_n^{2}(\omega)\,\ell_n(\omega),\qquad 0\le c_n(\omega)\le 1.",
  "c_n (ω)=A_n γ_n^2 (ω) ℓ_n (ω), 0≤c_n (ω)≤1")
P("This confidence is a weighting factor, not a probability. Where it is small, the estimate is replaced by the prior "
  "identification of the initial state, scaled by the current adaptive factor. With "
  "$L_0(j\\omega)=C(j\\omega)H(j\\omega,k_0)$ the full-gain loop identified at the initial stiffness $k_0$, the prior is")
E("prior", r"L_{\mathrm{pr},n}(j\omega)=\lambda_n L_0(j\omega),\qquad T_{\mathrm{pr},n}(j\omega)=\frac{L_{\mathrm{pr},n}(j\omega)}{1+L_{\mathrm{pr},n}(j\omega)}.",
  "L_(\"pr\",n) (jω)=λ_n L_0 (jω),  T_(\"pr\",n) (jω)=(L_(\"pr\",n) (jω))/(1+L_(\"pr\",n) (jω))")
P("Measurement and prior are blended in the closed-loop domain, where the spectral estimate is formed. The loop is then "
  "recovered by inverting {eq:T}:")
E("blend", r"\tilde{T}_n(j\omega)=c_n\,\hat{T}_n(j\omega)+(1-c_n)\,T_{\mathrm{pr},n}(j\omega),\qquad \hat{L}_n(j\omega)=\frac{\tilde{T}_n(j\omega)}{1-\tilde{T}_n(j\omega)}.",
  "T̃_n (jω)=c_n T̂_n (jω)+(1−c_n ) T_(\"pr\",n) (jω),  L̂_n (jω)=(T̃_n (jω))/(1−T̃_n (jω))")
P("As a result, a well-supported measurement governs $\\hat{L}_n$, while a weakly supported one leaves it close to the "
  "prior. Applying the capped distance to both loops gives the identified and prior margin curves")
E("bid", r"b_{\mathrm{id},n}(\omega)=\operatorname{med}_3\left\{\phi\big(\hat{L}_n(j\omega)\big)\right\},\qquad b_{0,n}(\omega)=\phi\big(L_{\mathrm{pr},n}(j\omega)\big),",
  "b_(\"id\",n) (ω)=\"med\"_3 {ϕ(L̂_n (jω))},  b_(0,n) (ω)=ϕ(L_(\"pr\",n) (jω))")
P("where $\\operatorname{med}_3$ is a three-bin moving median over frequency that suppresses isolated spectral outliers.")

H2("2.4", "Output-power inference branch", "s4")
P("Direct identification fails when the command is weak, yet a degrading specimen can still drive the loop toward "
  "instability during such periods. The measured output power offers a second source of evidence, because it reflects "
  "the loop even without strong excitation. This power is compared against a reference taken from the first three "
  "non-overlapping windows, which are assumed to represent the initial loop at full gain. The reference power and the "
  "observed ratio are")
E("qobs", r"p_{yy,0}(\omega)=\underset{h=1,2,3}{\operatorname{median}}\left|Y_h^{(0)}(\omega)\right|^{2},\qquad q_{\mathrm{obs},n}(\omega)=\frac{\bar{p}_{yy,n}(\omega)}{p_{yy,0}(\omega)},",
  "p_(yy,0) (ω)=\"median\"┬(h=1,2,3)  |Y_h^((0)) (ω)|^2,  q_(\"obs\",n) (ω)=(p̄_(yy,n) (ω))/(p_(yy,0) (ω))")
P("where $Y_h^{(0)}$ is the transform of $y$ in reference window $h$. To interpret this ratio, assume that $y$ is "
  "dominated by an equivalent output disturbance and that the spectrum of this disturbance is unchanged from the "
  "reference period. The output is then shaped by the sensitivity $1/(1+L)$, and a candidate loop $\\lambda_n g L_0$ "
  "predicts the ratio")
E("qmod", r"q_{\mathrm{mod},n}(\omega,g)=\left|\frac{1+L_0(j\omega)}{1+\lambda_n g\,L_0(j\omega)}\right|^{2}.",
  "q_(\"mod\",n) (ω,g)=〖|(1+L_0 (jω))/(1+λ_n g L_0 (jω))|〗^2")
P("Here, the positive scalar $g$ is an effective change in loop magnitude, not an estimate of $k$. It is fitted in each "
  "bin by matching the observed and predicted ratios on a logarithmic scale:")
E("gfit", r"g_{\mathrm{fit},n}(\omega)=\underset{g\in\mathcal{G}}{\operatorname{arg\,min}}\;\left|\log\,q_{\mathrm{obs},n}(\omega)-\log\,q_{\mathrm{mod},n}(\omega,g)\right|,",
  "g_(\"fit\",n) (ω)=\"arg min\"┬(g∈𝒢)  |log q_(\"obs\",n) (ω)−log q_(\"mod\",n) (ω,g)|")
P("where $\\mathcal{G}$ holds 25 logarithmically spaced values from 0.5 to 6. Because each bin is fitted independently, "
  "the curve $g(\\omega)$ is an inference model rather than an identified transfer function. A single fit is noisy, and "
  "the excitation may fade after a change is detected. The fitted change is therefore retained in a logarithmic memory "
  "initialized at $\\bar{g}_0=1$:")
E("gmem", r"\log\,\bar{g}_n(\omega)=(1-\eta_g)\log\,\bar{g}_{n-1}(\omega)+\eta_g\log\,g_{\mathrm{tar},n}(\omega).",
  "log ḡ_n (ω)=(1−η_g) log ḡ_(n−1) (ω)+η_g log g_(\"tar\",n) (ω)")
P("While the command is active ($A_n=1$), the target is $g_{\\mathrm{tar},n}=g_{\\mathrm{fit},n}$. The memory releases "
  "a change once the loop recovers, and recovery is detected from the band-median ratio")
E("rband", r"r_{\Omega,n}=\underset{\omega\in\Omega}{\operatorname{median}}q_{\mathrm{obs},n}(\omega).",
  "r_(Ω,n)=\"median\"┬(ω∈Ω)  q_(\"obs\",n) (ω)")
P("When $r_{\\Omega,n}<1$, the output power has fallen below the initial reference. The memory then decays toward "
  "$\\bar{g}=1$, with $g_{\\mathrm{tar},n}=1$ and $\\eta_g$ replaced by $\\eta_r$. Otherwise, $\\bar{g}_n$ is held, so a "
  "detected change remains represented while the excitation is weak. Finally, the output-power margin curve uses the "
  "same capped distance as {eq:bid}:")
E("bres", r"b_{\mathrm{pow},n}(\omega)=\operatorname{med}_3\left\{\phi\big(\lambda_n\bar{g}_n(\omega)L_0(j\omega)\big)\right\}.",
  "b_(\"pow\",n) (ω)=\"med\"_3 {ϕ(λ_n ḡ_n (ω) L_0 (jω))}")

H2("2.5", "Per-frequency fusion and reported indicator", "s5")
P("At each frequency, the three branches now provide three margin estimates, which are combined according to the "
  "evidence behind each. The output-power branch is trusted in proportion to the size of the inferred change,")
E("det", r"d_n(\omega)=\operatorname{clip}_{[0,1]}\left(\frac{\bar{g}_n(\omega)-1}{g_{\mathrm{det}}-1}\right),",
  "d_n (ω)=\"clip\"_([0,1]) ((ḡ_n (ω)−1)/(g_(\"det\")−1))")
P("which rises linearly from zero at $\\bar{g}_n=1$ to one at $\\bar{g}_n=g_{\\mathrm{det}}$. Together with the "
  "confidence $c_n$, this detection weight sets the weights of the three branches at each frequency:")
E("w", r"w_{\mathrm{id},n}=c_n,\qquad w_{\mathrm{pow},n}=(1-c_n)\,d_n,\qquad w_{0,n}=(1-c_n)(1-d_n).",
  "w_(\"id\",n)=c_n,  w_(\"pow\",n)=(1−c_n ) d_n,  w_(0,n)=(1−c_n )(1−d_n )")
P("These weights are nonnegative and sum to one. Direct identification receives the share supported by the measurement. "
  "The output-power branch receives the remainder in proportion to its detection weight, and the prior receives what "
  "neither measurement supports (Table 2). The fused margin curve is therefore")
E("beta", r"\beta_n(\omega)=w_{\mathrm{id},n}\,b_{\mathrm{id},n}(\omega)+w_{\mathrm{pow},n}\,b_{\mathrm{pow},n}(\omega)+w_{0,n}\,b_{0,n}(\omega).",
  "β_n (ω)=w_(\"id\",n) b_(\"id\",n) (ω)+w_(\"pow\",n) b_(\"pow\",n) (ω)+w_(0,n) b_(0,n) (ω)")
P("Fusion is performed bin by bin, before any reduction over frequency, so margins evaluated at different frequencies "
  "are never combined. This choice also handles the idle case without special treatment. When the command is inactive, "
  "$c_n=0$ in every bin. An unchanged loop then reads its gain-scaled prior, and a bin with a remembered change "
  "continues to report it.")
P("To drive the adaptive controller, the fused curve is reduced to a single value. The instantaneous indicator is the "
  "second-smallest value of $\\beta_n$ over $\\Omega$,")
E("binst", r"b_{\mathrm{inst},n}=\beta_{n,(2)}=\beta_n(\omega_{*,n}),", "b_(\"inst\",n)=β_(n,(2))=β_n (ω_(*,n))")
P("where $\\omega_{*,n}$ is the governing frequency. Discarding the lowest bin prevents a single outlier from governing "
  "the estimate, at the cost of attenuating a genuine minimum that is only one bin wide. To suppress fluctuations "
  "between updates, the reported indicator is smoothed in time,")
E("bosi", r"b_{\mathrm{OSI},n}=(1-\eta_b)\,b_{\mathrm{OSI},n-1}+\eta_b\,b_{\mathrm{inst},n},",
  "b_(\"OSI\",n)=(1−η_b) b_(\"OSI\",n−1)+η_b b_(\"inst\",n)")
P("and the adaptive law uses it to update $\\lambda_{n+1}$. Figure 2 summarizes one complete update, from the measured "
  "signals to the adaptive factor, and Table 1 lists the estimator parameters.")

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
P("The estimator relies on four assumptions, and each one limits how the reported indicator should be interpreted.")
RAW('<ol class="assumptions">' + "".join(f"<li>{inline(t)}</li>" for t in [
    "The identification branch assumes that the output disturbance is uncorrelated with $u$. Feedback through the "
    "numerical substructure can violate this assumption and bias $\\hat{T}_n$ even at high coherence [5].",
    "The output-power branch assumes that the disturbance spectrum is unchanged from the reference period and that the "
    "first 1.5 s represent the initial loop at full gain. A change in disturbance intensity or in the command-driven "
    "response can therefore alter $q_{\\mathrm{obs}}$ without any change in stability.",
    "The factor $g$ is real. The output-power branch therefore captures changes in loop magnitude but not in loop phase.",
    "Band limitation, trimming, and temporal smoothing mean that $b_{\\mathrm{OSI}}$ is not a guaranteed lower bound on "
    "the full-frequency margin $b_{\\mathrm{NCF}}$. The reported indicator also follows abrupt changes with a delay set "
    "by $\\eta_b$.",
]) + "</ol>")

REFS = '''<li id="citation1">K. Glover and D. McFarlane, “Robust stabilization of normalized coprime factor plant descriptions with H<sub>∞</sub>-bounded uncertainty,” <i>IEEE Transactions on Automatic Control</i>, vol. 34, no. 8, pp. 821–830, 1989. <a href="https://doi.org/10.1109/9.29424">doi:10.1109/9.29424</a></li>
<li id="citation2">M. Gomaa, E. D. Patino, J. N. Villamizar, J. W. Condori Uribe, and S. J. Dyke, “An online stability indicator for real-time hybrid simulation emphasizing physical substructure degradation,” author manuscript.</li>
<li id="citation3">P. D. Welch, “The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms,” <i>IEEE Transactions on Audio and Electroacoustics</i>, vol. 15, no. 2, pp. 70–73, 1967. <a href="https://doi.org/10.1109/TAU.1967.1161901">doi:10.1109/TAU.1967.1161901</a></li>
<li id="citation4">S. W. Roberts, “Control chart tests based on geometric moving averages,” <i>Technometrics</i>, vol. 1, no. 3, pp. 239–250, 1959. <a href="https://doi.org/10.1080/00401706.1959.10489860">doi:10.1080/00401706.1959.10489860</a></li>
<li id="citation5">U. Forssell and L. Ljung, “Closed-loop identification revisited,” <i>Automatica</i>, vol. 35, no. 7, pp. 1215–1241, 1999. <a href="https://doi.org/10.1016/S0005-1098(99)00022-9">doi:10.1016/S0005-1098(99)00022-9</a></li>
<li id="citation6">J. S. Bendat and A. G. Piersol, <i>Random Data: Analysis and Measurement Procedures</i>, 4th ed., Hoboken, NJ: Wiley, 2010.</li>'''

body = "\n".join(parts)
body = re.sub(r"\[(\d)\]", r'[<a href="#citation\1">\1</a>]', body)

# ---------------------------------------------------------------- page
ARTICLE = f"""
<h1>2. Online NCF stability indicator framework for adaptive control</h1>
<p class="meta">Section draft rewritten from manuscript2 for journal submission. Readers are assumed to be familiar with Ref. [<a href="#citation2">2</a>].</p>
{body}
<section class="references" aria-labelledby="refs"><h2 id="refs">References</h2><ol>
{REFS}
</ol></section>
"""

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
