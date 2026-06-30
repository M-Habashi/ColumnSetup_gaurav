%% Generate 3-case (high/low/mixed) damage-jump time series with seeds for M7 and PP-wide.
% Writes results/osi3_timeseries.json for the HTML page. PP-wide = sharp, location-
% agnostic NCF: peak of the output PSD found ANYWHERE in [1.5 90] Hz over a floor taken
% from the healthy baseline's quiet shelf; calibrated on the healthy phase (t<switch).
clearvars; clc;
this_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(this_dir)));
addpath(fullfile(project_main,'research','OSI','claude_trial','common'));   % osi_method7_resonance
addpath(fullfile(project_main,'control_and_HS','b_system_id','id_utils'));
addpath(fullfile(project_main,'research','optimizing_pl','codex'));         % osi_method9_adaptive_margin (M9.1), unchanged
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

cfg.t_start=0; cfg.t_end=dur;   % analysis window span

% --- M9.1 config (verbatim from codex run_m9_vs_m7_compare.m; method file unchanged) ---
cfg9=cfg; cfg9.ncf_threshold=0.40; cfg9.input_power_range_db=30; cfg9.rel_alarm_frac=0.80;
cfg9.m9_band=[2 100]; cfg9.m9_df=1; cfg9.m9_buf=5; cfg9.m9_hop=0.5; cfg9.m9_Lsub=512; cfg9.m9_hsub=256;
cfg9.m9_bootstrap_strength=1.0; cfg9.m9_gamma_min=0.47; cfg9.m9_min_bins=3; cfg9.m9_nwarm=5;
cfg9.m9_medfilt=3; cfg9.m9_detect_consec=1; cfg9.m9_calib_s=7.5; cfg9.m9_cap=0.70;
cfg9.m9_residual_floor=0.03; cfg9.m9_res_prctile=99; cfg9.m9_residual_early_all_bins=true;
cfg9.m9_res_early_match_hz=4; cfg9.m9_res_early_st_floor_frac=0.80; cfg9.m9_res_early_st_gate_frac=0.80;
cfg9.m9_st_prctile=100; cfg9.m9_st_power=1.15; cfg9.m9_freq_medfilt=3; cfg9.m9_line_reject=[58 62];
tc9=((cfg9.t_start+cfg9.m9_buf):cfg9.m9_hop:cfg9.t_end).';

% PP-wide config
ppc.buf=4; ppc.hop=0.5; ppc.nfft=4096; ppc.win=hann(2048); ppc.ov=1024;
[~,ff]=pwelch(randn(round(ppc.buf*fs),1),ppc.win,ppc.ov,ppc.nfft,fs);
ppc.ppb = ff>=1.5 & ff<=90 & ~(ff>=58 & ff<=62); ppc.ff=ff;
% CAUSAL grid: timestamp = window END (look-back only); both methods share it.
tend=(cfg.t_start+ppc.buf):ppc.hop:cfg.t_end; tc=tend.';
m7peak=ff>=25&ff<=42; m7floor=ff>=55&ff<=75; med=5;  % trailing-median taps
s_m7=@(P) sqrt(max(P(m7peak))/median(P(m7floor)));

out.tc_pp=tc; out.tc9=tc9; out.switch_s=switch_s; out.threshold=0.40; out.nominal=bnom;
out.true_dmg=true_dmg; out.cases=struct('name',{},'pp_seeds',{},'pp_mean',{}, ...
  'm7_seeds',{},'m7_mean',{},'tc_m7',{},'m9_seeds',{},'m9_mean',{}, ...
  'pp_det',{},'m7_det',{},'m9_det',{});

