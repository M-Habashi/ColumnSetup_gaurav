%% RUN_OSI5_M9  5-case battery scored on M7, PP, and M9.1 (codex, unchanged).
% Each mechanism case is a healthy->case JUMP at t=switch so every method has a
% healthy phase to calibrate on (M7/PP externally, M9.1 internally via m9_calib_s).
% Output-only regime (dm = S*disturbance, no command), so M9.1 runs on its
% residual branch here; its S,T branch is exercised in the 3-input-case study.
clearvars; clc;
this_dir = fileparts(mfilename('fullpath'));
main = fileparts(fileparts(fileparts(this_dir)));
addpath(this_dir);
addpath(fullfile(main,'control_and_HS','b_system_id','id_utils'));
addpath(fullfile(main,'research','optimizing_pl','codex'));   % osi_method9_adaptive_margin (M9.1)
[cases, ctx0] = osi_test_cases();
dt=ctx0.dt; fs=round(1/dt); sigma=ctx0.sigma; C0=ctx0.C0; Hh=ctx0.Hh;
switch_s=10; dur=40; n_seed=6; N=round(dur*fs)+1; t=(0:N-1).';  t=t/fs;
w=double(t>=switch_s); rmp=abs(t-switch_s)<=0.05; w(rmp)=0.5*(1+sin(pi*(t(rmp)-switch_s)/0.1));
Sh=feedback(1,C0*Hh);
wf=2*pi*logspace(log10(1.5),log10(120),9000).'; ncf=@(L) min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
bnom=ncf(squeeze(freqresp(C0*Hh,wf)));

% --- M7 / PP causal config (my methods) ---
buf=4; Nb=round(buf*fs); nfft=4096; win=hann(2048); ov=1024; med=5;
[~,ff]=pwelch(randn(Nb,1),win,ov,nfft,fs);
ppb=ff>=1.5&ff<=90&~(ff>=58&ff<=62); m7p=ff>=25&ff<=42; m7f=ff>=55&ff<=75;
tend=(buf:0.5:dur).'; hmask=tend<=switch_s; dmask=tend>=switch_s+buf;
s_m7=@(P) sqrt(max(P(m7p))/median(P(m7f)));

% --- M9.1 config (verbatim from codex), calib window inside the healthy prefix ---
cfg9.t_start=0; cfg9.t_end=dur; cfg9.ncf_threshold=0.40; cfg9.input_power_range_db=30; cfg9.rel_alarm_frac=0.80;
cfg9.m9_band=[2 100]; cfg9.m9_df=1; cfg9.m9_buf=5; cfg9.m9_hop=0.5; cfg9.m9_Lsub=512; cfg9.m9_hsub=256;
cfg9.m9_bootstrap_strength=1.0; cfg9.m9_gamma_min=0.47; cfg9.m9_min_bins=3; cfg9.m9_nwarm=5;
cfg9.m9_medfilt=3; cfg9.m9_detect_consec=1; cfg9.m9_calib_s=7.5; cfg9.m9_cap=0.70;
cfg9.m9_residual_floor=0.03; cfg9.m9_res_prctile=99; cfg9.m9_residual_early_all_bins=true;
cfg9.m9_res_early_match_hz=4; cfg9.m9_res_early_st_floor_frac=0.80; cfg9.m9_res_early_st_gate_frac=0.80;
cfg9.m9_st_prctile=100; cfg9.m9_st_power=1.15; cfg9.m9_freq_medfilt=3; cfg9.m9_line_reject=[58 62];
tc9=((cfg9.m9_buf):cfg9.m9_hop:dur).'; d9=tc9>=switch_s+cfg9.m9_buf;

fprintf('\n=== 5-CASE BATTERY with M9.1 (jump healthy->case, output-only, %d seeds) ===\n',n_seed);
fprintf('bnom=%.3f, detect if damaged-phase b<0.47\n\n',bnom);
fprintf('%-3s %-26s %7s %6s %5s | %12s | %12s | %12s\n','id','case','b_true','fHz','band','M7','PP','M9.1');
for i=1:numel(cases)
  c=cases(i); Hi=c.H; if c.delay_samples>0, Hi=c.H*tf(1,[1 zeros(1,c.delay_samples)],dt); end
  Sc=feedback(1,c.C*Hi); L=squeeze(freqresp(c.C*Hi,wf)); bt=ncf(L);
  [~,kk]=min(abs(1+L)./sqrt(2*(1+abs(L).^2))); fb=wf(kk)/(2*pi);
  % seed sims
  P=cell(numel(tend),n_seed); B9=zeros(numel(tc9),n_seed);
  for s=1:n_seed
    rng(s); d=sigma*randn(N,1);
    dm=(1-w).*lsim(Sh,d)+w.*lsim(Sc,d); dm=dm+0.01*std(dm)*randn(N,1);
    for k=1:numel(tend), e=round(tend(k)*fs)+1; P{k,s}=pwelch(detrend(dm(e-Nb+1:e)),win,ov,nfft,fs); end
    rng(s); ctx9=struct('fs',fs,'dt',dt,'C',C0,'H0d',Hh,'t',t,'dd_lead',zeros(N,1),'dm',dm);
    m9=osi_method9_adaptive_margin(ctx9,cfg9); B9(:,s)=m9.ncf;
  end
  % calibrate M7/PP on healthy-prefix windows
  P0=0; hk=find(hmask).'; for k=hk, for s=1:n_seed, P0=P0+P{k,s}; end, end
  P0=P0/(numel(hk)*n_seed); fmask=ppb&(P0<prctile(P0(ppb),40));
  spkP=@(Q) sqrt(max(movmedian(Q,3).*ppb)/median(Q(fmask)));
  rM=zeros(numel(hk)*n_seed,1); rP=rM; q=0;
  for k=hk, for s=1:n_seed, q=q+1; rM(q)=s_m7(P{k,s}); rP(q)=spkP(P{k,s}); end, end
  refM=median(rM); refP=median(rP);
  B7=zeros(numel(tend),n_seed); BP=B7;
  for k=1:numel(tend)
    for s=1:n_seed
      B7(k,s)=min(bnom*refM/s_m7(P{k,s}),1/sqrt(2)); BP(k,s)=min(bnom*refP/spkP(P{k,s}),1/sqrt(2));
    end
  end
  B7=movmedian(B7,[med-1 0],1); BP=movmedian(BP,[med-1 0],1);
  m7d=mean(mean(B7(dmask,:),2)); ppd=mean(mean(BP(dmask,:),2)); m9d=mean(mean(B9(d9,:),2));
  band=ternary(fb>=25&&fb<=42,'IN','OUT'); shd=bt<0.40;
  fprintf('%-3s %-26s %7.3f %6.1f %5s | %5.2f %-6s | %5.2f %-6s | %5.2f %-6s\n', ...
    c.id,c.name,bt,fb,band, m7d,verdict(m7d,shd), ppd,verdict(ppd,shd), m9d,verdict(m9d,shd));
end
fprintf('\nOutput-only battery: M9.1 uses its residual branch (no command -> S,T dormant);\n');
fprintf('its full S,T fusion is exercised in run_osi_ncf_direct_compare / the 3-input study.\n');

function v=verdict(b,should)
  a = b < 0.47;
  if should && a
    v='detect';
  elseif should
    v='MISS';
  elseif a
    v='FALSE';
  else
    v='ok';
  end
end
function s=ternary(c,a,b), if c, s=a; else, s=b; end, end
