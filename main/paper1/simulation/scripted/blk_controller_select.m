function output = blk_controller_select(controllerA, controllerB, ...
        controllerC, beta, startC)
%BLK_CONTROLLER_SELECT Select C directly or use the A/B blend path.

if strcmpi(startC, 'C')
    output = controllerC;
else
    output = blk_controller_blend(controllerA, controllerB, beta);
end
end
