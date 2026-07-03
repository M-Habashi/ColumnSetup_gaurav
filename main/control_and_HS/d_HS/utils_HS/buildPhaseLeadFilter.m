function filter = buildPhaseLeadFilter(phase_lead, sample_time)
%BUILDPHASELEADFILTER Build the discrete phase_lead prefilter.
% Input and output are displacement commands in the same units.

phase_lead = normalizePhaseLeadConfig(phase_lead);
if ~phase_lead.enabled
    filter = ss([], [], [], 1, sample_time);
    return
end

continuous_filter = phase_lead.gain ...
    * tf(poly(-phase_lead.zero_rad_s), poly(-phase_lead.pole_rad_s));
for notch_id = 1:size(phase_lead.notch_sections, 1)
    w = 2*pi*phase_lead.notch_sections(notch_id, 1);
    zeta_zero = phase_lead.notch_sections(notch_id, 2);
    zeta_pole = phase_lead.notch_sections(notch_id, 3);
    continuous_filter = continuous_filter ...
        * tf([1, 2*zeta_zero*w, w^2], [1, 2*zeta_pole*w, w^2]);
end
filter = c2d(continuous_filter, sample_time, 'tustin');
end
