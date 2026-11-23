"""Build and run the actual Flutter plugin without the production app/account."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

PACKAGE = Path(__file__).resolve().parents[1]
MAIN = r"""
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:divine_desktop_video_editor/divine_desktop_video_editor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox());
  final root = await Directory.systemTemp.createTemp('divine native worker ');
  final worker = NativeMediaWorker();
  final client = worker.createClient(temporaryDirectory: () async => root);
  try {
    var rejected = false;
    try {
      await worker.claimProcess(pid);
    } on MediaWorkerFailure catch (error) {
      rejected = error.code == 'ownership';
    }
    if (!rejected) throw StateError('An unrelated process was accepted.');
    final fixture = Platform.environment['DIVINE_NATIVE_FIXTURE']!;
    await client.execute('renderVideo', {
      'videoClips': [{'inputPath': fixture, 'startUs': 250000, 'endUs': 750000}],
      'flipX': true, 'maxFrameRate': 20, 'enableAudio': true,
    }, taskId: 'synthetic-render', consume: (output) async {
      final value = output.value! as Map<String, dynamic>;
      final artifact = File(value['path'] as String);
      if (await artifact.length() == 0) throw StateError('Empty native output.');
      await artifact.copy('${root.path}/result.mp4');
    });
    if (root.listSync().length != 1) throw StateError('Job files were not retired.');
    await client.dispose();
    stdout.writeln('DIVINE_NATIVE_WORKER_SMOKE_PASS');
  } on Object catch (error) {
    stderr.writeln('DIVINE_NATIVE_WORKER_SMOKE_FAIL '
      '${error is MediaWorkerFailure ? error.code : error.runtimeType}');
    await client.dispose();
    await root.delete(recursive: true);
    exit(1);
  }
  await root.delete(recursive: true);
  exit(0);
}
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['linux', 'windows'], required=True)
    parser.add_argument('--worker', help='Run Dart transport tests against this built helper.')
    args = parser.parse_args()
    flutter = ['flutter']
    if os.name == 'nt':
        installed = shutil.which('flutter')
        if not installed:
            raise RuntimeError('Pinned Flutter SDK is missing from PATH.')
        sdk = Path(installed).resolve().parent.parent
        flutter = [str(sdk / 'bin/cache/dart-sdk/bin/dart.exe'),
                   str(sdk / 'bin/cache/flutter_tools.snapshot')]
    with tempfile.TemporaryDirectory(prefix='divine-plugin-native-') as temporary:
        root = Path(temporary)
        plugin = root / 'plugin'
        plugin.mkdir()
        for name in ['lib', 'native', 'linux', 'windows']:
            source = PACKAGE / name
            if source.exists():
                shutil.copytree(source, plugin / name)
        # Resolve this isolated build outside the app's larger pub workspace.
        (plugin / 'pubspec.yaml').write_text((PACKAGE / 'pubspec.yaml').read_text()
            .replace('resolution: workspace\n', ''), encoding='utf-8')
        if args.worker:
            shutil.copytree(PACKAGE / 'test', plugin / 'test')
            subprocess.run(flutter + ['pub', 'get'], cwd=plugin, check=True)
            subprocess.run(flutter + ['test', 'test/native_worker_smoke.dart',
                '--dart-define=DIVINE_MEDIA_WORKER=' + str(Path(args.worker).resolve())],
                cwd=plugin, check=True)
            return
        app = root / 'app'
        subprocess.run(flutter + ['create', '--empty', '--no-pub',
                        '--platforms=' + args.platform, '--project-name=worker_probe',
                        str(app)], check=True)
        (app / 'pubspec.yaml').write_text("""name: worker_probe
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  divine_desktop_video_editor:
    path: ../plugin
""", encoding='utf-8')
        (app / 'lib/main.dart').write_text(MAIN, encoding='utf-8')
        subprocess.run(flutter + ['pub', 'get'], cwd=app, check=True)
        subprocess.run(flutter + ['build', args.platform, '--debug'], cwd=app, check=True)
        if args.platform == 'linux':
            binary = app / 'build/linux/x64/debug/bundle/worker_probe'
            command = ['xvfb-run', '-a', str(binary)]
        else:
            binary = app / 'build/windows/x64/runner/Debug/worker_probe.exe'
            command = [str(binary)]
        environment = dict(os.environ, DIVINE_NATIVE_FIXTURE=str(PACKAGE / 'test/fixtures/synthetic-colors.mp4'))
        result = subprocess.run(command, cwd=app, env=environment, capture_output=True,
                                text=True, timeout=90)
        # Show only stable harness classifications, never the native stderr stream.
        for line in (result.stdout + result.stderr).splitlines():
            if line.startswith('DIVINE_NATIVE_WORKER_'):
                print(line, flush=True)
        if result.returncode != 0 or 'DIVINE_NATIVE_WORKER_SMOKE_PASS' not in result.stdout:
            raise RuntimeError('Native plugin smoke failed; exit=' + str(result.returncode))


if __name__ == '__main__':
    main()
