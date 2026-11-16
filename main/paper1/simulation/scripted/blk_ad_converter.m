function output = blk_ad_converter(input, p)
%BLK_AD_CONVERTER A/D block: saturation followed by quantization.

saturated = blk_saturation(input, p.sat_limit_lower, p.sat_limit_upper);
output = blk_quantizer(saturated, p.quantize_int);
end
