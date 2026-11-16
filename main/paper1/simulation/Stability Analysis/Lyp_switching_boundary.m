%% Check if the switching is guranteed to be stable
% run test_margin_5 first

function [P, gamma] = find_common_lyapunov(G_st, P1, P2)
% Compact fmincon search for a common quadratic Lyapunov matrix P.
% P is normalized to trace(P)=1 internally; gamma is the achieved rate.
%
% Closed-loop realization (negative feedback, SISO):
%   Plant:      x_Tdot = A_T x_T + B_T u,        y = C_T x_T + D_T u
%   Controller: x_Cdot = A_C x_C + B_C y,        u = -(C_C x_C + D_C y)
% Then
%   A_cl = [ A_T - B_T D_C C_T,   B_T C_C
%           -B_C C_T,             A_C ]     (eq. 56, with D_T = 0)
%
% Assumptions:
%   • SISO
%   • D_T = 0 (strictly proper plant)
%   • P1 and P2 have the same state dimension (same controller order)

    % --- Get plant SS (enforce minimal realization) ---
    Gss = minreal(ss(G_st), 1e-8);
    [AT,BT,CT,DT] = ssdata(Gss);
    if any(abs(DT(:)) > 1e-10)
        error('find_common_lyapunov:DTnonzero', ...
             ['This implementation assumes D_T = 0. Detected ||D_T|| > tol.\n' ...
              'Either prefilter the plant to be strictly proper or augment states.']);
    end

    % --- Get controller SS for both candidates (allow PI/PID/TF/SS objects) ---
    C1ss = minreal(ss(P1), 1e-8);   [A1,B1,C1,D1] = ssdata(C1ss);
    C2ss = minreal(ss(P2), 1e-8);   [A2,B2,C2,D2] = ssdata(C2ss);

    % Sanity: same controller order for common Lyapunov search
    if size(A1,1) ~= size(A2,1)
        error('find_common_lyapunov:ordermismatch', ...
              'Controllers must have the same state dimension (order).');
    end

    % --- Build closed-loop A matrices using (56), negative-feedback sign ---
    % A_cl = [ AT - BT*D*C_T,   BT*C
    %          -B*C_T,          A ]
    Acl1 = [AT - BT*D1*CT,  BT*C1;  -B1*CT,  A1];
    Acl2 = [AT - BT*D2*CT,  BT*C2;  -B2*CT,  A2];

    % Total closed-loop order
    ncl  = size(AT,1) + size(A1,1);

    % Decision: x = [vech(L); gamma],  P = (L*L'+epsI*I)/trace(...)
    epsI = 1e-6;
    nvL  = ncl*(ncl+1)/2;  ig = nvL+1;
    L0   = eye(ncl);  x0 = [packL(L0); 1e-2];

    obj = @(x) -x(ig);  % maximize gamma
    nonlcon = @(x) lmi_con(x,ncl,ig,epsI,Acl1,Acl2);

    opts = optimoptions('fmincon','Algorithm','sqp','Display','iter', ...
                        'FiniteDifferenceType','central','MaxIterations',1000, ...
                        'MaxFunctionEvaluations',1e5,'ConstraintTolerance',1e-7);

    LB = [-inf(nvL,1); 1e-12];  UB = [inf(nvL,1); inf];

    % ================== MULTI-START replacement block ==================
    rng('shuffle');                 % <-- different random seed on each run
    Nstarts = 20;                   % try 20..50 if you want more robustness
    
    best = struct('have',false,'maxeig',Inf,'P',[],'gamma',0);
    
    for k = 1:Nstarts
        % random lower-triangular L0 with positive diagonal
        L0 = tril(randn(ncl));
        L0(1:ncl+1:end) = abs(diag(L0)) + 1;     % ensure strong PD start
        g0 = 10.^(-4 + 2*rand);                  % random gamma in [1e-4,1e-2]
        x0 = [packL(L0); g0];
    
        [xk,~,~,outk] = fmincon(obj,x0,[],[],[],[],LB,UB,nonlcon,opts);
    
        % prefer fmincon's best feasible iterate if it has one
        x_use = xk;
        if isfield(outk,'bestfeasible') && ~isempty(outk.bestfeasible) && isfield(outk.bestfeasible,'x')
            x_use = outk.bestfeasible.x;
        end
    
        % build candidate P,gamma and evaluate LMI residual
        Lk   = unpackL(x_use(1:nvL), ncl);
        Pt   = Lk*Lk' + epsI*eye(ncl);
        Pk   = Pt/trace(Pt);
        gk   = x_use(ig);
    
        M1   = Acl1'*Pk + Pk*Acl1 + gk*eye(ncl);
        M2   = Acl2'*Pk + Pk*Acl2 + gk*eye(ncl);
        S1k  = 0.5*(M1 + M1');
        S2k  = 0.5*(M2 + M2');
        mx   = max([max(eig(S1k)), max(eig(S2k))]);   % worst LMI eigenvalue
    
        % keep the best (smallest worst-eig), tie-break by larger gamma
        if mx < best.maxeig || ~best.have
            best = struct('have',true,'maxeig',mx,'P',Pk,'gamma',gk);
        elseif abs(mx - best.maxeig) <= 1e-12 && gk > best.gamma
            best.P = Pk; best.gamma = gk;
        end
    end
    
    % adopt best found
    P     = best.P;
    gamma = best.gamma;
    % ================================================================

    % Build symmetric LMI residuals
    M1 = Acl1'*P + P*Acl1 + gamma*eye(ncl);
    M2 = Acl2'*P + P*Acl2 + gamma*eye(ncl);
    S1 = 0.5*(M1 + M1');   % symmetric projection for robust eigenvalue tests
    S2 = 0.5*(M2 + M2');

    % ----- Final report (clear & loud) -----
    tolP = 1e-8;           % criterion for P ≻ 0:  min eig(P) > tolP
    tolS = 1e-8;           % criterion for S ≺ 0:  max eig(S) < -tolS

    mineigP  = min(eig(P));
    maxeigS1 = max(eig(S1));
    maxeigS2 = max(eig(S2));

    okP  = (mineigP  >  tolP);
    okS1 = (maxeigS1 < -tolS);
    okS2 = (maxeigS2 < -tolS);

    if okP && okS1 && okS2
        fprintf('\n==================== Solution FOUND ====================\n');
    else
        fprintf('\n================= Solution NOT Found ===================\n');
    end

    fprintf('pp (P matrix) =\n');  disp(P);

    fprintf('Acl1 (closed-loop A for P1) =\n');  disp(Acl1);
    fprintf('Acl2 (closed-loop A for P2) =\n');  disp(Acl2);

    fprintf('CHECK 1: P > 0  ->  min eig(P) = %.3e  >  tolP=%.1e   ==> %s\n', ...
            mineigP, tolP, tf(okP));
    fprintf('CHECK 2: S1 < 0 ->  max eig(S1)= %.3e  < -tolS=%.1e   ==> %s\n', ...
            maxeigS1, tolS, tf(okS1));
    fprintf('CHECK 3: S2 < 0 ->  max eig(S2)= %.3e  < -tolS=%.1e   ==> %s\n', ...
            maxeigS2, tolS, tf(okS2));

    fprintf('Notes: require min eig(P) > tolP and max eig(Si) < -tolS (i=1,2). gamma=%.6g\n', gamma);

    % Optional extra context
    fprintf('max(real(eig(Acl1))) = %0.6g\n', max(real(eig(Acl1))));
    fprintf('max(real(eig(Acl2))) = %0.6g\n', max(real(eig(Acl2))));
end

% ---- helpers (kept tiny) ----
function [c,ceq] = lmi_con(x,n,ig,epsI,A1,A2)
    L  = unpackL(x(1:n*(n+1)/2),n);
    g  = x(ig);
    P  = L*L' + epsI*eye(n);  P = P/trace(P);
    S1 = 0.5*((A1'*P + P*A1 + g*eye(n)) + (A1'*P + P*A1 + g*eye(n))');
    S2 = 0.5*((A2'*P + P*A2 + g*eye(n)) + (A2'*P + P*A2 + g*eye(n))');
    c  = [max(eig(S1)); max(eig(S2))];  % must be <= 0
    ceq = [];
end
function v = packL(L)
    n=size(L,1); v=zeros(n*(n+1)/2,1); k=1;
    for i=1:n, for j=1:i, v(k)=L(i,j); k=k+1; end, end
end
function L = unpackL(v,n)
    L=zeros(n); k=1;
    for i=1:n, for j=1:i, L(i,j)=v(k); k=k+1; end, end
end
function s = tf(b), if b, s='PASS'; else, s='FAIL'; end, end



% original system
transfer_sys = inner_open_loop2_with_params(mp ,cp, kp);

opts = pidtuneOptions('PhaseMargin',60);
analog_cntrlr= pid(1, 0, 0); 
analog_cl = feedback(analog_cntrlr*transfer_sys, 1);

[digital_cntrlr, info_d] = pidtune(analog_cl, 'PI',80, opts);
[digital_cntrlr2, info_d] = pidtune(analog_cl, 'PI',62.5, opts);

% reduced at alpha_i (location of the switch)
alpha = 0.35;
ki = alpha * kp;
ci = 2*zeta*sqrt(alpha*kp*mp);
analog_cl_r = feedback(analog_cntrlr * inner_open_loop2_with_params(mp, ci, ki), 1);

plant = analog_cl_r;           % G(s)=1/(s+2)
P1 = digital_cntrlr;
P2 = digital_cntrlr2;
[pp, g] = find_common_lyapunov(plant, P1, P2);
eig(pp)                         % should be > 0 if successful
