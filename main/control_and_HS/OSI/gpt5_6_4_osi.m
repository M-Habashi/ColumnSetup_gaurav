function [out, state, info] = gpt5_6_4_osi(varargin)
%GPT5_6_4_OSI Compatibility wrapper for the promoted SOL_OSI estimator.
% Historical GPT-5.6.4 estimator retained as SOL-OSI V1.

[out, state, info] = sol_osi_v1(varargin{:});
end
