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
    "The NCF online stability indicator (NCF OSI), proposed by Gomaa et al. {cite:gomaa}, "
    "quantifies the robustness of the closed-loop system as the physical plant changes during the experiment. The study "
    "showed that specimen stiffness degradation can drive the outer controller loop toward instability through a "
    "gain-amplification mechanism. In this study, we extend the analytical results to experimental implementation, "
    "discuss the challenges that arise, and propose ways to address them. The proposed framework comprises two "
    "parts: an online estimator of the indicator and an adaptive controller that gets updated accordingly. The "
    "indicator is estimated during the experiment from the desired displacement calculated by the numerical "
    "substructure and the measured actuator displacement by combining three estimator branches at each frequency, "
    "each weighted by the confidence in its output. The first is direct identification, $b_{\\mathrm{id}}$, which "
    "estimates the closed-loop transfer function of the outer controller loop from the desired displacement $u(t)$ "
    "to the measured actuator displacement $y(t)$, with the $H_1$ cross-spectral estimator {cite:bendat}. The second is "
    "output-power inference, $b_{\\mathrm{pow}}$, which can detect loop amplification at frequencies that cannot "
    "be reliably identified. This branch compares the output power measured during the experiment against the "
    "reference recorded before the excitation. The third is the prior identification of the initial state, $b_{0}$, "
    "which serves as a fallback when insufficient information is available. The adaptive controller then uses the "
    "estimated indicator to scale the controller output by the adaptive factor $\\lambda$, keeping the loop stable "
    "with an adequate margin as the specimen degrades while retaining as much tracking performance as possible. "
    "This section discusses the framework evaluation in detail.") + '</p>')

