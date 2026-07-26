/* Verify the browser port of sol_osi_simplified against MATLAB.
 *
 * docs/Sol_osi/bench2_engine.js re-runs the estimator in the reader's browser;
 * this compares its output at the committed defaults against the curves
 * make_bench2_plot_data.m wrote into bench2_data.js.  Run after either of
 * make_bench2_plot_data / make_bench2_interactive is regenerated:
 *
 *     node research/fabby_bench_2/check_bench2_interactive.js
 *
 * bench2_data.js rounds b and a to four decimals, so ~5e-5 is the floor; the
 * live scenario adds the int16 quantisation of its full-rate inputs.
 */
const fs = require('fs');
const path = require('path');

const DOCS = path.resolve(__dirname, '..', '..', 'docs', 'Sol_osi');

globalThis.window = globalThis;
for (const f of ['bench2_data.js', 'bench2_tune.js', 'bench2_engine.js']) {
  const code = fs.readFileSync(path.join(DOCS, f), 'utf8');
  (0, eval)(code);
}

const T = window.BENCH2_TUNE;
const D = window.BENCH2_DATA;

function stats(name, got, want) {
  let mx = 0, imx = 0, sum = 0;
  const n = Math.min(got.length, want.length);
  for (let i = 0; i < n; i++) {
    const d = Math.abs(got[i] - want[i]);
    if (d > mx) { mx = d; imx = i; }
    sum += d;
  }
  console.log(`  ${name.padEnd(10)} n=${n}  max|diff| = ${mx.toExponential(3)}` +
    ` at i=${imx}   mean = ${(sum / n).toExponential(3)}`);
  return mx;
}

const params = Object.assign({}, T.defaults);
params.no_evidence_prior = !!params.no_evidence_prior;

let worst = 0;
for (const key of ['gdb_replay', 'live_closed_loop']) {
  const t0 = Date.now();
  const out = window.OSISimplified.run(key, params);
  const ms = Date.now() - t0;
  const ref = D.tests.find(x => x.key === key);
  console.log(`\n${key}   (${ms} ms, ${out.b.length} updates)`);
  worst = Math.max(worst, stats('b', out.b, ref.osi.sol_osi_simplified));
  worst = Math.max(worst, stats('a', out.a, ref.auth.sol_osi_simplified));
  if (ref.has_ncf && out.b_true) {
    worst = Math.max(worst, stats('b_true', out.b_true, ref.ncf.sol_osi_simplified));
  }
}
console.log(`\nworst deviation across both scenarios: ${worst.toExponential(3)}`);
console.log(worst < 5e-3 ? 'PASS' : 'FAIL');
