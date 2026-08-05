function result = plant_family
%PLANT_FAMILY One-parameter degradation family between the 7k and 5k plants.
%
% theta = 0 is the identified 7k actuator/specimen system, theta = 1 is the
% identified 5k system. Because both models share the normalized
% controllable-companion coordinates of build_lqr_state_space_models, the
% numerator/denominator coefficient interpolation is exactly an affine
% interpolation of the (A, C) matrices; B is constant. The family is
% validated by dense-grid pole stability and by comparing the interpolated
% frequency responses against the two identified endpoints.

assets = kimi_assets;
models = load(assets.models, 'result');
models = models.result;
sys7 = models.system_7k;
sys5 = models.system_5k;
frequencyScale = models.frequency_scale_rad_per_second;

A0 = sys7.A; A1 = sys5.A;
C0 = sys7.C; C1 = sys5.C;
B = sys7.B;
assert(max(abs(B - sys5.B)) < 1e-12, 'B matrices differ');
dA = A1 - A0;
dC = C1 - C0;

theta = linspace(0, 1, 101).';
stable = false(size(theta));
maxRealPole = zeros(size(theta));
familyError = zeros(size(theta));
frequencyHz = linspace(0.1, 100, 1000).';
for i = 1:numel(theta)
    At = A0 + theta(i)*dA;
    Ct = C0 + theta(i)*dC;
    physical = ss(frequencyScale*At, frequencyScale*B, Ct, 0);
    poles = eig(At);
    maxRealPole(i) = max(real(poles))*frequencyScale;
    stable(i) = maxRealPole(i) < 0;
    if i > 1 && i < numel(theta)
        response = squeeze(freqresp(physical, 2*pi*frequencyHz));
        r0 = squeeze(freqresp(sys7.physical_state_space, 2*pi*frequencyHz));
        r1 = squeeze(freqresp(sys5.physical_state_space, 2*pi*frequencyHz));
        bracket = max(abs(r0), abs(r1));
        familyError(i) = max(abs(abs(response) - ...
            ((1-theta(i))*abs(r0) + theta(i)*abs(r1))) ./ bracket);
    end
end

result = struct;
result.theta = theta;
result.A0 = A0; result.dA = dA;
result.B = B;
result.C0 = C0; result.dC = dC;
result.frequency_scale = frequencyScale;
result.all_stable = all(stable);
result.max_real_pole_rad_s = maxRealPole;
result.worst_interpolation_error = max(familyError);
result.family_at = @(theta) deal(A0 + theta*dA, B, C0 + theta*dC);

outputFile = fullfile(assets.results, 'plant_family.mat');
save(outputFile, 'result')
fprintf('Family stable on dense grid: %d (worst pole %.6g rad/s)\n', ...
    result.all_stable, max(maxRealPole))
fprintf('Worst midpoint magnitude interpolation deviation: %.6g\n', ...
    result.worst_interpolation_error)
fprintf('Saved plant family to %s\n', outputFile)
end
