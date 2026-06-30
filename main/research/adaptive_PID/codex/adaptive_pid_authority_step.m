function [authority_next, margin_filtered_next, margin_guarded_next, ...
        above_count_next, below_count_next, down_confirmed] = ...
        adaptive_pid_authority_step(m91_margin, authority, ...
        margin_filtered, margin_guarded, above_count, below_count, ...
        target_margin, update_interval_s, a_min, a_max, ...
        down_deadband, down_rate, down_immediate_margin, down_confirm_n, ...
        up_deadband, power_law, smooth_down, up_rate, up_hold_s, ...
        margin_guard_up_rate, margin_guard_down_rate, margin_filter_alpha)
%ADAPTIVE_PID_AUTHORITY_STEP Codegen-safe adaptive PID authority update.
% Use this from a Simulink MATLAB Function block after M9.1 produces one
% margin sample. Feed the state outputs back through Unit Delay blocks.
%
% Inputs and outputs are scalar doubles for Simulink Real-Time/Speedgoat
% code generation. No structs, variable-size arrays, persistent state, or
% dynamic MATLAB features are used.
%
% State values:
%   margin_filtered initial value: target_margin
%   margin_guarded  initial value: target_margin
%   above_count     initial value: 0
%   below_count     initial value: 0
%
% The raw M9.1 margin is not modified. The guarded margin is an internal
% decision signal used to slow recovery and reject one-window moderate dips.

%#codegen

authority_next = authority;
margin_filtered_next = margin_filtered;
margin_guarded_next = margin_guarded;
above_count_next = above_count;
below_count_next = below_count;
down_confirmed = 0;

if ~isfinite(m91_margin)
    return
end

margin_filtered_next = (1 - margin_filter_alpha)*margin_filtered ...
    + margin_filter_alpha*m91_margin;

is_low = m91_margin < target_margin - down_deadband;
if is_low
    below_count_next = below_count + 1;
else
    below_count_next = 0;
end

severe_low = is_low && m91_margin <= down_immediate_margin;
down_confirmed = double(is_low && ...
    (severe_low || below_count_next >= down_confirm_n));

if severe_low && m91_margin < margin_guarded
    margin_guarded_next = m91_margin;
elseif m91_margin >= margin_guarded
    margin_guarded_next = min(m91_margin, ...
        margin_guarded + margin_guard_up_rate);
elseif down_confirmed ~= 0 || m91_margin >= target_margin
    margin_guarded_next = max(m91_margin, ...
        margin_guarded - margin_guard_down_rate);
end

if down_confirmed ~= 0
    margin_for_ratio = max(m91_margin, 0.05);
    desired = authority*(margin_for_ratio/target_margin)^power_law;
    desired = max(a_min, min(a_max, desired));
    candidate = (1 - smooth_down)*authority + smooth_down*desired;
    authority_next = max(candidate, authority - down_rate);
    above_count_next = 0;
elseif is_low
    above_count_next = 0;
elseif margin_guarded_next > target_margin + up_deadband
    above_count_next = above_count + 1;
    hold_n = max(1, round(up_hold_s/update_interval_s));
    if above_count_next >= hold_n
        authority_next = min(a_max, authority + up_rate);
    end
else
    above_count_next = 0;
end

authority_next = max(a_min, min(a_max, authority_next));
end
