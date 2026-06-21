function metric = validation_metrics()
%VALIDATION_METRICS Return handles to the J1-J7 validation metrics.
% Each metric reproduces the definition used in modified BM of V23.
% Units: J1 [ms]; J2-J7 [%]. Compared signal pairs must share one unit.

metric.J1 = @J1_tracking_delay;
metric.J2 = @J2_normalized_tracking_rms;
metric.J3 = @J3_tracking_peak_error;
metric.J4 = @J4_first_floor_normalized_rms;
metric.J5 = @J5_first_floor_peak_error;
metric.J6 = @J6_second_floor_normalized_rms;
metric.J7 = @J7_third_floor_normalized_rms;
end

function value = J1_tracking_delay(measured, commanded, dt)
%J1 Tracking delay from cross-correlation, reported in milliseconds.
% Units: measured/commanded share any unit; dt [s]; output [ms].
% The search covers lags from 0 through 49 samples, as in the source model.
correlation = zeros(50, 1);
for lag = 0:49
    coefficient = corrcoef(measured(1+lag:end), commanded(1:end-lag));
    correlation(lag+1) = coefficient(1, 2);
end
[~, delay_index] = max(correlation);
value = round(10*(delay_index-1)*dt*1000)/10;
end

function value = J2_normalized_tracking_rms(measured, commanded)
%J2 Standard deviation of tracking error normalized by the command [%].
% Units: inputs share any unit; output [%].
value = round(10000*std(measured-commanded)/std(commanded))/100;
end

function value = J3_tracking_peak_error(measured, commanded)
%J3 Peak absolute tracking error normalized by peak command [%].
% Units: inputs share any unit; output [%].
value = round(10000*max(abs(measured-commanded))/max(abs(commanded)))/100;
end

function value = J4_first_floor_normalized_rms(response, reference)
%J4 First-floor displacement error standard deviation, normalized [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*std(response-reference)/std(reference))/100;
end

function value = J5_first_floor_peak_error(response, reference)
%J5 First-floor peak displacement error, normalized by reference peak [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*max(abs(response-reference))/max(abs(reference)))/100;
end

function value = J6_second_floor_normalized_rms(response, reference)
%J6 Second-floor displacement error standard deviation, normalized [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*std(response-reference)/std(reference))/100;
end

function value = J7_third_floor_normalized_rms(response, reference)
%J7 Third-floor displacement error standard deviation, normalized [%].
% Units: inputs share any displacement unit; output [%].
value = round(10000*std(response-reference)/std(reference))/100;
end
