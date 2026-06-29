%% Generate 3-case (high/low/mixed) damage-jump time series with seeds for M7 and PP-wide.
% Writes results/osi3_timeseries.json for the HTML page. PP-wide = sharp, location-
% agnostic NCF: peak of the output PSD found ANYWHERE in [1.5 90] Hz over a floor taken
% from the healthy baseline's quiet shelf; calibrated on the healthy phase (t<switch).
clearvars; clc;
this_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(this_dir)));
addpath(fullfile(project_main,'research','OSI','claude_trial','common'));   % osi_method7_resonance
addpath(fullfile(project_main,'control_and_HS','b_system_id','id_utils'));
sr=fullfile(project_main,'saved_results'); dt=1/2048; fs=2048;

H7=load(fullfile(sr,'exp_tf','tf_sp_1_7000_20260627_210411.mat'));
H5=load(fullfile(sr,'exp_tf','tf_sp1_5000_20260627_233333.mat'));
PL=load(fullfile(sr,'delay_comp','pl_sp1_5000.mat'));
pv=H7.pid_values;
C=tf(pid(pv.P,pv.I,pv.D,1/pv.derivative_filter_N,dt,'IFormula','ForwardEuler','DFormula','ForwardEuler'));
Hh=H7.models.H_dc_dm_d; Hd=H5.models.H_dc_dm_d; GT=c2d(PL.delay_comp_tf,dt,'tustin');
Th=feedback(C*Hh,1); Sh=feedback(1,C*Hh); Td=feedback(C*Hd,1); Sd=feedback(1,C*Hd);
sigma=H7.source_noise_std;
w=2*pi*logspace(0,log10(90),4000).'; ncf=@(L) min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
bnom=ncf(squeeze(freqresp(C*Hh,w))); true_dmg=ncf(squeeze(freqresp(C*Hd,w)));

n_seed=8; warm=3; switch_s=10; dur=20;
N=round((dur+warm)*fs)+1; t=(0:N-1).'/fs;
ddh=grab(fullfile(sr,'tests','important','20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'),620-warm,N);
ddl=grab(fullfile(sr,'tests','important','20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'),100-warm,N);
cases=struct('name',{'high-band','low-band','mixed'},'dd',{ddh,ddl,ddh+ddl});
keep=t>=warm-1e-9; tk=t(keep)-warm;
wgt=double(tk>=switch_s); rmp=abs(tk-switch_s)<=0.05; wgt(rmp)=0.5*(1+sin(pi*(tk(rmp)-switch_s)/0.1));

% M7 config (as published in run_osi6_vs_osi7)
cfg.t_start=0; cfg.t_end=dur; cfg.ncf_threshold=0.40;
cfg.m7_buf=5; cfg.m7_hop=0.5; cfg.m7_peak_band=[25 42]; cfg.m7_floor_band=[55 75];
cfg.m7_binding_band=[10 58]; cfg.m7_calib_s=7.5; cfg.m7_medfilt=5; cfg.m7_cap=0.70; cfg.m7_detect_consec=4;
ctx.fs=fs; ctx.dt=dt; ctx.C=C; ctx.H0d=Hh; ctx.t=tk;

% PP-wide config
ppc.buf=4; ppc.hop=0.5; ppc.nfft=4096; ppc.win=hann(2048); ppc.ov=1024;
[~,ff]=pwelch(randn(round(ppc.buf*fs),1),ppc.win,ppc.ov,ppc.nfft,fs);
ppc.ppb = ff>=1.5 & ff<=90 & ~(ff>=58 & ff<=62); ppc.ff=ff;
tend=(cfg.t_start+ppc.buf):ppc.hop:cfg.t_end; tc_pp=(tend-ppc.buf/2).';

out.tc_pp=tc_pp; out.switch_s=switch_s; out.threshold=0.40; out.nominal=bnom;
out.true_dmg=true_dmg; out.cases=struct('name',{},'pp_seeds',{},'pp_mean',{}, ...
  'm7_seeds',{},'m7_mean',{},'tc_m7',{},'pp_det',{},'m7_det',{});

