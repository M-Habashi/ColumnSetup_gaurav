/* sol_osi_simplified + gpt5_6_4_auth, ported to the browser.
 *
 * A line-for-line port of research/sol_osi_simplified/sol_osi_simplified.m
 * and control_and_HS/OSI/gpt5_6_4_auth.m, so the reader can move a parameter
 * and watch the same estimator re-run on the same recorded data.
 *
 * Inputs come from bench2_tune.js.  The GDBqFpKb replay is open loop, so its
 * spectra are precomputed in MATLAB; the live scenario closes the loop, so the
 * plant is stepped here and only its output is transformed.
 *
 * research/fabby_bench_2/check_bench2_interactive.js verifies this against
 * the MATLAB curves; run it whenever either data file is regenerated.
 */
(function (root) {
  'use strict';

  var EPS = 2.220446049250313e-16;
  var SQRT1_2 = Math.SQRT1_2;

  /* ---- decoding ---------------------------------------------------------- */
  function b64bytes(s) {
    var bin = typeof atob === 'function'
      ? atob(s)
      : Buffer.from(s, 'base64').toString('binary');
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }
  function f32(s) {
    var b = b64bytes(s);
    return new Float32Array(b.buffer, b.byteOffset, b.byteLength / 4);
  }
  function i16(o) {
    var b = b64bytes(o.data);
    var q = new Int16Array(b.buffer, b.byteOffset, b.byteLength / 2);
    var out = new Float64Array(q.length);
    for (var i = 0; i < q.length; i++) out[i] = q[i] * o.scale;
    return out;
  }
  function unrle(o) {
    var out = new Float64Array(o.n), k = 0;
    for (var i = 0; i < o.idx.length; i++) {
      var end = (i + 1 < o.idx.length) ? o.idx[i + 1] : o.n;
      for (k = o.idx[i]; k < end; k++) out[k] = o.val[i];
    }
    return out;
  }

  /* ---- small numerics ---------------------------------------------------- */
  // MATLAB median: even count averages the two middle values.
  function medianOf(vals) {
    var v = Array.prototype.slice.call(vals).sort(function (a, b) { return a - b; });
    var n = v.length, h = n >> 1;
    return (n % 2) ? v[h] : 0.5 * (v[h - 1] + v[h]);
  }
  function medianMasked(x, keep) {
    var v = [];
    for (var i = 0; i < x.length; i++) if (keep[i]) v.push(x[i]);
    return medianOf(v);
  }
  // MATLAB movmedian(x,3) with shrinking endpoints.
  function movmedian3(x, out) {
    var n = x.length;
    out[0] = 0.5 * (Math.min(x[0], x[1]) + Math.max(x[0], x[1]));
    for (var i = 1; i < n - 1; i++) {
      var a = x[i - 1], b = x[i], c = x[i + 1], m;
      if (a > b) { m = a; a = b; b = m; }
      if (b > c) { m = b; b = c; c = m; }
      if (a > b) { m = a; a = b; b = m; }
      out[i] = b;
    }
    out[n - 1] = 0.5 * (Math.min(x[n - 2], x[n - 1]) + Math.max(x[n - 2], x[n - 1]));
    return out;
  }
  function chordal(re, im, cap) {
    var m = Math.hypot(1 + re, im) / Math.sqrt(2 * (1 + re * re + im * im));
    return m < cap ? m : cap;
  }

  /* ---- radix-2 FFT (in place, complex) ----------------------------------- */
  function makeFFT(n) {
    var levels = Math.round(Math.log2(n));
    var cos = new Float64Array(n / 2), sin = new Float64Array(n / 2);
    for (var i = 0; i < n / 2; i++) {
      cos[i] = Math.cos(2 * Math.PI * i / n);
      sin[i] = Math.sin(2 * Math.PI * i / n);
    }
    var rev = new Uint32Array(n);
    for (var j = 0; j < n; j++) {
      var x = j, y = 0;
      for (var b = 0; b < levels; b++) { y = (y << 1) | (x & 1); x >>= 1; }
      rev[j] = y;
    }
    return function (re, im) {
      var i, j, k, t;
      for (i = 0; i < n; i++) {
        j = rev[i];
        if (j > i) {
          t = re[i]; re[i] = re[j]; re[j] = t;
          t = im[i]; im[i] = im[j]; im[j] = t;
        }
      }
      for (var size = 2; size <= n; size *= 2) {
        var half = size / 2, step = n / size;
        for (i = 0; i < n; i += size) {
          for (j = i, k = 0; j < i + half; j++, k += step) {
            var l = j + half;
            var tre = re[l] * cos[k] + im[l] * sin[k];
            var tim = -re[l] * sin[k] + im[l] * cos[k];
            re[l] = re[j] - tre; im[l] = im[j] - tim;
            re[j] += tre; im[j] += tim;
          }
        }
      }
    };
  }

  /* ---- configuration ----------------------------------------------------- */
  // Mirrors makeConfig: the derived quantities that depend on a tunable.
  function buildCfg(base, p) {
    var nb = base.freq_hz.length;
    var c = {
      nb: nb,
      cap: base.cap,
      step_s: base.step_s,
      step_n: base.step_n,
      segment_n: base.segment_n,
      reference_stride: base.reference_stride,
      keep: base.keep,
      L0re: base.L0re, L0im: base.L0im,
      shape: base.shape,
      rho_grid: base.rho_grid,
      p: p
    };
    c.spectral_alpha = 1 - Math.exp(-base.step_s / p.memory_s);
    c.margin_alpha = 1 - Math.exp(-base.step_s / p.margin_s);
    c.residual_alpha = 1 - Math.exp(-base.step_s / p.residual_s);
    c.drive_alpha = 1 - Math.exp(-base.step_s / p.warm_s);
    c.recover_alpha = 1 - Math.exp(-base.step_s / p.rho_recover_s);
    c.power_floor = Math.pow(10, -p.power_floor_db / 10);
    c.warm_steps = Math.round(p.warm_s / base.step_s);
    // |1+L0|^2, reused by every rho grid point
    c.num = new Float64Array(nb);
    for (var i = 0; i < nb; i++) {
      var re = 1 + base.L0re[i], im = base.L0im[i];
      c.num[i] = re * re + im * im;
    }
    return c;
  }

  function newState(cfg) {
    var nb = cfg.nb;
    return {
      samples_in: 0, step_count: 0, spectral_count: 0,
      Suu: new Float64Array(nb), Syy: new Float64Array(nb),
      Sre: new Float64Array(nb), Sim: new Float64Array(nb),
      q_ref_samples: [new Float64Array(nb), new Float64Array(nb), new Float64Array(nb)],
      q_ref: new Float64Array(nb), q_ref_count: 0,
      reference_ratio: 1, log_rho: new Float64Array(nb),
      rho_drive: 1, ratio_prev: 0, b: cfg.cap, a_cmd: 1,
      // scratch
      _c: new Float64Array(nb), _bst: new Float64Array(nb),
      _bstm: new Float64Array(nb), _brho: new Float64Array(nb),
      _brhom: new Float64Array(nb), _bprior: new Float64Array(nb),
      _rho: new Float64Array(nb), _wres: new Float64Array(nb),
      _qobs: new Float64Array(nb), _qmod: new Float64Array(nb),
      _loss: new Float64Array(nb), _kbest: new Int32Array(nb),
      _Lre: new Float64Array(nb), _Lim: new Float64Array(nb)
    };
  }

  /* ---- one estimator update ---------------------------------------------- */
  // spec: {pu, py, cre, cim} views of length nb, plus urms.
  function osiStep(st, cfg, spec, urms) {
    var p = cfg.p, nb = cfg.nb, i, k;
    var keep = cfg.keep, cap = cfg.cap;

    st.samples_in = Math.min(cfg.segment_n, st.samples_in + cfg.step_n);
    st.step_count += 1;

    var activity = urms > p.eta_A ? 1 : 0;
    var activation_weight = p.hard_activity_gain * activity;
    var a_now = Math.min(Math.max(st.a_cmd, 0.02), 1);

    var bprior = st._bprior, b_prior = Infinity;
    for (i = 0; i < nb; i++) {
      bprior[i] = chordal(a_now * cfg.L0re[i], a_now * cfg.L0im[i], cap);
      if (keep[i] && bprior[i] < b_prior) b_prior = bprior[i];
    }

    if (st.samples_in < cfg.segment_n) {
      st.b += activity * cfg.margin_alpha * (b_prior - st.b);
      return { b: st.b, residual_weight: 0 };
    }

    // q_ref: three samples, one per full segment, then their median
    if (st.q_ref_count < 3 && st.step_count % cfg.reference_stride === 0) {
      st.q_ref_samples[st.q_ref_count].set(spec.py);
      st.q_ref_count += 1;
      if (st.q_ref_count === 3) {
        for (i = 0; i < nb; i++) {
          st.q_ref[i] = medianOf([st.q_ref_samples[0][i],
            st.q_ref_samples[1][i], st.q_ref_samples[2][i]]);
        }
      }
    }
    if (st.spectral_count === 0) {
      st.Suu.set(spec.pu); st.Syy.set(spec.py);
      st.Sre.set(spec.cre); st.Sim.set(spec.cim);
    } else {
      var q = cfg.spectral_alpha;
      for (i = 0; i < nb; i++) {
        st.Suu[i] += q * (spec.pu[i] - st.Suu[i]);
        st.Syy[i] += q * (spec.py[i] - st.Syy[i]);
        st.Sre[i] += q * (spec.cre[i] - st.Sre[i]);
        st.Sim[i] += q * (spec.cim[i] - st.Sim[i]);
      }
    }
    st.spectral_count += 1;

    /* branch 1: identification */
    var maxSuu = 0;
    for (i = 0; i < nb; i++) if (st.Suu[i] > maxSuu) maxSuu = st.Suu[i];
    var conf = st._c, Lre = st._Lre, Lim = st._Lim, bst = st._bst;
    var Tpre, Tpim;
    for (i = 0; i < nb; i++) {
      var s2 = st.Sre[i] * st.Sre[i] + st.Sim[i] * st.Sim[i];
      var g2 = Math.min(1, s2 / Math.max(st.Suu[i] * st.Syy[i], EPS));
      var p_rel = st.Suu[i] / Math.max(maxSuu, EPS);
      var lev = p_rel / (p_rel + cfg.power_floor);
      conf[i] = activity * g2 * lev;
      var den0 = Math.max(st.Suu[i], EPS);
      var Thre = st.Sre[i] / den0, Thim = st.Sim[i] / den0;
      // prior transfer a*L0/(1+a*L0)
      var lr = a_now * cfg.L0re[i], li = a_now * cfg.L0im[i];
      var dr = 1 + lr, di = li, dd = dr * dr + di * di;
      var tpr = (lr * dr + li * di) / dd, tpi = (li * dr - lr * di) / dd;
      Tpre = conf[i] * Thre + (1 - conf[i]) * tpr;
      Tpim = conf[i] * Thim + (1 - conf[i]) * tpi;
      var er = 1 - Tpre, ei = -Tpim;
      var mag = Math.hypot(er, ei);
      if (mag < 0.02) {
        var ang = Math.atan2(ei, er + EPS);
        er = 0.02 * Math.cos(ang); ei = 0.02 * Math.sin(ang);
      }
      var ed = er * er + ei * ei;
      Lre[i] = (Tpre * er + Tpim * ei) / ed;
      Lim[i] = (Tpim * er - Tpre * ei) / ed;
      bst[i] = chordal(Lre[i], Lim[i], cap);
    }
    var bstm = movmedian3(bst, st._bstm);

    /* branch 2: observation */
    var drive_ratio = 1;
    var rho_best_arr = new Float64Array(nb);
    for (i = 0; i < nb; i++) rho_best_arr[i] = 1;

    if (st.step_count > cfg.warm_steps) {
      var qobs = st._qobs;
      if (st.q_ref_count === 3) {
        for (i = 0; i < nb; i++) qobs[i] = st.Syy[i] / Math.max(st.q_ref[i], EPS);
        st.reference_ratio = medianMasked(qobs, keep);
        var d0 = Math.max(Math.pow(medianMasked(qobs, keep), p.reference_level_beta), EPS);
        for (i = 0; i < nb; i++) qobs[i] /= d0;
      } else {
        for (i = 0; i < nb; i++) qobs[i] = st.Syy[i] / cfg.shape[i];
        var d1 = Math.max(medianMasked(qobs, keep), EPS);
        for (i = 0; i < nb; i++) qobs[i] /= d1;
      }
      var best = new Float64Array(nb);
      for (i = 0; i < nb; i++) best[i] = Infinity;
      var qm = st._qmod, logq = st._loss;
      for (i = 0; i < nb; i++) logq[i] = Math.log(Math.max(qobs[i], EPS));
      for (k = 0; k < cfg.rho_grid.length; k++) {
        var ar = a_now * cfg.rho_grid[k];
        for (i = 0; i < nb; i++) {
          var qr = 1 + ar * cfg.L0re[i], qi = ar * cfg.L0im[i];
          qm[i] = cfg.num[i] / (qr * qr + qi * qi);
        }
        var mm = st.q_ref_count === 3
          ? Math.max(Math.pow(medianMasked(qm, keep), p.reference_level_beta), EPS)
          : Math.max(medianMasked(qm, keep), EPS);
        for (i = 0; i < nb; i++) {
          if (!keep[i]) continue;
          var L = Math.abs(logq[i] - Math.log(Math.max(qm[i] / mm, EPS)));
          if (L < best[i]) { best[i] = L; rho_best_arr[i] = cfg.rho_grid[k]; }
        }
      }
      var wsum = 0, dsum = 0;
      for (i = 0; i < nb; i++) {
        var w = conf[i] * conf[i];
        var mr = a_now * cfg.L0re[i], mi = a_now * cfg.L0im[i];
        wsum += w * (mr * Lre[i] + mi * Lim[i]);
        dsum += w * (mr * mr + mi * mi);
      }
      var rho_drive = Math.max(wsum / Math.max(dsum, EPS), EPS);
      var raw_kick = Math.max(rho_drive / st.rho_drive - 1, 0);
      var kick = Math.min(Math.min(raw_kick, st.ratio_prev), p.detector_max - 1);
      st.ratio_prev = raw_kick;
      drive_ratio = 1 + activation_weight * kick;
      st.rho_drive += cfg.drive_alpha * (rho_drive - st.rho_drive);
      var coherent_weight = Math.min(Math.max(2 * (rho_drive - 1), 0), 1);
      var level_weight = Math.max(
        1 - p.level_fit_start_ratio / Math.max(st.reference_ratio, EPS), 0);
      var eff_floor = p.fit_floor + p.level_fit_gain * level_weight;
      var shape_weight = coherent_weight + eff_floor * activity * (1 - coherent_weight);
      var alpha_rho = activity * cfg.residual_alpha;
      for (i = 0; i < nb; i++) {
        var rt = 1 + shape_weight * (rho_best_arr[i] - 1);
        st.log_rho[i] += alpha_rho * (Math.log(rt) - st.log_rho[i]);
      }
    }
    var forgetting = st.reference_ratio < 1 ? 1 : 0;
    var decay = 1 - cfg.recover_alpha * forgetting;
    var rho = st._rho;
    for (i = 0; i < nb; i++) {
      st.log_rho[i] *= decay;
      rho[i] = Math.exp(st.log_rho[i]) * drive_ratio;
    }

    /* fusion: per bin, then trim one isolated low bin */
    var brho = st._brho;
    for (i = 0; i < nb; i++) {
      var s = a_now * rho[i];
      brho[i] = chordal(s * cfg.L0re[i], s * cfg.L0im[i], cap);
    }
    var brhom = movmedian3(brho, st._brhom);
    var lowest = Infinity, lowestGov = 0;
    var b_raw = Infinity, gov = 0, wres = st._wres;
    for (i = 0; i < nb; i++) {
      var det = Math.min(Math.max((rho[i] - 1) / (p.rho_detect - 1), 0), 1);
      var w_st = conf[i];
      wres[i] = (1 - conf[i]) * det;
      var no_ev = p.no_evidence_prior ? bprior[i] : cap;
      var bb = w_st * bstm[i] + wres[i] * brhom[i] + (1 - w_st - wres[i]) * no_ev;
      if (keep[i] && bb < lowest) {
        b_raw = lowest; gov = lowestGov;
        lowest = bb; lowestGov = i;
      } else if (keep[i] && bb < b_raw) {
        b_raw = bb; gov = i;
      }
    }
    st.b += cfg.margin_alpha * (b_raw - st.b);
    var b = Math.min(Math.max(st.b, 0), cap);
    return { b: b, residual_weight: wres[gov] };
  }

  /* ---- authority regulator ----------------------------------------------- */
  function authStep(b, rw, ast, prm) {
    rw = Math.min(Math.max(rw, 0), 1);
    var a0 = Math.min(Math.max(ast.a, prm.a_min), prm.a_max);
    var b_ref = prm.target + prm.guard * (1 + rw);
    var e_raw = b - b_ref;
    var db = prm.deadband * (1 + rw);
    var em = Math.sign(e_raw) * Math.max(Math.abs(e_raw) - db, 0);
    var e = Math.min(em, 0) + Math.pow(b_ref * Math.SQRT2, 2) * Math.max(em, 0);
    var la = Math.log(a0) + prm.rate * Math.sqrt(a0) * prm.dt_update * e;
    var af = Math.exp(Math.min(Math.max(la, Math.log(prm.a_min)), Math.log(prm.a_max)));
    ast.a = a0 + Math.min(Math.max(af - a0, -prm.max_step), prm.max_step);
    return ast.a;
  }

  /* ---- scenario runners --------------------------------------------------- */
  var cache = {};
  function decode(test, key) {
    if (!cache[key]) {
      cache[key] = {
        pu: f32(test.pu), py: test.py ? f32(test.py) : null,
        cre: test.cre ? f32(test.cre) : null,
        cim: test.cim ? f32(test.cim) : null,
        ure: test.ure ? f32(test.ure) : null,
        uim: test.uim ? f32(test.uim) : null,
        urms: f32(test.urms),
        ref: test.ref ? i16(test.ref) : null,
        noise: test.noise ? i16(test.noise) : null,
        gain_full: test.gain_full ? unrle(test.gain_full) : null
      };
    }
    return cache[key];
  }

  function runOpen(test, key, cfg, prm) {
    var d = decode(test, key), nb = cfg.nb, n = test.n;
    var st = newState(cfg), ast = { a: prm.a_init };
    var b = new Float64Array(n), a = new Float64Array(n);
    var spec = {};
    var acur = prm.a_init;
    for (var k = 0; k < n; k++) {
      var o = k * nb;
      spec.pu = d.pu.subarray(o, o + nb);
      spec.py = d.py.subarray(o, o + nb);
      spec.cre = d.cre.subarray(o, o + nb);
      spec.cim = d.cim.subarray(o, o + nb);
      st.a_cmd = acur;
      var r = osiStep(st, cfg, spec, d.urms[k]);
      acur = authStep(r.b, r.residual_weight, ast, prm);
      b[k] = r.b; a[k] = acur;
    }
    return { t: test.t, b: b, a: a };
  }

  function runClosed(test, key, cfg, prm) {
    var d = decode(test, key), nb = cfg.nb, n = test.n, N = test.N;
    var np = test.np, nc = test.nc, blk = cfg.step_n, sn = cfg.segment_n;
    var st = newState(cfg), ast = { a: prm.a_init };
    var b = new Float64Array(n), a = new Float64Array(n), bT = new Float64Array(n);
    var dm = new Float64Array(N);
    var xp = new Float64Array(np), xc = new Float64Array(nc);
    var xpn = new Float64Array(np), xcn = new Float64Array(nc);
    var buf = new Float64Array(sn);
    var fre = new Float64Array(sn), fim = new Float64Array(sn);
    var fft = makeFFT(sn);
    var py = new Float64Array(nb), cre = new Float64Array(nb), cim = new Float64Array(nb);
    var spec = { py: py, cre: cre, cim: cim };
    var win = cfg.window, acur = prm.a_init, ib = 0, ku = 0, i, j;
    var nL = test.L5fre.length;

    for (var k = 0; k < N; k++) {
      var y = 0;
      for (i = 0; i < np; i++) y += test.Cp[i] * xp[i];
      var dmk = y + d.noise[k];
      var e = d.ref[k] - dmk;
      var u = test.Dc * e;
      for (i = 0; i < nc; i++) u += test.Cc[i] * xc[i];
      for (i = 0; i < nc; i++) {
        var s = test.Bc[i] * e;
        for (j = 0; j < nc; j++) s += test.Ac[j * nc + i] * xc[j];
        xcn[i] = s;
      }
      xc.set(xcn);
      var dck = Math.min(Math.max(d.gain_full[k] * acur * u, -test.dc_sat), test.dc_sat);
      for (i = 0; i < np; i++) {
        var sp = test.Bp[i] * dck;
        for (j = 0; j < np; j++) sp += test.Ap[j * np + i] * xp[j];
        xpn[i] = sp;
      }
      xp.set(xpn);
      dm[k] = dmk;
      buf[sn - blk + ib] = dmk;
      ib += 1;
      if (ib === blk) {
        ib = 0;
        // FFT of the windowed dm buffer; U was precomputed
        for (i = 0; i < sn; i++) { fre[i] = buf[i] * win[i]; fim[i] = 0; }
        fft(fre, fim);
        var o = ku * nb;
        for (i = 0; i < nb; i++) {
          var bi = i + 1;                       // bins 2..100 Hz, df = 2 Hz
          var yr = fre[bi], yi = fim[bi];
          py[i] = yr * yr + yi * yi;
          var ur = d.ure[o + i], ui = d.uim[o + i];
          cre[i] = yr * ur + yi * ui;
          cim[i] = yi * ur - yr * ui;
        }
        spec.pu = d.pu.subarray(o, o + nb);
        st.a_cmd = acur;
        var r = osiStep(st, cfg, spec, d.urms[ku]);
        acur = authStep(r.b, r.residual_weight, ast, prm);
        b[ku] = r.b; a[ku] = acur;
        var g = d.gain_full[k] * acur, bmin = Infinity;
        for (i = 0; i < nL; i++) {
          var lr = g * test.L5fre[i], li = g * test.L5fim[i];
          var v = Math.hypot(1 + lr, li) / Math.sqrt(2 * (1 + lr * lr + li * li));
          if (v < bmin) bmin = v;
        }
        bT[ku] = bmin;
        ku += 1;
        buf.copyWithin(0, blk);
      }
    }
    return { t: test.t, b: b, a: a, b_true: bT, dm: dm };
  }

  function run(name, params) {
    var T = root.BENCH2_TUNE;
    var cfg = buildCfg(T.cfg, params);
    cfg.window = f32(T.cfg.window);
    var test = T.tests[name];
    var prm = T.auth;
    return test.mode === 'closed'
      ? runClosed(test, name, cfg, prm)
      : runOpen(test, name, cfg, prm);
  }

  root.OSISimplified = { run: run, buildCfg: buildCfg, osiStep: osiStep, authStep: authStep };
})(typeof window !== 'undefined' ? window : globalThis);
