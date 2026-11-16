%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                     Controller algorithm design                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% DEFINE CONTROLLER CHARACTERISTICS
%  NOTE: Participants should replace this portion of the file to modify
%        the basic sample controllers.

load('./Controllers/Controller_2018_6_11_15_20_29')

%%

% PID tracking controller
%  Gc = ss(pid_1);
G_C = ss(pid_1);

% Phase compensator 
pre_ss = ss(G_T);

%% CHECK STABILITY
% NOTE: This portion of the file should not be modified.

G_CL = feedback(G_C*G_pp,1,-1);

% CHECK STABILITY OF CONTROLLER
if max(real(eig(G_C.a))) > 0 
	disp('UNSTABLE CONTROLLER !')
	return
end
% CHECK STABILITY OF CLOSED LOOP SYSTEM (w/CONTROLLER)
if max(real(eig(G_CL.a))) > 0 
	disp('CLOSED LOOP UNSTABLE !')
	return
end

%  Convert to Discrete Form 
[Acd,Bcd,Ccd,Dcd]         = c2dm(G_C.a,G_C.b,G_C.c,G_C.d,dt_rths,'tustin');
[Apred,Bpred,Cpred,Dpred] = c2dm(pre_ss.a,pre_ss.b,pre_ss.c,pre_ss.d,dt_rths,'tustin');

%% Controllers transfer functions
% NOTE: This portion of the file should not be modified.

switch lower(plot_cont_on)
    case 'yes'
    b_d = [0 0.4471 0.7412];   r_d = [0.8510 0.3255 0.0980];  y_d = [0.9294  0.6941    0.1255];   % Color definition

    ww = 2*pi*logspace(-1,2,3000);

    [MAG,PHASE] = bode(pid_1,ww);
    magn = squeeze(MAG);   mag_PI = abs(magn);
    pha  = squeeze(PHASE); ang_PI = unwrap(pha);

    [MAG,PHASE] = bode(G_T,ww);
    magn = squeeze(MAG);   mag_PL = abs(magn);
    pha  = squeeze(PHASE); ang_PL = unwrap(pha);

    figure
    subplot(2,1,1);
    p1 = plot(ww/2/pi,db(mag_PI),'color',b_d,'linewidth',2);  hold on, grid on
    p2 = plot(ww/2/pi,db(mag_PL),'color',r_d,'linewidth',2);  hold on, grid on
    axis([0 40 -10 40])
    ylabel('Magnitude [dB]','fontsize',12,'fontweight','bold')

    subplot(2,1,2);
    plot(ww/2/pi,ang_PI,'color',b_d,'linewidth',2),  hold on, grid on
    plot(ww/2/pi,ang_PL,'color',r_d,'linewidth',2),  hold on, grid on
    axis([0 40 -100 100])
    ylabel('Phase [deg]','fontsize',12,'fontweight','bold')

    legend([p1,p2],{'PI controller TF','Phase-lead controller TF'},'Location','northeast','fontsize',10)
    xlabel('Frequency [Hz]','fontsize',12,'fontweight','bold'), 

    % Response comparison of the Plant, and CL controllers
    tt = 0:dt_rths:.12;

    T_A = feedback(pid_1*G_plant,1);
    T_AF = G_T* T_A;

    [y_p] =  step(G_plant,tt);
    [y_PI] =  step(T_A,tt);
    [y_Par] = step(T_AF,tt);

    figure
    p1 = plot([0 tt(end)],[1 1],'k--','linewidth',1.2); grid on, hold on
    p1 = plot(tt,y_p,'color',b_d,'linewidth',2);
    p2 = plot(tt,y_PI,'color',r_d,'linewidth',2);
    p3 = plot(tt,y_Par,'color',y_d,'linewidth',2);
    axis([0 tt(end) 0 1.5])
    xlabel('Time [sec]','fontsize',12,'fontweight','bold')
    ylabel('Amplitude','fontsize',12,'fontweight','bold'), 
    legend([p1,p2,p3],{'Plant response','Closed-loop response (PI)','Closed-loop response (PI & PL)'},'Location','southeast','fontsize',10)

    [MAG,PHASE] = bode(G_plant,ww);
    magn = squeeze(MAG);   mag_OL = abs(magn);
    pha  = squeeze(PHASE); ang_OL = unwrap(pha);

    [MAG,PHASE] = bode(T_A,ww);
    magn = squeeze(MAG);   mag_CL = abs(magn);
    pha  = squeeze(PHASE); ang_CL = unwrap(pha);

    [MAG,PHASE] = bode(T_AF,ww);
    magn = squeeze(MAG);   mag_F = abs(magn);
    pha  = squeeze(PHASE); ang_F = unwrap(pha);

    figure
    s1 = subplot(3,1,1);
    p1 = plot(ww/2/pi,db(mag_OL),'color',b_d,'linewidth',2);  hold on, grid on
    p2 = plot(ww/2/pi,db(mag_CL),'color',r_d,'linewidth',2); 
    p3 = plot(ww/2/pi,db(mag_F),'color',y_d,'linewidth',2); 
    axis([0 40 -60 10])
    ylabel('Magnitude [dB]','fontsize',12,'fontweight','bold')

    s2 = subplot(3,1,2);
    plot(ww/2/pi,ang_OL,'color',b_d,'linewidth',2),  hold on, grid on
    plot(ww/2/pi,ang_CL,'color',r_d,'linewidth',2), 
    plot(ww/2/pi,ang_F,'color',y_d,'linewidth',2),
    axis([0 40 -180 0])
    ylabel('Phase [deg]','fontsize',12,'fontweight','bold')

    Td1 = ang_OL'/(2*pi)./ww/(2*pi);        % convert phase lag to time delay in second
    DL1 = mean(abs(Td1(2:500)));

    Td2 = ang_CL'/(2*pi)./ww/(2*pi);        % convert phase lag to time delay in second
    DL2 = mean(abs(Td2(2:500)));

    Td3 = ang_F'/(2*pi)./ww/(2*pi);        % convert phase lag to time delay in second
    DL3 = mean(abs(Td3(2:500)));

    s2 = subplot(3,1,3);
    plot(ww/2/pi,Td1,'linewidth',2,'color',b_d); grid on, hold on
    plot(ww/2/pi,Td2,'linewidth',2,'color',r_d)
    plot(ww/2/pi,Td3,'linewidth',2,'color',y_d)
    axis([0 40 -.04 0])
    ylabel('Time delay [sec]','fontsize',12,'fontweight','bold')
    xlabel('Frequency [Hz]','fontsize',12,'fontweight','bold'), 
    legend([p1,p2,p3],{'Plant response','Closed-loop response (PI)','Closed-loop response (PI & PL)'},'Location','southwest','fontsize',10)
    otherwise 
end
