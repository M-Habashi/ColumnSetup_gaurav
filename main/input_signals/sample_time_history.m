% Five-second triangle command for the Signal Generation time-history mode.
% Columns are [time_s dd_mm].
% Units: input dt is s; output time_history columns are [s, mm].

time_history = [
    0.5  2
    1.0  0
    1.5  2
    2.0  0
    2.5  2
    3.0  0
    3.5  2
    4.0  0
    4.5  2
];

time_history(:, 1) = time_history(:, 1) + dt;
time_history = [0 0; time_history; time_history(end, 1)+dt 0];
