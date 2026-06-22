function config = official_tls_config
% Official windowed noise-whitened TLS configuration.
config.noise_duration = 2;
config.window_s = 0.1;
config.filter_hz = 30;
config.plot_stride = 64;
config.f_min = 20;
config.q_rel = 1;
config.r_rel = 1;
end
