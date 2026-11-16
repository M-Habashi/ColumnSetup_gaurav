function output = blk_chirp_signal(t, initialFrequency, finalFrequency, targetTime)
%BLK_CHIRP_SIGNAL Linear-frequency chirp used by the masked source block.

phase = 2 * pi * initialFrequency .* t + ...
    pi * (finalFrequency - initialFrequency) .* t.^2 / targetTime;
output = 0.5 * sin(phase);
end
