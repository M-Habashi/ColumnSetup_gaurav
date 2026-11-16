function [fi, frecs, Mn, Kn, fi_n, fnn, Tn]  = modes(M,K)
% MODES Obtains the natural modes and the associated natural frequencies. 
 
%% NOTE: This portion of the file should not be modified.

% Natural Modes and freqs. 
[fi, w_cuad] = eig(M\K);     % Faster than eig(inv(M)*K)
[frecs, ind]= sort(sqrt(diag(w_cuad)));
frecs = diag(round(100*frecs)/100);         % [rad/sec]
fnn = frecs/2/pi;                           % [Hz]
fi = fi(:,ind');
Tn = diag(2*pi./frecs);                     % [sec]
% Normalize the modes with respect to the mass. 
for i = 1:length(fi)
    Mn = fi(:,i)'*M*fi(:,i);
    fi_norm(:,i) = 1/sqrt(Mn).*fi(:,i);
end
%  Modal properties. 
Mn = fi_norm'*M*fi_norm;    % Must be = I
Kn = fi_norm'*K*fi_norm;    % Must be = w_cuad
fi_n = fi_norm;
end
