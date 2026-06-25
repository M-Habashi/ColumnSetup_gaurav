function filter = buildPhaseLeadFilter(phase_lead, sample_time)
%BUILDPHASELEADFILTER Build the discrete phase-lead prefilter.
% Input and output are displacement commands in the same units.

phase_lead = normalizePhaseLeadConfig(phase_lead);
if ~phase_lead.enabled
    filter = ss([], [], [], 1, sample_time);
    return
end

continuous_filter = phase_lead.gain ...
    * tf([1 phase_lead.zero_rad_s], [1 phase_lead.pole_rad_s]);
filter = c2d(continuous_filter, sample_time, 'tustin');
end