fprintf('bnom=%.3f true_dmg=%.3f. Generating %d cases x %d seeds...\n',bnom,true_dmg,numel(cases),n_seed);
for ci=1:numel(cases)
  dd_lead=lsim(GT,cases(ci).dd); trk_h=lsim(Th,dd_lead); trk_d=lsim(Td,dd_lead);
  ddlk=dd_lead(keep);
  DM=zeros(numel(tk),n_seed);
  for s=1:n_seed
    rng(s); d=sigma*randn(N,1);
    dmh=trk_h+lsim(Sh,d); dmd=trk_d+lsim(Sd,d);
    DM(:,s)=(1-wgt).*dmh(keep)+wgt.*dmd(keep);
  end
  % --- PP windowed PSDs ---
  nW=numel(tend); Pall=cell(nW,n_seed);
  for k=1:nW
    i1=find(tk>=tend(k)-ppc.buf,1); idx=i1:i1+round(ppc.buf*fs)-1;
    for s=1:n_seed, Pall{k,s}=pwelch(detrend(DM(idx,s)),ppc.win,ppc.ov,ppc.nfft,fs); end
  end
  % calibrate on healthy windows (tc_pp < switch - buf/2), pooled over seeds
  hmask=tc_pp < switch_s - ppc.buf/2;
  P0=zeros(size(ff)); cnt=0;
  for k=find(hmask).', for s=1:n_seed, P0=P0+Pall{k,s}; cnt=cnt+1; end, end
  P0=P0/cnt; floormask=ppc.ppb & (P0<prctile(P0(ppc.ppb),40));
  spkW=@(P) sqrt(max(movmedian(P,3).*ppc.ppb)/median(P(floormask)));
  rW=[]; for k=find(hmask).', for s=1:n_seed, rW(end+1)=spkW(Pall{k,s}); end, end %#ok<AGROW>
  refW=median(rW);
  B_PP=zeros(nW,n_seed);
  for k=1:nW, for s=1:n_seed, B_PP(k,s)=min(bnom*refW/spkW(Pall{k,s}),1/sqrt(2)); end, end
  % --- M7 per seed ---
  m7=osi_method7_resonance(setfield(ctx,'dm',DM(:,1)),cfg); tc_m7=m7.tc; %#ok<SFLD>
  B_M7=zeros(numel(tc_m7),n_seed);
  for s=1:n_seed
    cx=ctx; cx.dm=DM(:,s); cx.t=tk; cx.dc=lsim(C, ddlk-DM(:,s));
    mm=osi_method7_resonance(cx,cfg); B_M7(:,s)=mm.ncf;
  end
  ppm=mean(B_PP,2); m7m=mean(B_M7,2);
  out.cases(ci).name=cases(ci).name;
  out.cases(ci).pp_seeds=B_PP.'; out.cases(ci).pp_mean=ppm;
  out.cases(ci).m7_seeds=B_M7.'; out.cases(ci).m7_mean=m7m; out.cases(ci).tc_m7=tc_m7;
  out.cases(ci).pp_det=detect(ppm,tc_pp,0.40,5);
  out.cases(ci).m7_det=detect(m7m,tc_m7,0.40,4);
  fprintf('  %-10s: PP healthy %.2f damaged %.2f (det %.1fs) | M7 healthy %.2f damaged %.2f (det %.1fs)\n', ...
    cases(ci).name, mean(ppm(hmask)), mean(ppm(tc_pp>switch_s+ppc.buf/2)), out.cases(ci).pp_det, ...
    mean(m7m(tc_m7<switch_s-2.5)), mean(m7m(tc_m7>switch_s+2.5)), out.cases(ci).m7_det);
end

out_dir=fullfile(this_dir,'results'); if ~exist(out_dir,'dir'), mkdir(out_dir); end
fid=fopen(fullfile(out_dir,'osi3_timeseries.json'),'w'); fwrite(fid,jsonencode(out)); fclose(fid);
fprintf('Saved %s\n',fullfile(out_dir,'osi3_timeseries.json'));

function dd=grab(file,t0,N), R=load(file); i0=find(R.result.t>=t0,1); dd=R.result.dd(i0:i0+N-1); dd=dd-mean(dd); end
function td=detect(b,tc,thr,consec)
  below=b(:)<thr; below(isnan(b))=false; hit=find(movsum(below,[consec-1,0])>=consec,1);
  td=NaN; if ~isempty(hit), td=tc(hit); end
end
