function sigma = blwnStdFromExceedance(amp, exceed_percentile)
%BLWNSTDFROMEXCEEDANCE Convert two-sided exceedance amplitude to Gaussian std.
sigma = amp/(sqrt(2)*erfcinv(exceed_percentile/100));
end
