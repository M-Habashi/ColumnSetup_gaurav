function [KK_12, kk_lat] = KK_mat(E,Ic,Ib,Lc,Lb)


L = Lb;
h = Lc;
KK = diag([45*Ic/h^3 72*Ic/h^3 36*Ic/h^3 (7*Ic/h+4*Ib/L) (7*Ic/h+8*Ib/L) (7*Ic/h+4*Ib/L),...
    (8*Ic/h+4*Ib/L) (8*Ic/h+8*Ib/L) (8*Ic/h+4*Ib/L) (4*Ic/h+4*Ib/L) (4*Ic/h+8*Ib/L) (4*Ic/h+4*Ib/L)]);
KK(1,2:end) = [ -36*Ic/h^3  0           -3*Ic/h^2   -3*Ic/h^2   -3*Ic/h^2   -6*Ic/h^2   -6*Ic/h^2   -6*Ic/h^2   0             0            0];
KK(2,3:end) = [-36*Ic/h^3  6*Ic/h^2    6*Ic/h^2    6*Ic/h^2    0           0           0           -6*Ic/h^2    -6*Ic/h^2    -6*Ic/h^2];
KK(3,4:end) = [0 0 0 6*Ic/h^2    6*Ic/h^2    6*Ic/h^2    6*Ic/h^2    6*Ic/h^2    6*Ic/h^2];
KK(4,5:end) = [2*Ib/L     0   2*Ic/h     0 0 0 0 0];
KK(5,6:end) = [2*Ib/L     0   2*Ic/h     0 0 0 0];    
KK(6,7:end) = [0 0 2*Ic/h   0  0  0]; 
KK(7,8:end) = [2*Ib/L   0  2*Ic/h   0  0]; 
KK(8,9:end) = [2*Ib/L   0  2*Ic/h     0];
KK(9,10:end) = [0   0  2*Ic/h]; 
KK(10,11:end) = [2*Ib/L   0 ];
KK(11,12:end) = [2*Ib/L ];

for i = 1:11
    KK(i+1:end,i) = transpose(KK(i,i+1:end));
end
KK = E*KK;
KK_12 = KK;

% 12 DOF Stiffness matrix condensed in 3 DOF
kk_lat = KK(1:3,1:3) - transpose(KK(4:12,1:3))*inv(KK(4:12,4:12))*KK(4:12,1:3);
