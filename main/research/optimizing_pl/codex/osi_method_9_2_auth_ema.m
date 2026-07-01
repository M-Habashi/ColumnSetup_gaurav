function [authority_next, valid_count_next] = osi_method_9_2_auth_ema( ...
        osi_value, authority, valid_count, target_ncf, a_min, ...
        alpha_down, alpha_up, valid_confirm_n)
%OSI_METHOD_9_2_AUTH_EMA Fast-down slow-up Method 9.2 authority update.
% This is a simple comparison candidate for the median+slew law. Invalid
% OSI samples hold the previous authority and reset the clean-window count.

%#codegen

authority_next = authority;
valid_count_next = valid_count;

if ~isfinite(osi_value)
    valid_count_next = 0;
    return
end

valid_count_next = min(valid_count + 1, valid_confirm_n);
a_raw = min(1, max(a_min, osi_value/target_ncf));

if a_raw < authority
    alpha = alpha_down;
elseif valid_count_next >= valid_confirm_n
    alpha = alpha_up;
else
    alpha = 0;
end

authority_next = authority + alpha*(a_raw - authority);
authority_next = min(1, max(a_min, authority_next));
end
