function [authority_next, buffer_next, hold_count_next, ...
        valid_count_next] = osi_method_9_2_auth_slew(osi_value, ...
        authority, buffer, hold_count, valid_count, target_ncf, ...
        update_interval_s, a_min, down_deadband, down_rate_per_s, ...
        up_deadband, up_rate_per_s, up_hold_s, valid_confirm_n)
%OSI_METHOD_9_2_AUTH_SLEW Smooth codegen-safe Method 9.2 authority update.
% The direct 9.2 target remains auth = OSI/target_ncf. This update rejects
% one-window OSI spikes with a 3-sample median, drops authority quickly when
% OSI stays low, and recovers only after clean valid windows.

%#codegen

authority_next = authority;
buffer_next = buffer;
hold_count_next = hold_count;
valid_count_next = valid_count;

if ~isfinite(osi_value)
    valid_count_next = 0;
    return
end

buffer_next(1) = buffer(2);
buffer_next(2) = buffer(3);
buffer_next(3) = osi_value;
valid_count_next = min(valid_count + 1, valid_confirm_n);

lo = min(buffer_next(1), min(buffer_next(2), buffer_next(3)));
hi = max(buffer_next(1), max(buffer_next(2), buffer_next(3)));
osi_med = buffer_next(1) + buffer_next(2) + buffer_next(3) - lo - hi;
a_raw = min(1, max(a_min, osi_med/target_ncf));

if a_raw < authority - down_deadband
    if isfinite(down_rate_per_s)
        authority_next = max(a_raw, ...
            authority - down_rate_per_s*update_interval_s);
    else
        authority_next = a_raw;
    end
    hold_count_next = max(hold_count_next, ...
        max(1, round(up_hold_s/update_interval_s)));
    return
end

if hold_count_next > 0
    hold_count_next = hold_count_next - 1;
end

if valid_count_next >= valid_confirm_n && hold_count_next <= 0 ...
        && a_raw > authority + up_deadband
    authority_next = min(a_raw, authority + up_rate_per_s*update_interval_s);
end

authority_next = min(1, max(a_min, authority_next));
end
