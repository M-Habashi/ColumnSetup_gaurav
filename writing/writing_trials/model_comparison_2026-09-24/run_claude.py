"""Run fresh tool-free Claude print sessions and retain model provenance."""
import argparse
import concurrent.futures
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parent

def run_one(run_id, prompt_path=None, output_dir=None):
    prompt_file = Path(prompt_path) if prompt_path else ROOT / 'packets' / f'{run_id}.txt'
    destination = Path(output_dir) if output_dir else ROOT / 'claude' / run_id
    destination.mkdir(parents=True, exist_ok=True)
    cli = shutil.which('claude')
    if not cli:
        raise RuntimeError('Claude executable not found')
    args = [cli, '-p', '--model', 'claude-opus-5-5', '--effort', 'high',
            '--safe-mode', '--tools', '', '--strict-mcp-config',
            '--no-session-persistence', '--output-format', 'json']
    print(f'{run_id}: started fresh Opus 5.5 high session', flush=True)
    start = time.monotonic()
    result = subprocess.run(args, input=prompt_file.read_text(encoding='utf-8-sig'),
                            text=True, encoding='utf-8', capture_output=True,
                            timeout=900, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    duration = time.monotonic() - start
    (destination / 'raw.json').write_text(result.stdout, encoding='utf-8')
    (destination / 'stderr.txt').write_text(result.stderr, encoding='utf-8')
    data = json.loads(result.stdout)
    if result.returncode or data.get('is_error'):
        raise RuntimeError(f'{run_id}: CLI failed, inspect raw.json and stderr.txt')
    model_usage = data.get('modelUsage', {})
    if 'claude-opus-5-5' not in model_usage:
        raise RuntimeError(f'{run_id}: requested model not confirmed in modelUsage')
    (destination / 'response.md').write_text(data['result'], encoding='utf-8')
    metadata = dict(run_id=run_id, requested_model='claude-opus-5-5', effort='high',
                    command=args, session_id=data.get('session_id'),
                    seconds=duration, total_cost_usd=data.get('total_cost_usd'),
                    model_usage=model_usage, permission_denials=data.get('permission_denials'),
                    turns=data.get('num_turns'), prompt_path=str(prompt_file))
    (destination / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print(f'{run_id}: completed in {duration:.1f}s, model confirmed', flush=True)
    return metadata

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ids', nargs='+')
    parser.add_argument('--prompt')
    parser.add_argument('--output')
    args = parser.parse_args()
    if args.prompt:
        run_one('review', args.prompt, args.output)
    else:
        runs = json.loads((ROOT / 'manifest.json').read_text(encoding='utf-8-sig'))
        ids = args.ids or [run['id'] for run in runs]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {pool.submit(run_one, run_id): run_id for run_id in ids}
            for future in concurrent.futures.as_completed(futures):
                future.result()
