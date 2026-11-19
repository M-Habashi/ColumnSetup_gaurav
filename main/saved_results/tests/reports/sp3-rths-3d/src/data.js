export async function loadRun() {
  const get = async (name, type) => {
    const response = await fetch('./data/' + name);
    if (!response.ok) throw new Error('Could not load ' + name);
    return response[type]();
  };
  const [run, samples, states] = await Promise.all([
    get('run.json', 'json'), get('signals.bin', 'arrayBuffer'), get('frame.bin', 'arrayBuffer')
  ]);
  run.signals = new Float32Array(samples);
  run.frames = new Float32Array(states);
  const width = run.channels.length;
  run.at = (i, c) => run.signals[i * width + c];
  run.sample = (t, c) => {
    const k = Math.max(0, Math.min(run.samples - 1, t * run.hz));
    const i = Math.floor(k), j = Math.min(i + 1, run.samples - 1);
    return run.at(i, c) + (run.at(j, c) - run.at(i, c)) * (k - i);
  };
  run.cameraStart = (run.cameraLabStart - run.labStart) / run.timeScale;
  run.cameraEnd = run.cameraStart + run.cameraSeconds / run.timeScale;
  return run;
}
export const signed = (v, digits = 2) => (v < -0.00001 ? '−' : '+') + Math.abs(v).toFixed(digits);
export const clamp = (v, lo, hi) => Math.max(lo, Math.min(v, hi));

export function hingePhase(run,id,t){
  if(run.firstPlastic[id]!==null&&t>=run.firstPlastic[id])return 2;
  if(run.firstYield[id]!==null&&t>=run.firstYield[id])return 1;
  return 0;
}
