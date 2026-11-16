function output = blk_saturation(input, lowerLimit, upperLimit)
%BLK_SATURATION Saturation primitive.

output = min(max(input, lowerLimit), upperLimit);
end
