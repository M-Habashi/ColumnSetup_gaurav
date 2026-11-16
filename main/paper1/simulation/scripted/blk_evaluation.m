function metrics = blk_evaluation(trial, dt)
%BLK_EVALUATION Evaluate the nine benchmark measures.

xMeasured = trial.X_m.Data;
numerical = trial.Num_resp.Data;
reference = trial.Ref_Resp;
% Paper Eq. (12): arg max_k sum_i y_n(i)*x_m(i-k). Retain the
% benchmark's 0:49-sample nonnegative delay-search window.
lags = 0:49;
correlation = zeros(size(lags));
for lagIndex = 1:numel(lags)
    lag = lags(lagIndex);
    correlation(lagIndex) = sum(numerical(1+lag:end, 1) .* ...
        xMeasured(1:end-lag, 1));
end
[~, delayIndex] = max(correlation);
delays = lags * dt;

metrics = zeros(1, 9);
metrics(1) = round(10000 * delays(delayIndex)) / 10;
metrics(2) = round(10000 * norm(xMeasured(:, 1) - numerical(:, 1)) ...
    / norm(numerical(:, 1))) / 100;
metrics(3) = round(10000 * max(abs(xMeasured(:, 1) - numerical(:, 1))) ...
    / max(abs(numerical(:, 1)))) / 100;
metrics(4) = round(10000 * norm(xMeasured(:, 1) - reference(:, 1)) ...
    / norm(reference(:, 1))) / 100;
metrics(5) = round(10000 * norm(numerical(:, 2) - reference(:, 2)) ...
    / norm(reference(:, 2))) / 100;
metrics(6) = round(10000 * norm(numerical(:, 3) - reference(:, 3)) ...
    / norm(reference(:, 3))) / 100;
metrics(7) = round(10000 * max(abs(xMeasured(:, 1) - reference(:, 1))) ...
    / max(abs(reference(:, 1)))) / 100;
metrics(8) = round(10000 * max(abs(numerical(:, 2) - reference(:, 2))) ...
    / max(abs(reference(:, 2)))) / 100;
metrics(9) = round(10000 * max(abs(numerical(:, 3) - reference(:, 3))) ...
    / max(abs(reference(:, 3)))) / 100;
end
