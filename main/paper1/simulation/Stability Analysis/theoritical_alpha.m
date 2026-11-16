%% Alpha theoretical solution — with term-by-term plotting
% Requires: analog_cntrlr (Ca), digital_cntrlr (Cd), mp, cp, kp, zeta

%% Verifying expanded system (your original definitions)
a1 = 2.1283e+13;   % m·Pa/s  (a1*beta0)
a2 = 4.2297e+06;   % m·Pa
a3 = 3.3;          % 1/s
b1 = 425;          % 1/s (β1)
b2 = 9.9976e+04;   % 1/s (β2) ~ 1.0e5

s  = tf('s');
Ga1 = a1/(s^2 + b1*s + b2);
Ga2 = a2*s;
Ga3 = 1/(s + a3);

Ca = analog_cntrlr;
Cd = digital_cntrlr;
Gs = 1/(mp*s^2 + cp*s + kp);

Hye1 = (Ca * Ga1 * Gs * Ga3) / (1 + Gs * Ga3 * Ga2);
Hyc  = Hye1 / (1 + Hye1);  % compare to analog_cl

%% 2) Critical frequency (w_cr) and alpha (alpha_crit)
% Y(s) exactly as in your code:
Y = Ga3 * (Ga2 + Ca*Ga1*(Cd + 1));

% Define the 3 terms so that eqn = term1 + term2 + term3  (|Y|, angle(Y))
% term1(w) =  (mp*w^2)/kp
% term2(w) = -( |Y(jw)| * cos(angle(Y(jw))) ) / kp
% term3(w) = -( |Y(jw)|^2 * sin(angle(Y(jw)))^2 ) / (4*zeta^2*w^2*mp*kp)
term1 = @(w) (mp.*w.^2) ./ kp;
term2 = @(w) -(abs(squeeze(freqresp(Y,w))) .* cos(angle(squeeze(freqresp(Y,w)))))./kp;
term3 = @(w) -(abs(squeeze(freqresp(Y,w))).^2 .* (sin(angle(squeeze(freqresp(Y,w)))).^2)) ./ (4 .* zeta.^2 .* w.^2 .* mp .* kp);

% Summation equals your equation:
eqn  = @(w) term1(w) + term2(w) + term3(w);

% Find the root near your previous initial guess
initial_guess = 282.2;
w_cr = fzero(eqn, initial_guess);
fprintf('\nFound critical frequency: w_crit = %.4f rad/s\n', w_cr);

% Plot eqn(w) and each term over a frequency range
w_range = linspace(10, 1000, 1000).';   % column vector for consistent sizing

% Evaluate Y(jw) once for the vectorized plots (for speed & stability)
Hw = squeeze(freqresp(Y, w_range));  % 1x1xN -> N
Hw = Hw(:);                          % ensure Nx1
ReY = real(Hw);
ImY = imag(Hw);

% Vectorized term values (magnitude/phase using Re/Im identities)
term1_vec = (mp .* w_range.^2) ./ kp;
term2_vec = -(sqrt(ReY.^2 + ImY.^2) .* (ReY ./ sqrt(ReY.^2 + ImY.^2))) ./ kp;  % = -( |Y| cosθ )/kp
term3_vec = -((ReY.^2 + ImY.^2) .* ((ImY ./ sqrt(ReY.^2 + ImY.^2)).^2)) ./ (4 .* zeta.^2 .* w_range.^2 .* mp .* kp); % = -( |Y|^2 sin^2θ )/(...)
eqn_vec   = term1_vec + term2_vec + term3_vec;

% Plot
figure; 
plot(w_range, eqn_vec, 'LineWidth', 1.6); hold on; grid on; grid minor;
plot(w_range, term1_vec, 'LineWidth', 1.2);
plot(w_range, term2_vec, 'LineWidth', 1.2);
plot(w_range, term3_vec, 'LineWidth', 1.2);

% (Optional) Mark the zero-crossing if it lies in-range
if w_cr >= min(w_range) && w_cr <= max(w_range)
    yline(0, '--', 'HandleVisibility', 'off');
    xline(w_cr, ':', sprintf('\\omega_{crit}=%.2f', w_cr), ...
        'LabelOrientation','horizontal','LabelVerticalAlignment','middle');
end

title('Equation and Its Constituent Terms vs Frequency');
xlabel('Frequency \omega (rad/s)');
ylabel('Value');
legend({'eqn','term1','term2','term3'}, 'Location','best');
hold off;

% Compute alpha at w_cr (as in your code)
Y_wcr = freqresp(Y, w_cr);
alpha = (imag(Y_wcr))^2 / (4*zeta^2*w_cr^2*mp*kp);
fprintf('Calculated alpha_cr = %.4f\n\n', alpha);

%% (Optional) Your earlier verification
L = Cd * Hyc; % healthy loop
poles_healthy = pole(feedback(L,1));
% keep a subset if you need the same indices:
keep_idx = [4,5,10,12,13,17];
keep_idx = keep_idx(keep_idx<=numel(poles_healthy));   % guard if lengths differ
poles_healthy = poles_healthy(keep_idx);
poles_eq = pole(feedback(Gs*Y,1));
% Display differences (sizes may differ if models differ)
try
    disp('poles_healthy - poles_eq (size permitting):');
    disp(poles_healthy - poles_eq(1:numel(poles_healthy)));
catch
    disp('Note: pole vector sizes differ; skipping direct subtraction.');
end

% quick check Y(j*omega_cr)
evalfr(Y, 1j*w_cr);

%% (Optional) Store results in arrays if you are batching cases
ii = 1;
mi(ii)      = mp; %#ok<SAGROW>
ki(ii)      = kp; %#ok<SAGROW>
Yi(ii)      = Y;  %#ok<SAGROW>
Gsi(ii)     = Gs; %#ok<SAGROW>
Y_wcri(ii)  = Y_wcr; %#ok<SAGROW>
Li(ii)      = L;  %#ok<SAGROW>
w_cri(ii)   = w_cr; %#ok<SAGROW>
alphai(ii)  = alpha; %#ok<SAGROW>
