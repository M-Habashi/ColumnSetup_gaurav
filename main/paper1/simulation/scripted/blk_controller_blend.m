function output = blk_controller_blend(controllerA, controllerB, beta)
%BLK_CONTROLLER_BLEND Product/Sum network for the two PI controllers.

output = beta * controllerA + (1 - beta) * controllerB;
end
