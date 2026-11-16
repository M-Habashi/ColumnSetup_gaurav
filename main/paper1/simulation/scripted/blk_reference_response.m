function response = blk_reference_response(referenceSystem, ground, t)
%BLK_REFERENCE_RESPONSE Match F3's post-simulation lsim call.

response = lsim(referenceSystem, ground, t);
end
