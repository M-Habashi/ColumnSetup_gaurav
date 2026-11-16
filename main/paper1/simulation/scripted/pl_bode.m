function pl_bode
%PL_BODE Plot the phase-lead compensator Bode response.
%   With the "scripted" folder on the MATLAB path, run this figure with:
%       pl_bode
%   The horizontal axis is frequency in Hz.

modified = 1;             % 1 = modified phase-lead compensator
frequencyHz = logspace(-1, 2, 3000);

if modified == 1
    phaseLead = tf(31.6431547 * [1 49.3502225], [1 1657.846121]);
    phaseLeadName = 'Modified phase-lead compensator';
else
    phaseLead = tf(50.8316336027 * [1 168.6036181018], ...
        [1 8570.3973394443]);
    phaseLeadName = 'Original phase-lead compensator';
end

omega = 2 * pi * frequencyHz;
response = squeeze(freqresp(phaseLead, omega));

figure('Name', 'Phase-lead Bode response', 'Color', 'w');

subplot(2, 1, 1);
semilogx(frequencyHz, 20 * log10(abs(response)), 'LineWidth', 2, ...
    'Color', '#01746F');
grid on; box on;
ylabel('Magnitude [dB]');
title('Phase-lead compensator Bode response');
legend(phaseLeadName, 'Location', 'best');

subplot(2, 1, 2);
semilogx(frequencyHz, unwrap(angle(response)) * 180 / pi, ...
    'LineWidth', 2, 'Color', '#01746F');
grid on; box on;
xlabel('Frequency [Hz]');
ylabel('Phase [deg]');
end
