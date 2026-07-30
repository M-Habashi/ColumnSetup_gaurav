function [m_hat, c_hat, k_hat, status] = online_tse_estimator_runtime(dm_m, fm)
%ONLINE_TSE_ESTIMATOR_RUNTIME Causal noise-whitened TLS specimen estimator.
% Units: dm_m [m], fm [N], m_hat [kg], c_hat [N*s/m], k_hat [N/m].
% Status: 0 noise acquisition, 1 rejected TLS, 2 hold/overlap, 3 KF update.
%#codegen

persistent x_state force_state x_offset force_offset x_prev v_prev
persistent noise_count noise_sum noise_sum_sq noise_scale
persistent buffer buffer_index buffer_count candidate_countdown
persistent data_count last_update theta_state P Q R initialized

dt = 1/2048;
window_samples = 205;
noise_samples = 4097;

if isempty(initialized)
    x_state = zeros(2, 1);
    force_state = zeros(2, 1);
    x_offset = dm_m;
    force_offset = fm;
    x_prev = dm_m;
    v_prev = 0;
    noise_count = 0;
    noise_sum = zeros(1, 4);
    noise_sum_sq = zeros(1, 4);
    noise_scale = ones(1, 4);
    buffer = zeros(205, 4);
    buffer_index = 1;
    buffer_count = 0;
    candidate_countdown = window_samples;
    data_count = 0;
    last_update = -window_samples;
    theta_state = [NaN; NaN; NaN];
    P = zeros(3, 3);
    Q = zeros(3, 3);
    R = zeros(3, 3);
    initialized = false;
end

% Causal second-order 30 Hz Butterworth filter at 2048 Hz.
b0 = 0.0019871490495440292;
b1 = 0.0039742980990880583;
b2 = 0.0019871490495440292;
a1 = -1.8700042856615608;
a2 = 0.87795288185973697;

u = dm_m - x_offset;
y = b0*u + x_state(1);
x_state(1) = b1*u - a1*y + x_state(2);
x_state(2) = b2*u - a2*y;
x_filtered = y + x_offset;

u = fm - force_offset;
y = b0*u + force_state(1);
force_state(1) = b1*u - a1*y + force_state(2);
force_state(2) = b2*u - a2*y;
force_filtered = y + force_offset;

v = (x_filtered - x_prev)/dt;
a = (v - v_prev)/dt;
x_prev = x_filtered;
v_prev = v;
z = [a, v, x_filtered, force_filtered];

if noise_count < noise_samples
    noise_count = noise_count + 1;
    noise_sum = noise_sum + z;
    noise_sum_sq = noise_sum_sq + z.^2;
    if noise_count == noise_samples
        variance = (noise_sum_sq - noise_sum.^2/noise_samples)/(noise_samples - 1);
        noise_scale = sqrt(max(variance, 0));
        noise_scale(noise_scale == 0) = 1;
    end
    m_hat = NaN;
    c_hat = NaN;
    k_hat = NaN;
    status = 0;
    return
end

buffer(buffer_index, :) = z;
buffer_index = buffer_index + 1;
if buffer_index > window_samples
    buffer_index = 1;
end
buffer_count = min(buffer_count + 1, window_samples);
data_count = data_count + 1;
candidate_countdown = candidate_countdown - 1;
status = 2;

if buffer_count == window_samples && candidate_countdown == 0
    candidate_countdown = 64;
    column_mean = mean(buffer, 1);
    centered = zeros(205, 4);
    whitened = zeros(205, 4);
    for column = 1:4
        centered(:, column) = buffer(:, column) - column_mean(column);
        whitened(:, column) = centered(:, column)/noise_scale(column);
    end
    force_rms = sqrt(mean(centered(:, 4).^2));
    if force_rms <= 20
        status = 1;
    else
        [unused_u, unused_s, right_vectors] = svd(whitened, 0); %#ok<ASGLU>
        q = right_vectors(:, 4)./noise_scale';
        theta_tls = -q(1:3)/q(4);

        if all(isfinite(theta_tls)) && theta_tls(1) > 0 && theta_tls(3) > 0
            if ~initialized
                theta_state = theta_tls;
                parameter_scale = abs(theta_state);
                P = diag(parameter_scale.^2);
                Q = diag(parameter_scale.^2);
                R = diag(parameter_scale.^2);
                initialized = true;
                last_update = data_count;
                status = 3;
            elseif data_count - last_update >= window_samples
                P = P + Q*0.1;
                gain = P/(P + R);
                theta_state = theta_state + gain*(theta_tls - theta_state);
                P = (eye(3) - gain)*P;
                last_update = data_count;
                status = 3;
            end
        else
            status = 1;
        end
    end
end

m_hat = theta_state(1);
c_hat = theta_state(2);
k_hat = theta_state(3);
end
