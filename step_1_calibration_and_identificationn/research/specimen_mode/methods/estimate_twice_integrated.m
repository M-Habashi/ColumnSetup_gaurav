function fit = estimate_twice_integrated(D, ~)
ix = cumtrapz(D.t, D.x);
iix = cumtrapz(D.t, ix);
iiF = cumtrapz(D.t, cumtrapz(D.t, D.F));

X = [D.x ix iix ones(size(D.x)) D.t];
p = X \ iiF;
fit = pack_fit('Twice Integrated', p);
end
