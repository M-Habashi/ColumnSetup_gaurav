function noise = blk_sensor_noise(sampleCount, seed, covariance, sampleTime)
%BLK_SENSOR_NOISE Match the Simulink Random Number block's legacy stream.

savedRng = rng;
randn('seed', seed); %#ok<RAND>
standardNoise = randn(sampleCount, 1);
rng('default');
rng(savedRng);
noise = sqrt(covariance) / sqrt(sampleTime) * standardNoise;
end