fprintf('bnom=%.3f true_dmg=%.3f. Generating %d cases x %d seeds (CAUSAL: backward window,\n',bnom,true_dmg,numel(cases),n_seed);
fprintf('end timestamp, calib on past healthy, trailing median)...\n');
for ci=1:numel(cases)
  dd_lead=lsim(GT,cases(ci).dd); trk_h=lsim(Th,dd_lead); trk_d=lsim(Td,dd_lead);
  ddlk=dd_lead(keep);
  DM=zeros(numel(tk),n_seed);
  for s=1:n_seed
    rng(s); d=sigma*randn(N,1);
    dmh=trk_h+lsim(Sh,d); dmd=trk_d+lsim(Sd,d);
    DM(:,s)=(1-wgt).*dmh(keep)+wgt.*dmd(keep);
  end
  % --- M9.1 (codex osi_method9_adaptive_margin), called UNCHANGED, its own grid ---
  B9=zeros(numel(tc9),n_seed); nom9=bnom;
  for s=1:n_seed
    rng(s);                                   % reproducible bootstrap per seed
    ctx9=struct('fs',fs,'dt',dt,'C',C,'H0d',Hh,'t',tk,'dd_lead',ddlk,'dm',DM(:,s));
    m9=osi_method9_adaptive_margin(ctx9,cfg9);
    B9(:,s)=m9.ncf; nom9=m9.nominal;
  end
  m9m=mean(B9,2,'omitnan');
  % backward window [tend-buf, tend] ending at tend -> per-window PSD
  nW=numel(tend); Pall=cell(nW,n_seed);
  for k=1:nW
    e=find(tk<=tend(k),1,'last'); idx=e-round(ppc.buf*fs)+1:e;   % samples up to tend only
    for s=1:n_seed, Pall{k,s}=pwelch(detrend(DM(idx,s)),ppc.win,ppc.ov,ppc.nfft,fs); end
  end
  % calibrate on PAST healthy windows (window entirely before the jump: tend<=switch)
  hmask=tc<=switch_s;
  P0=zeros(size(ff)); cnt=0;
  for k=find(hmask).', for s=1:n_seed, P0=P0+Pall{k,s}; cnt=cnt+1; end, end
  P0=P0/cnt; floormask=ppc.ppb & (P0<prctile(P0(ppc.ppb),40));
  spkW=@(P) sqrt(max(movmedian(P,3).*ppc.ppb)/median(P(floormask)));   % movmedian over FREQ (within window)
  hk=find(hmask).'; rW=zeros(numel(hk)*n_seed,1); rM=rW; q=0;
  for k=hk
    for s=1:n_seed, q=q+1; rW(q)=spkW(Pall{k,s}); rM(q)=s_m7(Pall{k,s}); end
  end
  refW=median(rW); refM=median(rM);
  B_PP=zeros(nW,n_seed); B_M7=zeros(nW,n_seed);
  for k=1:nW
    for s=1:n_seed
      B_PP(k,s)=min(bnom*refW/spkW(Pall{k,s}),1/sqrt(2));
      B_M7(k,s)=min(bnom*refM/s_m7(Pall{k,s}),1/sqrt(2));
    end
  end
  B_PP=movmedian(B_PP,[med-1 0],1); B_M7=movmedian(B_M7,[med-1 0],1);   % TRAILING median (backward)
  ppm=mean(B_PP,2); m7m=mean(B_M7,2);
  out.cases(ci).name=cases(ci).name;
  out.cases(ci).pp_seeds=B_PP.'; out.cases(ci).pp_mean=ppm;
  out.cases(ci).m7_seeds=B_M7.'; out.cases(ci).m7_mean=m7m; out.cases(ci).tc_m7=tc;
  out.cases(ci).m9_seeds=B9.'; out.cases(ci).m9_mean=m9m;
  out.cases(ci).pp_det=detect(ppm,tc,0.47,5);
  out.cases(ci).m7_det=detect(m7m,tc,0.47,5);
  out.cases(ci).m9_det=detect(m9m,tc9,cfg9.rel_alarm_frac*nom9,cfg9.m9_detect_consec);
  dmask=tc>=switch_s+ppc.buf; d9=tc9>=switch_s+cfg9.m9_buf;
  fprintf(['  %-10s: PP h%.2f d%.2f (det %.1fs) | M7 h%.2f d%.2f (det %.1fs) | ' ...
    'M9.1 h%.2f d%.2f (det %.1fs)\n'], ...
    cases(ci).name, mean(ppm(hmask)), mean(ppm(dmask)), out.cases(ci).pp_det, ...
    mean(m7m(hmask)), mean(m7m(dmask)), out.cases(ci).m7_det, ...
    mean(m9m(tc9<=switch_s)), mean(m9m(d9)), out.cases(ci).m9_det);
end

out_dir=fullfile(this_dir,'results'); if ~exist(out_dir,'dir'), mkdir(out_dir); end
fid=fopen(fullfile(out_dir,'osi3_timeseries.json'),'w'); fwrite(fid,jsonencode(out)); fclose(fid);
fprintf('Saved %s\n',fullfile(out_dir,'osi3_timeseries.json'));

function dd=grab(file,t0,N), R=load(file); i0=find(R.result.t>=t0,1); dd=R.result.dd(i0:i0+N-1); dd=dd-mean(dd); end
function td=detect(b,tc,thr,consec)
  below=b(:)<thr; below(isnan(b))=false; hit=find(movsum(below,[consec-1,0])>=consec,1);
  td=NaN; if ~isempty(hit), td=tc(hit); end
end
