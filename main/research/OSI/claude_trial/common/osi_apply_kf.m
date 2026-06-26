function [m_filt, m_smooth, P_filt] = osi_apply_kf(z, q, r, m0, P0)
%OSI_APPLY_KF Scalar random-walk Kalman filter + RTS smoother for the indicator.
% Model:  m_k = m_{k-1} + w_k,  w_k ~ N(0,q)   (true margin random walk)
%         z_k = m_k + v_k,      v_k ~ N(0,r)   (windowed margin measurement)
% This is the smoother the non-overlapping (independent-sample) design enables.
% NaN measurements are treated as missing (predict-only). Units dimensionless.
    if nargin < 4 || isempty(m0), m0 = z(find(~isnan(z),1)); end
    if nargin < 5 || isempty(P0), P0 = r; end
    z = z(:); n = numel(z);
    m_pred = zeros(n,1); P_pred = zeros(n,1);
    m_filt = zeros(n,1); P_filt = zeros(n,1);
    mp = m0; Pp = P0 + q;
    for k = 1:n
        m_pred(k) = mp; P_pred(k) = Pp;
        if isnan(z(k))
            m_filt(k) = mp; P_filt(k) = Pp;            % missing -> no update
        else
            K = Pp / (Pp + r);
            m_filt(k) = mp + K*(z(k) - mp);
            P_filt(k) = (1 - K)*Pp;
        end
        mp = m_filt(k); Pp = P_filt(k) + q;            % predict next
    end
    % RTS backward smoother
    m_smooth = m_filt;
    for k = n-1:-1:1
        A = P_filt(k) / P_pred(k+1);
        m_smooth(k) = m_filt(k) + A*(m_smooth(k+1) - m_pred(k+1));
    end
end
