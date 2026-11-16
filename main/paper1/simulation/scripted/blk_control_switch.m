function output = blk_control_switch(original, blended, modified)
%BLK_CONTROL_SWITCH Select original or modified controller output.

if -modified >= 0
    output = original;
else
    output = blended;
end
end
