function output = blk_sensor_output(input, sensorGain, noise)
%BLK_SENSOR_OUTPUT Sensor Gain and noise Sum blocks.

output = sensorGain * input + noise;
end
