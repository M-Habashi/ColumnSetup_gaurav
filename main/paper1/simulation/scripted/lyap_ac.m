function result = lyap_ac(options)
%LYAP_AC Compatibility wrapper for the A/C Habashi Lyapunov command.
%   RESULT = LYAP_AC is equivalent to RESULT = LYAP('A','C').

if nargin < 1
    result = lyap('A', 'C');
else
    result = lyap('A', 'C', options);
end
end
