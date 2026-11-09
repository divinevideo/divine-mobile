#!/usr/bin/env python3
"""Run consent acceptance with a pinned Worker and disposable local D1/R2."""
import argparse
import os
from pathlib import Path
import queue
import shutil
import subprocess
import tempfile
import threading


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('backend', type=Path, help='Exact relay-manager candidate checkout/snapshot')
    parser.add_argument('--native', action='store_true', help='Exercise the production capture screen on a booted Android emulator')
    args = parser.parse_args()
    backend = args.backend.resolve()
    if not (backend / 'worker/node_modules/miniflare').is_dir():
        parser.error('Run npm ci in the candidate worker directory first')
    flutter = shutil.which('flutter')
    if not flutter:
        parser.error('Put the repository pinned Flutter SDK on PATH')
    repo = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='consent-acceptance-') as temporary:
        log = Path(os.environ.get('RUNNER_TEMP', temporary)) / 'consent-worker.log'
        ready = queue.Queue()
        server = subprocess.Popen(
            ['node', str(Path(__file__).with_name('server.mjs')), str(backend)],
            cwd=repo, env={**os.environ, 'CONSENT_TEST_PORT': '48787' if args.native else '0'},
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )

        def capture():
            with log.open('w') as output:
                for line in server.stdout:
                    output.write(line)
                    output.flush()
                    if line.startswith('CONSENT_ACCEPTANCE_READY '):
                        ready.put(line.strip().split(' ', 1)[1])
            ready.put(None)

        reader = threading.Thread(target=capture, daemon=True)
        reader.start()
        try:
            try:
                endpoint = ready.get(timeout=30)
            except queue.Empty:
                endpoint = None
            if not endpoint:
                raise RuntimeError(f'Local Worker did not become ready:\n{log.read_text()}')
            if args.native:
                subprocess.run(['adb', 'reverse', 'tcp:48787', 'tcp:48787'], check=True)
                result = subprocess.run(
                    ['bash', 'local_stack/profile.sh', 'integration_test/consent/native_consent_capture_test.dart'],
                    cwd=repo,
                    env={**os.environ, 'E2E_BACKEND_LOG': str(log),
                         'E2E_TEST_PERMISSIONS': 'android.permission.CAMERA android.permission.RECORD_AUDIO'},
                    check=False,
                )
            else:
                result = subprocess.run(
                    [flutter, 'test', '--no-pub', 'tool/consent_acceptance.dart',
                     f'--dart-define=CONSENT_ACCEPTANCE_URL={endpoint}', '--reporter=expanded'],
                    cwd=repo / 'mobile', check=False,
                )
            if result.returncode:
                raise SystemExit(result.returncode)
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
            reader.join(timeout=5)


if __name__ == '__main__':
    main()
