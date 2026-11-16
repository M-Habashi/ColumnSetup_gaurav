function output = blk_da_converter(input, p)
%BLK_DA_CONVERTER D/A block: quantization followed by saturation.

quantized = blk_quantizer(input, p.quantize_int);
output = blk_saturation(quantized, p.sat_limit_lower, p.sat_limit_upper);
end
