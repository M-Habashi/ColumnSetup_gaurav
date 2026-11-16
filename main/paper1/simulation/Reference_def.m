% Benchmark Problem in Real-Time Hybrid Simulation
% Fininte Element Model of the Full Structure, 30 DOF
% 3-Story, 2-Bay Moment-Resisting Frame.

% FEM by Christian Silva, Purdue University, 5/15/2018
% Collaborators: Daniel Gomez P., Amin Maghareh
% Supervised by: Shirley J. Dyke, Billie Spencer Jr.

%%%%%%%%%%%%%%%%%%%%%%^^^^^^^^^^^^^^^^^^^^^^^^^^^%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% M O D E L    DESCRIPTION  %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%vvvvvvvvvvvvvvvvvvvvvvvvvvv%%%%%%%%%%%%%%%%%%%%%%%%%
% 
%     ------------------------- Acc 3 (3rd floor) 
%    9|          6|          3|                            ^ y
%     |           |           |                            |
%     |           |           |                            |  
%     ------------- ----------- Acc 2 (2nd floor)          |
%    8|          5|          2|                            |
%     |           |           |                            ------------>
%     |           |           |                                        x
%     ------------- ----------- Acc 1 (1st floor) 
%    7|          4|          1|
%     |           |           |
%     |           |           |
%  12 ^        11 ^        10 ^ Hinged boundary conditions
%     -------------------------
%     -------Ground Motion-----   (shaking direction: <-->)
%     -------------------------
% 
%  
%  GLOBAL DOF'S: 
%  1) x_1    2) x_2      3) x_3      4) x_4      5) x_5      6) x_6
%  7) x_7    8) x_8      9) x_9     10) y_1     11) y_2     12) y_3
% 13) y_4   14) y_5     15) y_6     16) y_7     17) y_8     18) y_9
% 19) @_1   20) @_2     21) @_3     22) @_4     23) @_5     24) @_6
% 25) @_7   26) @_8     27) @_9     28) @_10    29) @_11    30) @_12
%
% x: horizontal displacement
% y: vertical displacement
% @: rotation around axis perpendicular to x-y 


clc, clear, close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         Define mass and damping ratio  for the FEM model          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  NOTE: Participants should replace this portion of the file to modify 
%        the reference system cases.

m_ref = [1000 1100 1300 1000];       % Floor mass, [kg]
z_ref = [.05  .04  .03  .03 ];        % Modal damping ratio, [--]


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Define Material properties %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NOTE: This portion of the file should not be modified.

Lb = 762/1000;                      % Beam length (m)
Lc = 635/1000;                      % Column length (m)
Ic = 2.520*(25.4/1000)^4;           % 2nd Moment of Area x column (m^4)
Ib = 255267/1000^4;                 % 2nd Moment of Area x beam (m^4)
Ac = 1.670*(25.4/1000)^2;           % Cross sectional Area column (m^2)
Ab = 0.947*(25.4/1000)^2;           % Cross sectional Area beam (m^2)

E = 200E9;                          % steel modulus of elasticity (MPa)
NEL = 15;                           % number of finite elements
DOF = NEL*2;                        % number of degrees of freedom

%==========================================================================

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Transformation Matrices properties %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NOTE: This portion of the file should not be modified.

% DEFINE LOCAL TO GLOBAL TRANSFORMATION MATRIX

L2G = [ 4   13  22  1   10  19;
        5   14  23  2   11  20;
        6   15  24  3   12  21;
        7   16  25  4   13  22;
        8   17  26  5   14  23;
        9   18  27  6   15  24;
        0   0   28  10  -1  19;
        0   0   29  13  -4  22;
        0   0   30  16  -7  25;
        10  -1  19  11  -2  20;
        13  -4  22  14  -5  23;
        16  -7  25  17  -8  26;
        11  -2  20  12  -3  21;
        14  -5  23  15  -6  24;
        17  -8  26  18  -9  27];


% INITIALIZE ASSEMBLAGE TRANSFORMATION MATRICES    
    
for jj = 1:DOF
a{jj} = zeros(6,DOF);
end
clear jj

% SETUP ASSEMBLAGE TRANSFORMATION MATRICES ELEMENTS

lug = zeros(6,1);
for ii = [1:6 10:NEL]
    for jj = 1:6
%         if ii < 7
            a{ii}(jj,abs(L2G(ii,jj))) = sign(L2G(ii,jj));
            lug(jj) = L2G(ii,jj);
