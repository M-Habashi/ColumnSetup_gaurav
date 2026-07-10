function make_report_data(here, suite_fabby, suite_fable, suite_gpt, ...
    gdb, score_fabby, score_fable, score_gpt)
%MAKE_REPORT_DATA Export suite + GDB traces as report_data.js for
% fabby_report.html (self-contained: var REPORT = {...}).

D = struct();
D.target = suite_fabby.target;
D.score_fabby = round(score_fabby.mean_score*10)/10;
D.score_fable = round(score_fable.mean_score*10)/10;
D.score_gpt = round(score_gpt.mean_score*10)/10;
D.cases = {};
for i = 1:numel(suite_fabby.cases)
    cf = suite_fabby.cases(i);
    cb = suite_fable.cases(i);
    cg = suite_gpt.cases(i);
    sf = score_fabby.cases(i);
    sb = score_fable.cases(i);
    sg = score_gpt.cases(i);
    c = struct();
    c.name = cf.name;
    c.pass_fabby = cf.pass;
    c.pass_fable = cb.pass;
    c.pass_gpt = cg.pass;
    c.detail_fabby = cf.detail;
    c.detail_fable = cb.detail;
    c.detail_gpt = cg.detail;
    c.score_fabby = round(sf.score*10)/10;
    c.score_fable = round(sb.score*10)/10;
    c.score_gpt = round(sg.score*10)/10;
    c.tc = round4(cf.sim.tc);
    c.b_true = round4(cf.sim.b_true);
    c.b_star = round4(sf.b_star);
    c.b_fabby = round4(cf.sim.b_est);
    c.a_fabby = round4(cf.sim.a);
    c.b_fable = round4(cb.sim.b_est);
    c.a_fable = round4(cb.sim.a);
    c.b_gpt = round4(cg.sim.b_est);
    c.a_gpt = round4(cg.sim.a);
    [c.dm_t, c.dm_lo, c.dm_hi] = envelope_bins(cf.sim.t, cf.sim.dm, 700);
    D.cases{end+1} = c;
end

g = struct();
g.tc = round4(gdb.tc);
g.b = round4(gdb.b);
g.b_st = round4(gdb.b_st);
g.b_q = round4(gdb.b_q);
g.a = round4(gdb.a);
g.b_gpt = round4(gdb.b_gpt);
g.a_gpt = round4(gdb.a_gpt);
g.auth_logged = round4(gdb.auth_logged);
g.b_logged = round4(gdb.b_logged);
g.diag_gain = round4(gdb.diag_gain);
[g.u_t, g.u_lo, g.u_hi] = envelope_bins(gdb.t_raw, gdb.u_osi, 700);
[g.dm_t, g.dm_lo, g.dm_hi] = envelope_bins(gdb.t_raw, gdb.dm, 700);
D.gdb = g;

txt = ['var REPORT = ' jsonencode(D) ';'];
fid = fopen(fullfile(here, 'report_data.js'), 'w');
fwrite(fid, txt);
fclose(fid);
fprintf('report_data.js written (%.1f MB)\n', numel(txt)/1e6);
end

function y = round4(x)
y = round(x*1e4)/1e4;
y(~isfinite(x)) = NaN;   % jsonencode turns NaN into null
end

function [tb, lo, hi] = envelope_bins(t, x, nbin)
n = numel(t);
edges = round(linspace(1, n+1, nbin+1));
tb = NaN(nbin, 1); lo = tb; hi = tb;
for k = 1:nbin
    seg = x(edges(k):edges(k+1)-1);
    tb(k) = t(edges(k));
    lo(k) = min(seg);
    hi(k) = max(seg);
end
tb = round4(tb); lo = round4(lo); hi = round4(hi);
end
