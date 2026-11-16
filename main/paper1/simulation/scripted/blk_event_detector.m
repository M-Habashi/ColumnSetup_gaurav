function [latched, timestamp] = blk_event_detector( ...
        previousLatch, previousTimestamp, fallingHit, currentTime)
%BLK_EVENT_DETECTOR Hit Crossing, OR latch, and timestamp Unit Delays.

latched = previousLatch || fallingHit;
if fallingHit
    timestamp = currentTime;
else
    timestamp = previousTimestamp;
end
end
