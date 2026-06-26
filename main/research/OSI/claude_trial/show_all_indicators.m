%% show_all_indicators -- run all six OSI methods and show an overview figure
%% for EACH data file (broadband 1731 and low-frequency 1749) -> two figures.
% Panel 1: reference dd and response dm. Panels 2-7: the indicator from M1..M6.
% Panel 8: collapse zoom. Loads cached trial results (runs a trial if missing).

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, 'common'));
files = getfield(osi_config(), 'test_files');   %#ok<GFLD>
tags  = {'trial_1','trial_2','trial_3','trial_4','trial_5','trial_6','trial_7'};
short = {'M1: nonparametric H1 (direct)', 'M2: parametric per-window', ...
         'M3: dd-instrument', 'M4: nu-gap drift', ...
         'M5: recursive RLS tracker', 'M6: recursive freq-point Kalman', ...
         'M7: output resonance (sensitivity peak)'};
nM = numel(tags);

for fi = 1:numel(files)
    setappdata(0, 'osi_data_file', files{fi});
    cfg = osi_config();  ctx = osi_load_context(cfg);

    S = cell(nM,1);
    for i = 1:nM
        f = fullfile(cfg.results_dir, [tags{i} '_' cfg.data_id '_result.mat']);
        if ~isfile(f), evalc(['run(''' fullfile(this_dir,tags{i},['run_' tags{i} '.m']) ''')']); end
        Ld = load(f); S{i} = Ld.result;
    end

    inWin = ctx.t >= cfg.t_start & ctx.t <= cfg.t_end;
    tw = ctx.t(inWin); dd = ctx.dd(inWin); dm = ctx.dm(inWin);
    stride = max(1, round(numel(tw)/6000));
    ts = tw(1:stride:end); dds = dd(1:stride:end); dms = dm(1:stride:end);

    fig = figure('Color','w','Name',['OSI overview - data ' cfg.data_id], ...
        'Position',[40 40 1280 940]);
    ax1 = subplot(4,2,1);
    plot(ax1, ts, dds, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.0, 'DisplayName','dd (reference)');
    hold(ax1,'on');
    plot(ax1, ts, dms, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.0, 'DisplayName','dm (response)');
    grid(ax1,'on'); xlim(ax1,[cfg.t_start cfg.t_end]);
    xlabel(ax1,'time (s)'); ylabel(ax1,'displacement (mm)');
    title(ax1,'Reference dd and response dm'); legend(ax1,'Location','best');

    for i = 1:nM
        ax = subplot(4,2,i+1); r = S{i};
        if numel(r.tc) <= 30, sty = {'-o','MarkerFaceColor','w'}; else, sty = {'-'}; end
        col = [0.20 0.30 0.55]; if i==7, col = [0.55 0 0.35]; end   % highlight M7
        plot(ax, r.tc, r.ncf, sty{:}, 'Color',col, 'LineWidth',1.6, ...
            'DisplayName','indicator'); hold(ax,'on');
        if isfield(r,'extra')
            for e = 1:numel(r.extra)
                plot(ax, r.tc, r.extra(e).data, '-', 'Color',[0.6 0.7 0.85], ...
                    'LineWidth',0.7, 'DisplayName', r.extra(e).name);
            end
        end
        thr = cfg.ncf_threshold; if isfield(r,'threshold'), thr = r.threshold; end
        yline(ax, r.nominal, '--', 'nominal', 'Color',[0 0.45 0.74], 'HandleVisibility','off');
        yline(ax, thr, ':', 'threshold', 'Color',[0.85 0.33 0.10], 'HandleVisibility','off');
        if isfield(r,'detect_time') && ~isnan(r.detect_time)
            xline(ax, r.detect_time, '-.', 'Color',[0.6 0 0], 'HandleVisibility','off');
        end
        grid(ax,'on'); xlim(ax,[cfg.t_start cfg.t_end]);
        xlabel(ax,'time (s)'); ylabel(ax,'NCF margin'); title(ax, short{i});
    end

    if cfg.low_freq_input
        tag = sprintf('data %s -- LOW-FREQUENCY input (dd median ~3 Hz): band [%g %g] Hz', ...
            cfg.data_id, cfg.band(1), cfg.band(2));
    else
        tag = sprintf('data %s -- broadband input: band [%g %g] Hz', cfg.data_id, cfg.band(1), cfg.band(2));
    end
    sgtitle(sprintf('OSI methods over %.0f-%.1f s   |   %s', cfg.t_start, cfg.t_end, tag), 'FontWeight','bold');

    out = fullfile(cfg.results_dir, ['all_indicators_overview_' cfg.data_id '.png']);
    saveas(fig, out);
    fprintf('data %s: saved %s\n', cfg.data_id, out);
end
rmappdata(0, 'osi_data_file');   % restore default data file for other scripts