H2("2.1", "Framework Architecture", "s1")
P("In the hybrid simulation block diagram shown in Figure 1, the numerical substructure computes the desired displacement $d(t)$ "
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
<figcaption><b>Figure 1.</b> Hybrid simulation loop with the NCF OSI framework setup.</figcaption></figure>''')
P('The plant in Figure 1 is characterized by the transfer function $H(s,k)=Y(s)/V(s)$ from the command $v(t)$ '
  'to the measured actuator displacement $y(t)$. The open-loop transfer function and closed-loop response from '
  '$u(t)$ to $y(t)$ are')
E("L", r"L(s,\lambda,k)=\lambda\,C(s)\,H(s,k),", "L(s,λ,k)=λ C(s) H(s,k)")
E("T", r"T(s,\lambda,k)=\frac{Y(s)}{U(s)}=\frac{L(s,\lambda,k)}{1+L(s,\lambda,k)},",
  "T(s,λ,k)=(Y(s))/(U(s))=(L(s,λ,k))/(1+L(s,λ,k))")
P('Here $U(s)$ and $Y(s)$ are the Laplace transforms of $u(t)$ and $y(t)$. The NCF stability margin '
  'of the outer controller loop is evaluated for the loop $L$ under unity feedback {cite:glover}:')
E("bncf", r"b_{\mathrm{NCF}}(L)=\inf_{\omega}\frac{|1+L(j\omega)|}{\sqrt{2\big(1+|L(j\omega)|^{2}\big)}}.",
  "b_(\"NCF\") (L)=\"inf\"┬ω  (|1+L(jω)|)/√(2(1+|L(jω)|^2)).")
P('As the specimen changes during a hybrid simulation, the loop $L(j\\omega)$ changes with it. {eq:bncf} '
  'could be applied directly only if $L(j\\omega)$ were identified with high confidence at every frequency, but '
  'online measurements rarely support this across the full band. The NCF OSI is therefore estimated from three '
  'complementary branches, direct identification $b_{\\mathrm{id}}$, output-power inference $b_{\\mathrm{pow}}$ '
  'and prior identification of the initial state $b_0$, which the following sections develop in turn.')

H2("2.2", "Direct identification branch, " + inline("$b_{\\mathrm{id}}$"), "s2")
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
  'bin $m$. The samples of each window are weighted by the Hann window presented by Blackman and Tukey {cite:blackman}:')
E("hann", r"w[r]=\frac{1}{2}\left[1-\cos\!\left(\frac{2\pi r}{N-1}\right)\right].",
  "w[r]=1/2 [1−cos((2πr)/(N−1))].")
P('Welch {cite:welch} proposed estimating the power spectrum by averaging, with equal weight, the squared Fourier '
  'magnitudes of overlapping windowed segments of a record. Cross spectra are estimated in the same way from products '
  'of paired Fourier transforms, with one transform conjugated. In the present study, the plant changes as the '
  'specimen degrades, so recent windows should carry more weight than earlier ones. Each window therefore provides '
  'one raw estimate of the autospectra of $u$ and $y$ and the cross spectrum of $y$ with $u$:')
E("puu", r"p_{uu,n}(\omega_m)=|U_n(\omega_m)|^{2},", "p_(uu,n) (ω_m)=|U_n (ω_m)|^2,")
E("pyy", r"p_{yy,n}(\omega_m)=|Y_n(\omega_m)|^{2},", "p_(yy,n) (ω_m)=|Y_n (ω_m)|^2,")
E("pyu", r"p_{yu,n}(\omega_m)=Y_n(\omega_m)\,U_n^{*}(\omega_m),", "p_(yu,n) (ω_m)=Y_n (ω_m) U_n^* (ω_m),")
P('where the superscript $*$ denotes the complex conjugate. These raw estimates are averaged with the geometric moving average proposed by Roberts {cite:roberts}, which '
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
  "spectra give the $H_1$ estimate of the closed-loop frequency response {cite:bendat} and the magnitude-squared coherence")
E("that", r"\hat{T}_n(j\omega)=\frac{\bar{p}_{yu,n}(\omega)}{\bar{p}_{uu,n}(\omega)},",
  "T̂_n (jω)=(p̄_(yu,n) (ω))/(p̄_(uu,n) (ω)),")
E("coh", r"\gamma_n^{2}(\omega)=\frac{|\bar{p}_{yu,n}(\omega)|^{2}}{\bar{p}_{uu,n}(\omega)\,\bar{p}_{yy,n}(\omega)}.",
  "γ_n^2 (ω)=(|p̄_(yu,n) (ω)|^2)/(p̄_(uu,n) (ω) p̄_(yy,n) (ω)).")
P("Inverting {eq:T} gives the identified loop:")
E("lhat", r"\hat{L}_n(j\omega)=\frac{\hat{T}_n(j\omega)}{1-\hat{T}_n(j\omega)}.",
  "L̂_n (jω)=(T̂_n (jω))/(1−T̂_n (jω)).")
P("Here, the identified loop is smoothed with the running median over neighbouring frequencies discussed by "
  "Di Matteo et al. {cite:dimatteo}, so the median is taken over each frequency and its two neighbours. The smoothed "
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
E("act", r"A_n=\begin{cases}1, & \sqrt{\dfrac{1}{N}\displaystyle\sum_{r=0}^{N-1}u_n[r]^{2}}>\eta_A\,\sigma_u,\\ 0, & \text{otherwise}.\end{cases}",
  "A_n={■(1,&√(1/N ∑_(r=0)^(N−1)▒〖u_n [r]^2 〗)>η_A σ_u@0,&\"otherwise\")┤")
P("where $\\sigma_u$ is the standard deviation of the command noise measured in a quiet record, and $\\eta_A$ is a "
  "hyperparameter to be tuned. The second factor is the input leverage $\\ell_n$, which reduces "
  "the weight of bins that carry little command energy. The command power in each bin is first normalized by its "
  "maximum over $\\Omega$:")
E("prel", r"\ell_{\mathrm{raw},n}(\omega)=\frac{\bar{p}_{uu,n}(\omega)}{\max_{\nu\in\Omega}\bar{p}_{uu,n}(\nu)}.",
  "ℓ_(\"raw\",n) (ω)=(p̄_(uu,n) (ω))/(\"max\"┬(ν∈Ω)  p̄_(uu,n) (ν)).")
P("To ensure numerical stability for low values of $\\ell_{\\mathrm{raw},n}$, the hyperparameter $\\ell_{\\mathrm{floor}}$ "
  "is introduced in the final expression of the leverage:")
E("lev", r"\ell_n(\omega)=\frac{\ell_{\mathrm{raw},n}(\omega)}{\ell_{\mathrm{raw},n}(\omega)+\ell_{\mathrm{floor}}},",
  "ℓ_n (ω)=(ℓ_(\"raw\",n) (ω))/(ℓ_(\"raw\",n) (ω)+ℓ_(\"floor\") ),")
P("where $\\ell_{\\mathrm{floor}}$ sets the relative power at which a bin receives half weight. Bins well above "
  "$\\ell_{\\mathrm{floor}}$ receive nearly full weight. The third factor is the coherence, which completes the weight")
E("conf", r"w_{\mathrm{id},n}(\omega)=A_n\,\gamma_n^{2}(\omega)\,\ell_n(\omega).",
  "w_(\"id\",n) (ω)=A_n γ_n^2 (ω) ℓ_n (ω).")
P("This weight sets the share of this branch in the fusion of Section 2.4.")

H2("2.3", "Output-power inference branch", "s3")
P("Direct identification fails when the command is weak or does not excite the relevant frequency band. Even then, a "
  "degrading specimen can still drive the system toward instability. However, the change in output power relative to "
  "the initial state can reveal loop amplification even at frequencies without strong excitation. This change therefore "
  "provides a second source of evidence for a reduction in the stability margin. To quantify this change, the averaged "
  "output power is compared with its initial reference:")
E("qobs", r"q_{\mathrm{obs},n}(\omega)=\frac{\bar{p}_{yy,n}(\omega)}{p_{yy,0}(\omega)},",
  "q_(\"obs\",n) (ω)=(p̄_(yy,n) (ω))/(p_(yy,0) (ω)),")
P("where $q_{\\mathrm{obs},n}$ is the observed power ratio, which measures the change in output power at each frequency "
  "relative to the initial state, $\\bar{p}_{yy,n}$ is the averaged autospectrum of $y$ from {eq:ewyy}, and $p_{yy,0}$ is "
  "the reference autospectrum recorded in the initial state before the excitation, with $\\lambda=1$.")
P("According to the observation discussed in Gomaa et al. {cite:gomaa} and the experimental verification presented in "
  "Section xx, the change due to specimen degradation is assumed to be an amplification $g$ of the open-loop gain. "
  "Consequently, a candidate loop $\\lambda_n g L_0$ predicts the ratio")
E("qmod", r"q_{\mathrm{mod},n}(\omega,g)=\left|\frac{1+L_0(j\omega)}{1+\lambda_n g\,L_0(j\omega)}\right|^{2},",
  "q_(\"mod\",n) (ω,g)=〖|(1+L_0 (jω))/(1+λ_n g L_0 (jω))|〗^2,")
P("where $q_{\\mathrm{mod},n}$ is the predicted power ratio, and $L_0(j\\omega)=C(j\\omega)H_0(j\\omega)$ is the loop of "
  "the prior identification of the initial state. The amplification is then selected as the candidate in $\\mathcal{G}$ "
  "that minimizes the logarithmic difference between the observed and predicted ratios:")
E("gfit", r"\hat{g}_n(\omega)=\underset{g\in\mathcal{G}}{\operatorname{arg\,min}}\;\left|\log q_{\mathrm{obs},n}(\omega)-\log q_{\mathrm{mod},n}(\omega,g)\right|,",
  "ĝ_n (ω)=\"arg min\"┬(g∈𝒢)  |log q_(\"obs\",n) (ω)−log q_(\"mod\",n) (ω,g)|,")
P("where $\\hat{g}_n$ is the selected amplification, and $\\mathcal{G}$ is a grid of candidate values of $g$.")
P("The selected amplification at update $n$ inherits the scatter of $q_{\\mathrm{obs},n}$ and therefore varies between "
  "updates. To reduce this scatter while following the degrading specimen, successive selections are averaged "
  "recursively, as for the spectra in Equations ({n:ewuu})–({n:ewyu}), with more weight on recent values. The average is formed on a "
  "logarithmic scale:")
E("gmem", r"\log\hat{g}_{\mathrm{s},n}(\omega)=(1-\eta_g)\log\hat{g}_{\mathrm{s},n-1}(\omega)+\eta_g\log\hat{g}_n(\omega),",
  "log ĝ_(\"s\",n) (ω)=(1−η_g) log ĝ_(\"s\",n−1) (ω)+η_g log ĝ_n (ω),")
P("where $\\hat{g}_{\\mathrm{s},n}$ is the smoothed amplification, and $\\eta_g$ is the averaging factor that weights the "
  "newest selection. {eq:bncf} then gives the margin of this branch:")
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

H2("2.4", "Per-frequency fusion and reported indicator", "s4")
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
  "evaluating the NCF OSI. The adaptive law then uses it to update $\\lambda_{n+1}$. Figure 2 summarizes one complete "
  "update, from the measured signals to the adaptive factor, and Table 1 lists the estimator parameters.")

RAW('''<figure id="fig2"><svg role="img" aria-labelledby="f2t f2d" viewBox="0 0 1000 510">
<title id="f2t">Structure of one estimator update</title>
<desc id="f2d">Windowed displacements u and y feed a windowed FFT that forms the averaged autospectra and cross spectrum. These spectra feed the direct identification and output-power branches. A third branch is the initial-state prior. The adaptive factor lambda feeds all three branches. The three margin curves are fused per frequency bin with the weights w_id, w_pow and w_0, and the minimum of the fused curve over the analysis band gives b_OSI, which drives the adaptive law that returns lambda.</desc>
<defs>
<marker id="a2" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#000"/></marker>
<marker id="a2l" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#AC6420"/></marker>
<marker id="a2y" markerWidth="8" markerHeight="8" refX="9" refY="5" viewBox="0 0 10 10" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#007CA8"/></marker>
</defs>
<g fill="none" stroke="#000" stroke-width="1.5">
<rect x="40" y="175" width="190" height="110" rx="10"/>
<rect x="340" y="30" width="270" height="110" rx="10"/>
<rect x="340" y="175" width="270" height="110" rx="10"/>
<rect x="340" y="320" width="270" height="110" rx="10"/>
<rect x="700" y="175" width="180" height="110" rx="10"/>
<rect x="700" y="320" width="180" height="110" rx="10"/>
<rect x="340" y="455" width="270" height="44" rx="10"/>
<path d="M2 205 H38" marker-end="url(#a2)"/>
<path d="M230 230 H280 V85 H338" marker-end="url(#a2)"/>
<path d="M280 230 H304 A6 6 0 0 1 316 230 H338" marker-end="url(#a2)"/>
<path d="M610 85 H655 V205 H698" marker-end="url(#a2)"/>
<path d="M610 230 H698" marker-end="url(#a2)"/>
<path d="M610 375 H655 V255 H698" marker-end="url(#a2)"/>
<path d="M790 285 V318" marker-end="url(#a2)"/>
<path d="M880 375 H992" marker-end="url(#a2)"/>
<path d="M940 375 V477 H612" marker-end="url(#a2)"/>
</g>
<path d="M2 255 H38" fill="none" stroke="#007CA8" stroke-width="1.5" marker-end="url(#a2y)"/>
<g fill="none" stroke="#AC6420" stroke-width="1.5">
<path d="M340 477 H310 V120"/>
<path d="M310 120 H338" marker-end="url(#a2l)"/>
<path d="M310 265 H338" marker-end="url(#a2l)"/>
<path d="M310 410 H338" marker-end="url(#a2l)"/>
</g>
<circle cx="280" cy="230" r="3.5" fill="#000"/><circle cx="940" cy="375" r="3.5" fill="#000"/>
<circle cx="310" cy="265" r="3" fill="#AC6420"/><circle cx="310" cy="410" r="3" fill="#AC6420"/>
<g text-anchor="middle" dominant-baseline="central" style="fill:#000">
<text x="14" y="190" class="it" style="font-size:22px">u</text>
<text x="14" y="240" class="it" style="font-size:22px;fill:#007CA8">y</text>
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
<text x="475" y="477" style="font-size:20px">Adaptive law</text>
<text x="634" y="70" class="it" style="font-size:18px">w<tspan style="font-size:12px;font-style:normal" dy="5">id</tspan></text>
<text x="640" y="215" class="it" style="font-size:18px">w<tspan style="font-size:12px;font-style:normal" dy="5">pow</tspan></text>
<text x="634" y="360" class="it" style="font-size:18px">w<tspan style="font-size:12px;font-style:normal" dy="5">0</tspan></text>
<text x="960" y="358" class="it" style="font-size:18px">b<tspan style="font-size:12px;font-style:normal" dy="5">OSI</tspan></text>
<text x="294" y="447" class="it" style="font-size:22px;fill:#AC6420">λ</text>
</g></svg>
<figcaption><b>Figure 2.</b> One estimator update. Branch weights from Equations ({n:conf}), ({n:w}) and ({n:w0}) are marked on the arrows entering the fusion block. The minimum of the fused curve over Ω gives <i>b</i><sub>OSI</sub>, and the adaptive factor <i>λ</i> (copper) enters all three branches.</figcaption></figure>''')

def trow(cells, tag="td"):
    return "<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in cells) + "</tr>"

T1 = [
    ("$\\Delta t$", "0.125 s", "—", "Update interval"),
    ("$T_w$, $N$", "0.5 s, 1024", "—", "Window length at $f_s=2048$ Hz"),
    ("$\\Omega$", "2–100 Hz, 47 bins", "—", "Analysis set, 58–62 Hz rejected"),
    ("$\\eta_s$", "0.39", "0.25 s", "Spectral averaging, Equations ({n:ewuu})–({n:ewyu})"),
    ("$\\eta_A$", "4.54", "—", "Activity threshold relative to command noise, {eq:act}"),
    ("$\\ell_{\\mathrm{floor}}$", "$10^{-3}$", "—", "Input-leverage reference, {eq:lev}"),
    ("$\\mathcal{G}$", "0.5–6, 25 values", "—", "Candidate loop-magnitude changes, {eq:gfit}"),
    ("$\\eta_g$", "0.12", "1.0 s", "Output-power memory, accumulation, {eq:gmem}"),
    ("$r_g$", "0.73", "0.4 s", "Recovery factor per update, {eq:gdecay}"),
    ("$g_{\\mathrm{th}}$", "1.75", "—", "Amplification threshold, {eq:det}"),
]
RAW('<figure class="table" id="tab1"><figcaption><b>Table 1.</b> Estimator parameters. Smoothing coefficients follow '
    + inline("$\\eta=1-\\exp(-\\Delta t/\\tau)$") + ' from the listed time constant.</figcaption><table class="border-white/10">'
    + "<thead>" + trow(["Symbol", "Value", "$\\tau$", "Role"], "th") + "</thead><tbody>"
    + "".join(trow(r) for r in T1) + "</tbody></table></figure>")


H2("2.5", "Assumptions and limitations", "s5")
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

REFS = {  # key -> entry. Cite as {cite:key} or {cite:a,b}. Numbers follow first appearance.
    "glover": 'K. Glover and D. McFarlane, “Robust stabilization of normalized coprime factor plant descriptions with H<sub>∞</sub>-bounded uncertainty,” <i>IEEE Transactions on Automatic Control</i>, vol. 34, no. 8, pp. 821–830, 1989. <a href="https://doi.org/10.1109/9.29424">doi:10.1109/9.29424</a>',
    "gomaa": 'M. Gomaa, E. D. Patino, J. N. Villamizar, J. W. Condori Uribe, and S. J. Dyke, “An online stability indicator for real-time hybrid simulation emphasizing physical substructure degradation,” author manuscript.',
    "welch": 'P. D. Welch, “The use of fast Fourier transform for the estimation of power spectra: A method based on time averaging over short, modified periodograms,” <i>IEEE Transactions on Audio and Electroacoustics</i>, vol. 15, no. 2, pp. 70–73, 1967. <a href="https://doi.org/10.1109/TAU.1967.1161901">doi:10.1109/TAU.1967.1161901</a>',
    "roberts": 'S. W. Roberts, “Control chart tests based on geometric moving averages,” <i>Technometrics</i>, vol. 1, no. 3, pp. 239–250, 1959. <a href="https://doi.org/10.1080/00401706.1959.10489860">doi:10.1080/00401706.1959.10489860</a>',
    "bendat": 'J. S. Bendat and A. G. Piersol, <i>Random Data: Analysis and Measurement Procedures</i>, 4th ed., Hoboken, NJ: Wiley, 2010.',
    "blackman": 'R. B. Blackman and J. W. Tukey, “The measurement of power spectra from the point of view of communications engineering — Part I,” <i>The Bell System Technical Journal</i>, vol. 37, no. 1, pp. 185–282, 1958. <a href="https://doi.org/10.1002/j.1538-7305.1958.tb03874.x">doi:10.1002/j.1538-7305.1958.tb03874.x</a>',
    "dimatteo": 'S. Di Matteo, N. M. Viall, and L. Kepko, “Power spectral density background estimate and signal detection via the multitaper method,” <i>Journal of Geophysical Research: Space Physics</i>, vol. 126, no. 2, e2020JA028748, 2021. <a href="https://doi.org/10.1029/2020JA028748">doi:10.1029/2020JA028748</a>',
}

body = "\n".join(parts)

# ---------------------------------------------------------------- page
ARTICLE = f"""
<h1>2. Online NCF stability indicator framework for adaptive control</h1>
<p class="meta">Section draft rewritten from manuscript2 for journal submission. Readers are assumed to be familiar with Ref. {{cite:gomaa}}.</p>
{body}
<section class="references" aria-labelledby="refs"><h2 id="refs">References</h2><ol>
{{REFS}}
</ol></section>
"""
CITED = []
def cite(m):
    for k in m.group(1).split(","):
        if k not in CITED: CITED.append(k)
    return "[" + ", ".join(f'<a class="cite" href="#ref-{k}">{CITED.index(k) + 1}</a>' for k in m.group(1).split(",")) + "]"
ARTICLE = re.sub(r"\{n:(\w+)\}", lambda m: str(EQ[m.group(1)]), ARTICLE)
ARTICLE = re.sub(r"\{cite:([a-z0-9_,]+)\}", cite, ARTICLE)
def scholar(t):  # title links to a Google Scholar search, DOI stays plain text
    t = re.sub(r'<a href="[^"]+">(doi:[^<]+)</a>', r"\1", t)
    m = re.search(r"“(.+?)(,?)”|<i>(.+?)</i>", t)
    title = m.group(1) or m.group(3)
    a = (f'<a href="https://scholar.google.com/scholar?q={quote_plus(re.sub("<[^>]+>", "", title))}" '
         f'target="_blank" rel="noopener">{title}</a>')
    return t.replace(m.group(0), f"“{a}{m.group(2)}”" if m.group(1) else f"<i>{a}</i>", 1)
ARTICLE = ARTICLE.replace("{REFS}", "\n".join(f'<li id="ref-{k}">{scholar(REFS[k])}</li>' for k in CITED))

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
