function y = osi_moving_median(x, width)
%OSI_MOVING_MEDIAN NaN-aware moving median for OSI frequency traces.

if width <= 1
    y = x;
else
    y = movmedian(x, width, 'omitnan');
end
end
