function value = osi_prctile_finite(x, pct)
%OSI_PRCTILE_FINITE Percentile after removing NaN and Inf values.

x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = prctile(x, pct);
end
end
