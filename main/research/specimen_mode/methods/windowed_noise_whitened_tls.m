function result = windowed_noise_whitened_tls(t, a, v, x, F, noise_scale, config)
% Dense whitened TLS with approximately non-overlapping KF assimilation.
n_window = round(config.window_s/(t(2) - t(1)));
sample_idx = n_window:config.plot_stride:numel(t);
n = numel(sample_idx);

theta_raw = nan(n, 3);
theta_kf = nan(n, 3);
accepted = false(n, 1);
initialized = false;
last_update = -inf;

for i = 1:n
    i2 = sample_idx(i);
    idx = (i2 - n_window + 1):i2;
    if rms(F(idx) - mean(F(idx))) > config.f_min
        estimate = noise_whitened_tls(a(idx), v(idx), x(idx), F(idx), noise_scale);
        if all(isfinite(estimate)) && estimate(1) > 0 && estimate(3) > 0
            theta_raw(i, :) = estimate';
        end
    end

    if i2 - last_update >= n_window && all(isfinite(theta_raw(i, :)))
        estimate = theta_raw(i, :)';
        if ~initialized
            theta = estimate;
            parameter_scale = abs(theta);
            P = diag((config.r_rel*parameter_scale).^2);
            Q = diag((config.q_rel*parameter_scale).^2);
            R = diag((config.r_rel*parameter_scale).^2);
            initialized = true;
        else
            P = P + Q*config.window_s;
            K = P/(P + R);
            theta = theta + K*(estimate - theta);
            P = (eye(3) - K)*P;
        end
        last_update = i2;
        accepted(i) = true;
    end

    if initialized
        theta_kf(i, :) = theta';
    end
end

result.t = t(sample_idx);
result.theta_raw = theta_raw;
result.theta_kf = theta_kf;
result.accepted = accepted;
end
