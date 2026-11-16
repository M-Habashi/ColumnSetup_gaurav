function margin = blk_indicator_margin(alpha, beta, p, useC)
%BLK_INDICATOR_MARGIN Pure-numeric normalized coprime-factor margin block.

if nargin < 4
    useC = false;
end

persistent frequency s
if isempty(frequency)
    frequency = logspace(-1, 4, 10000);
    s = 1i * frequency;
end

stiffness = alpha * p.k_e;
damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
a1 = 2.1283e13;
a2 = 4.2297e6;
a3 = 3.3;
b1 = 425;
b2 = 9.9976e4;

denominator = p.m_e .* s.^5 + ...
    (damping + p.m_e * (a3 + b1)) .* s.^4 + ...
    (stiffness + (a3 + b1) * damping + a2 + ...
        p.m_e * (b1 * a3 + b2)) .* s.^3 + ...
    (stiffness * (a3 + b1) + damping * (b1 * a3 + b2) + ...
        b1 * a2 + b2 * a3 * p.m_e) .* s.^2 + ...
    (stiffness * (b1 * a3 + b2) + b2 * a3 * damping + ...
        b2 * a2) .* s + b2 * a3 * stiffness;
plant = a1 ./ (denominator + a1);

if useC
    kp = p.pi_c_kp;
    ki = p.pi_c_ki;
else
    kp = beta * p.pi_a_kp + (1 - beta) * p.pi_b_kp;
    ki = beta * p.pi_a_ki + (1 - beta) * p.pi_b_ki;
end
controller = kp + ki ./ s;
sigma = (sqrt(abs(plant).^2 + 1) .* sqrt(abs(controller).^2 + 1)) ...
    ./ abs(1 + plant .* controller);
margin = 1 / max(sigma);
end
