function [out, state, info] = gpt5_6_4_osi(varargin)
%GPT5_6_4_OSI Compatibility wrapper for the promoted SOL_OSI estimator.
% New code should call sol_osi directly.

[out, state, info] = sol_osi(varargin{:});
end