%         else
%             a{ii}(jj,abs(L2G(ii,jj))) = sign(L2G(ii,jj));
%             lug(jj) = abs(L2G(ii,jj));
%         end        
    end    
    check =[(1:6)', lug];
end

lug = zeros(6,1);
for ii = 7:9
    for jj = 3:6 
    a{ii}(jj,abs(L2G(ii,jj))) = sign(L2G(ii,jj));
    lug(jj) = L2G(ii,jj);    
    end
    check =[(1:6)', lug];
end


clear ii jj L2G 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%   Stiffness Matrix   %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% DEFINE ELEMENT STIFFNESS MATRIX

% BEAM
kb = E*Ib/Lb^3* ...
    [Ab*Lb^2/Ib 0 0 -Ab*Lb^2/Ib 0 0;
     0 12 6*Lb 0 -12 6*Lb;
     0 6*Lb 4*Lb^2 0 -6*Lb 2*Lb^2;
     -Ab*Lb^2/Ib 0 0 Ab*Lb^2/Ib 0 0;
     0 -12 -6*Lb 0 12 -6*Lb;
     0 6*Lb 2*Lb^2 0 -6*Lb 4*Lb^2];

% COLUMN
kc = E*Ic/Lc^3* ...
    [Ac*Lc^2/Ic 0 0 -Ac*Lc^2/Ic 0 0;
     0 12 6*Lc 0 -12 6*Lc;
     0 6*Lc 4*Lc^2 0 -6*Lc 2*Lc^2;
     -Ac*Lc^2/Ic 0 0 Ac*Lc^2/Ic 0 0;
     0 -12 -6*Lc 0 12 -6*Lc;
     0 6*Lc 2*Lc^2 0 -6*Lc 4*Lc^2]; 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% Matrix Assemblage %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% STIFFNESS LOCAL TO GLOBAL
for ll = 1:6
    kb_hat{ll} = a{ll}'*kb*a{ll};    
end
clear ll

for ll = 7:NEL
    kc_hat{ll} = a{ll}'*kc*a{ll};    
end
clear ll

% STIFFNESS GLOBAL ASSEMBLY
K = zeros(DOF,DOF);
for nn = 1:NEL
    if nn < 7
        K = K+kb_hat{nn};
    else
        K = K+kc_hat{nn};
    end
end
clear nn


% DEFINE LUMPED MASS MATRIX 
for ii = 1:length(m_ref)^1
    % Lumped mass matrix
     M = diag([m_ref(ii)/4   m_ref(ii)/4   m_ref(ii)/4   m_ref(ii)/2  m_ref(ii)/2   m_ref(ii)/2   m_ref(ii)/4   m_ref(ii)/4   m_ref(ii)/4   m_ref(ii)/4   m_ref(ii)/4   m_ref(ii)/4  m_ref(ii)/2   m_ref(ii)/2   m_ref(ii)/2   m_ref(ii)/4   m_ref(ii)/4    m_ref(ii)/4      0.01*ones(1,12)]);

    % CALCULATE MODAL PARAMETERS 
    [V, D] = eig(M\K);
    freq = sqrt(sort(diag(D)))/2/pi;    % [Hz]
end

% NOTE:
% For purposes of examining single actuator RTHS and given the fact that 
% the finite element model resulting from the benchmark structure has a large 
% number of DOF and high frequency dynamics, and given the fact that the model 
% is linear elastic, static condensation is applied to the model. This results 
% in a 3 DOF reference model, with lumped masses on each story depicted in 
% Fig. 2 (see the companion paper). Along  with  static  condensation, 
% other  assumptions  are  made  to  reduce  the model without loss of 
% relevant and necessary information.  Specifically, these are (1) the 
% vertical translations of all the nodes of  the model are neglected as their
% magnitudes are very small compared to their horizontal counterparts.  
% This was confirmed by the vertical displacements obtained from the FEM model,
% which resulted in values negligible compared to those corresponding to the
% horizontal displacements; (2) the beams in each story behave as a rigid
% diaphragm as confirmed by the FE model, and (3) a lumped-mass is
% applied at each floor which includes the self-weight of the structure. 
% Static condensation is applied by apportioning the mass and stiffness
% matrices into dy-namic  (non-zero) and  zero-mass  DOF.  Once  this  step is
% completed, the  static transformation matrix is determined,  and the condensed
% mass, stiffness and input coefficients are obtained (Chopra et al., 1995).


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                        Reference model (3-DOF)                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NOTE: This portion of the file should not be modified.

for ii = 1:length(m_ref)
    Ms = m_ref(ii)*[1 1 1];         % [Mass_1st_floor    Mass_2nd_floor    Mass_3rd_floor  ]
    zetas = z_ref(ii)*[1 1 1];      % [Damping_1st_mode  Damping_2nd_mode  Damping_3rd_mode]
    %--------------------------------------------------------------------------
    
    % Reference Model 
    % NOTE: This portion of the file should not be modified.

    [~, M] = MM_mat(Ms);
    [~, K] = KK_mat(E,Ic,Ib,Lc,Lb);

    % Natural modes and frequencies 
    [fi, frecs, ~, ~, fi_n,]  = modes(M,K);

    n = length(frecs);     % Number of degrees of freedom
    % Build the damping
    C = CC_mat(n, M, zetas, fi, frecs);

    % State Space form  (REFERENCE system)
    iota = ones(n,1);
    AA_ref = [...
        zeros(n,n) eye(n);
        -M\K -M\C];
    BB_ref = [...
        zeros(n,1); 
        -eye(n)\iota];
    CC_ref = [...
        eye(n) zeros(n,n);
        zeros(n,n) eye(n);
        -M\K -M\C];
    DD_ref = [...
        zeros(n,1);
        zeros(n,1); 
        zeros(n,1)];
    sys_r = ss(AA_ref,BB_ref,CC_ref,DD_ref);

    [Wn,ZZ] = damp(sys_r);
    fn = Wn([1:2:6])/2/pi;
    zeta = ZZ([1:2:6])*100;

fprintf('Reference system: \n');
fprintf('(CASE %d:    Mass per floor = %1.2f\t [kg]) \n',ii,m_ref(ii));
A1 = [1 round(100*fn(1))/100 zeta(1)];
A2 = [2 round(100*fn(2))/100 zeta(2)]; ...
A3 = [3 round(100*fn(3))/100 zeta(3)];
formatSpec = 'Mode %d:\t    fn: %1.2f\t [Hz],    zeta = %2.2f\t [%%]\n';
fprintf(formatSpec,A1,A2,A3)
disp(' ')

save(strcat('./Building cases/Case_',num2str(ii)),'M','C','K','zetas','n','sys_r')
end

