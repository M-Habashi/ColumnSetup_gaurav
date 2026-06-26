function sel = osi_select_bins(f, coh, P, cfg)
%OSI_SELECT_BINS Logical mask of FRF bins to keep for the margin estimate:
% in-band AND coherent AND adequately excited. The global input-power gate
% (within cfg.input_power_range_db of the in-band peak) rejects unexcited bins
% whose FRF is corrupted by spectral leakage -- the failure mode that makes a
% low-frequency input fake a near-zero margin. P(:,1) is the input auto-spectrum.
    pdc = 10*log10(P(:,1) + eps);
    inb = f >= cfg.band(1) & f <= cfg.band(2);
    if ~any(inb), sel = false(size(f)); return, end
    sel = inb & coh >= cfg.coh_min & pdc >= max(pdc(inb)) - cfg.input_power_range_db;
end
