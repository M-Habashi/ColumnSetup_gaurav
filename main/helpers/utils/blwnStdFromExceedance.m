function sigma = blwnStdFromExceedance(amp, exceed_percentile)
%BLWNSTDFROMEXCEEDANCE Convert two-sided exceedance amplitude to Gaussian std.
% Used by the Band-Limited White Noise block in model_ColumnSetup_00.slx.
% Units: amp and sigma use the same signal unit; exceed_percentile is percent.
sigma = amp/(sqrt(2)*erfcinv(exceed_percentile/100));
end
