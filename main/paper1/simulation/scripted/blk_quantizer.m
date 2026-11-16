function output = blk_quantizer(input, interval)
%BLK_QUANTIZER Quantizer primitive.

output = interval .* round(input ./ interval);
end
