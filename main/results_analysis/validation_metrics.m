function metric = validation_metrics()
%VALIDATION_METRICS Return handles to the J1-J7 validation metrics.
% Each metric reproduces the definition used in modified BM of V23.
% Units: J1 [ms]; J2-J7 [%]. Compared signal pairs must share one unit.
% Indicator meanings:
%   J1-J3: measured dm against d_n, the numerical sub control point.
%   J4-J6: x1_n/x2_n/x3_n numerical sub response against x1_r/x2_r/x3_r.
%   J7: measured dm against d_r, the full FEM control point, reported as NMSE.

metric.J1 = @J1_tracking_delay;
metric.J2 = @J2_normalized_tracking_rms;
metric.J3 = @J3_tracking_peak_error;
metric.J4 = @J4_first_floor_normalized_rms;
metric.J5 = @J5_second_floor_normalized_rms;
metric.J6 = @J6_third_floor_normalized_rms;
metric.J7 = @J7_control_point_nmse;
end

function value = J1_tracking_delay(dm, d_n, dt)
%J1 Tracking delay between dm and d_n from finddelay [ms].
% Units: dm/d_n share any unit; dt [s]; output [ms].
delay_samples = finddelay(d_n(:), dm(:));
value = round(10*delay_samples*dt*1000)/10;
end

function value = J2_normalized_tracking_rms(dm, d_n)
%J2 100*std(dm - d_n)/std(d_n) [%].
% Units: inputs share any unit; output [%].
value = round(10000*std(dm-d_n)/std(d_n))/100;
end

function value = J3_tracking_peak_error(dm, d_n)
%J3 100*max(abs(dm - d_n))/max(abs(d_n)) [%].
% Units: inputs share any unit; output [%].
value = round(10000*max(abs(dm-d_n))/max(abs(d_n)))/100;
end

function value = J4_first_floor_normalized_rms(x1_n, x1_r)
%J4 100*std(x1_n - x1_r)/std(x1_r) [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*std(x1_n-x1_r)/std(x1_r))/100;
end

function value = J5_second_floor_normalized_rms(x2_n, x2_r)
%J5 100*std(x2_n - x2_r)/std(x2_r) [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*std(x2_n-x2_r)/std(x2_r))/100;
end

function value = J6_third_floor_normalized_rms(x3_n, x3_r)
%J6 100*std(x3_n - x3_r)/std(x3_r) [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*std(x3_n-x3_r)/std(x3_r))/100;
end

function value = J7_control_point_nmse(dm, d_r)
%J7 100*mean((dm - d_r)^2)/mean(d_r^2) [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*mean((dm-d_r).^2)/mean(d_r.^2))/100;
end
