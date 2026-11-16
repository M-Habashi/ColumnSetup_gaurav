function blk_plot_rths(trial, tend)
%BLK_PLOT_RTHS Plot the three displacement comparisons.

figure('Name', 'Pure MATLAB v-RTHS simulation');
for floorIndex = 1:3
    subplot(3, 1, floorIndex);
    plot(trial.t, trial.Ref_Resp(:, floorIndex), '-', 'LineWidth', 1.5);
    hold on;
    plot(trial.t, trial.Num_resp.Data(:, floorIndex), ':', 'LineWidth', 1.5);
    grid on;
    xlim([0, tend]);
    ylabel(sprintf('x_%d (m)', floorIndex));
end
xlabel('Time (sec)');
legend({'Reference model', 'RTHS simulation'});
end
