function s = osi_window_label(cfg)
%OSI_WINDOW_LABEL Short text describing the active windowing (for plot titles).
    if strcmp(cfg.win_mode, 'sliding')
        s = sprintf('%.1fs buf / %.1fs hop', cfg.win_buf, cfg.win_hop);
    else
        s = sprintf('%g s window', cfg.W);
    end
end
