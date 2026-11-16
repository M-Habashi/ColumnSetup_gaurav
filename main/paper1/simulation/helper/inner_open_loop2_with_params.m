function  [sys, a1, b1, b2, a2, a3] = inner_open_loop2_with_params(m ,c, k)
% Original 2nd-order servo:
%   Gs(s) = a1 / (s^2 + b1*s + b2), with a1 = a1*beta0 (combined)
% CSI feedback H(s)=a2*s, actuator 1/(s+a3), structure 1/(m s^2 + c s + k)

    % ----- Parameters from your table -----
    a1 = 2.1283e+13; %2.1283e+13;   % m·Pa/s  (a1*beta0)
    a2 = 4.2297e+06;    % m·Pa
    a3 = 3.3;       % 1/s
    b1 = 425;       % 1/s (β1)
    b2 = 9.9976e+04;      % 1/s (β2) == 1.0e5

    s = tf('s');

    % Numerator
    numerator = a1;

    % Denominator (fully expanded)
    d5 = m;
    d4 = c + m*(a3 + b1);
    d3 = k + (a3 + b1)*c + a2 + m*(b1*a3 + b2);
    d2 = k*(a3 + b1) + c*(b1*a3 + b2) + b1*a2 + b2*a3*m;
    d1 = k*(b1*a3 + b2) + b2*a3*c + b2*a2;
    d0 = b2*a3*k;

    denominator = d5*s^5 + d4*s^4 + d3*s^3 + d2*s^2 + d1*s + d0;

    % Transfer function
    sys = numerator / denominator;
end
