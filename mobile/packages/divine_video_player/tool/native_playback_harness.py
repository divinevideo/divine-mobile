"""Verify actual desktop video surfaces with synthetic local and HTTP media."""
import argparse
import contextlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

PACKAGE = Path(__file__).resolve().parents[1]
MARKERS = {
    'DIVINE_PLAYBACK_LOCAL_PIXELS_PASS',
    'DIVINE_PLAYBACK_HTTP_PIXELS_PASS',
    'DIVINE_PLAYBACK_INVALID_SOURCE_PASS',
    'DIVINE_PLAYBACK_PASS',
}
MAIN = r"""import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:divine_video_player/divine_video_player.dart';

class ProbeFailure implements Exception {
  ProbeFailure(this.code);
  final String code;
}

enum FrameColor { green, red, blue }

Future<void> checkPixels(GlobalKey key, FrameColor color) async {
  final deadline = Stopwatch()..start();
  while (deadline.elapsed < const Duration(seconds: 10)) {
    SchedulerBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 3),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      if (image.width != 128 || image.height != 240)
        throw ProbeFailure('surface_size');
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) throw ProbeFailure('pixel_readback');
      var matches = true;
      for (final point in [(32, 60), (64, 120), (96, 180)]) {
        final offset = (point.$2 * image.width + point.$1) * 4;
        final r = bytes.getUint8(offset);
        final g = bytes.getUint8(offset + 1);
        final b = bytes.getUint8(offset + 2);
        matches =
            matches &&
            switch (color) {
              FrameColor.green => g > 80 && r < 40 && b < 40,
              FrameColor.red => r > 180 && g < 40 && b < 40,
              FrameColor.blue => b > 180 && r < 40 && g < 40,
            };
      }
      if (matches) return;
    } finally {
      image.dispose();
    }
  }
  throw ProbeFailure('pixels_${color.name}');
}

Future<int> respond(HttpRequest request, List<int> data) async {
  var bytes = 0;
  try {
    if (request.uri.path != '/synthetic.mp4') {
      request.response.statusCode = HttpStatus.notFound;
    } else if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    } else {
      var start = 0;
      var end = data.length - 1;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      var valid = true;
      if (range != null) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        if (match == null ||
            (match.group(1)!.isEmpty && match.group(2)!.isEmpty)) {
          valid = false;
        } else if (match.group(1)!.isEmpty) {
          final suffix = int.parse(match.group(2)!);
          valid = suffix > 0;
          start = (data.length - suffix).clamp(0, data.length);
        } else {
          start = int.parse(match.group(1)!);
          if (match.group(2)!.isNotEmpty) end = int.parse(match.group(2)!);
          end = end.clamp(0, data.length - 1);
          valid = start <= end;
        }
      }
      if (!valid) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${data.length}',
        );
      } else {
        if (range != null) {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${data.length}',
          );
        }
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.contentLength = end - start + 1;
        if (request.method != 'HEAD') {
          request.response.add(data.sublist(start, end + 1));
          bytes = end - start + 1;
        }
      }
    }
  } finally {
    await request.response.close();
  }
  return bytes;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var frameworkErrors = 0;
  FlutterError.onError = (_) {
    frameworkErrors++;
  };
  ui.PlatformDispatcher.instance.onError = (_, _) {
    frameworkErrors++;
    return true;
  };
  runApp(const SizedBox());
  final controller = DivineVideoPlayerController();
  HttpServer? server;
  Directory? invalidFixture;
  StreamSubscription<HttpRequest>? subscription;
  final pending = <Future<void>>{};
  var httpErrors = 0;
  var requests = 0;
  var servedBytes = 0;
  var passed = false;
  var failure = 'unexpected';
  var stage = 'initialization';
  final hold = Platform.environment['DIVINE_PLAYBACK_HOLD'];
  try {
    await controller.initialize().timeout(const Duration(seconds: 20));
    if (!controller.usesLinuxBackend)
      throw ProbeFailure('desktop_registration');
    final key = GlobalKey();
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xffff00ff),
          child: Center(
            child: SizedBox(
              width: 128,
              height: 240,
              child: RepaintBoundary(
                key: key,
                child: DivineVideoPlayer(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    final local = File(Platform.environment['DIVINE_PLAYBACK_LOCAL']!);
    stage = 'local_load';
    await controller.setSource(VideoClip(uri: local.uri.toString()));
    await controller.setLooping(looping: true);
    await controller.play();
    if (!await controller.firstFrameRendered.timeout(
      const Duration(seconds: 15),
    )) {
      throw ProbeFailure('local_frame');
    }
    stage = 'local_pixels';
    await checkPixels(key, FrameColor.green);
    stdout.writeln('DIVINE_PLAYBACK_LOCAL_PIXELS_PASS');

    final remote = File(Platform.environment['DIVINE_PLAYBACK_HTTP']!);
    final data = await remote.readAsBytes();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    subscription = server.listen((request) {
      requests++;
      late final Future<void> handler;
      handler = respond(request, data)
          .then((bytes) {
            servedBytes += bytes;
          })
          .catchError((Object error, StackTrace stack) {
            httpErrors++;
          });
      pending.add(handler);
      unawaited(
        handler.whenComplete(() {
          pending.remove(handler);
        }),
      );
    });
    await controller.pause();
    stage = 'http_load';
    await controller.setSource(
      VideoClip.network('http://127.0.0.1:${server.port}/synthetic.mp4'),
    );
    stage = 'http_frame';
    if (!await controller.firstFrameRendered.timeout(
      const Duration(seconds: 15),
    )) {
      throw ProbeFailure('http_frame');
    }
    stage = 'http_red';
    await checkPixels(key, FrameColor.red);
    if (controller.state.status == PlaybackStatus.playing ||
        controller.state.position != Duration.zero) {
      throw ProbeFailure('paused_source_advanced');
    }
    final advancing = controller.stateStream.firstWhere(
      (state) =>
          state.position >= const Duration(milliseconds: 2100) &&
          state.status == PlaybackStatus.playing,
    );
    await controller.play();
    stage = 'http_progress';
    await advancing.timeout(const Duration(seconds: 10));
    stage = 'http_blue';
    await checkPixels(key, FrameColor.blue);
    if (requests == 0 || servedBytes == 0) throw ProbeFailure('http_unused');
    stdout.writeln('DIVINE_PLAYBACK_HTTP_PIXELS_PASS');

    // A known duration bypasses metadata probing so the active renderer must
    // reject the source. Decoder failures must remain observable.
    invalidFixture = await Directory.systemTemp.createTemp(
      'divine-invalid-video-',
    );
    final invalid = File('${invalidFixture.path}/invalid.mp4');
    await invalid.writeAsString('Synthetic invalid video.');
    stage = 'invalid_load';
    final rejected = controller.stateStream.firstWhere(
      (state) => state.status == PlaybackStatus.error,
    );
    await controller.setSource(
      VideoClip(uri: invalid.uri.toString(), end: const Duration(seconds: 1)),
    );
    final invalidFrame = controller.firstFrameRendered;
    await rejected.timeout(const Duration(seconds: 10));
    if (controller.state.isFirstFrameRendered)
      throw ProbeFailure('invalid_frame');
    await controller.stop();
    if (await invalidFrame.timeout(const Duration(seconds: 5))) {
      throw ProbeFailure('invalid_frame');
    }
    stdout.writeln('DIVINE_PLAYBACK_INVALID_SOURCE_PASS');
    if (frameworkErrors != 0) throw ProbeFailure('framework');
    passed = true;
    if (hold != null) {
      final gate = File(hold);
      stdout.writeln('DIVINE_PLAYBACK_READY_FOR_RELOAD');
      if (!await gate.exists()) {
        await gate.parent
            .watch()
            .firstWhere((_) => gate.existsSync())
            .timeout(const Duration(seconds: 30));
      }
    }
  } on ProbeFailure catch (error) {
    failure = error.code;
  } on TimeoutException {
    failure = 'timeout';
  } on Object {
    // Native errors can include paths or stream metadata. Expose the fixed
    // classification only, while still failing the owned probe process.
    failure = 'native';
  } finally {
    try {
      await controller.dispose();
    } on Object {
      passed = false;
      failure = 'dispose';
    }
    try {
      await server?.close(force: true);
    } on Object {
      passed = false;
      failure = 'server_close';
    }
    try {
      await subscription?.cancel();
    } on Object {
      passed = false;
      failure = 'subscription';
    }
    await Future.wait(pending.toList());
    try {
      await invalidFixture?.delete(recursive: true);
    } on Object {
      passed = false;
      failure = 'fixture_cleanup';
    }
  }
  if (httpErrors != 0) {
    passed = false;
    failure = 'http_handler';
  }
  if (frameworkErrors != 0) {
    passed = false;
    failure = 'framework';
  }
  if (!passed) {
    stderr.writeln('DIVINE_PLAYBACK_FAIL $stage $failure');
    exit(1);
  }
  stdout.writeln('DIVINE_PLAYBACK_PASS');
  if (hold != null) {
    runApp(const SizedBox());
    stdout.writeln('DIVINE_PLAYBACK_RETIRED');
  } else {
    exit(0);
  }
}
"""


def flutter_command():
    installed = shutil.which('flutter')
    if not installed:
        raise RuntimeError('Pinned Flutter SDK is missing from PATH.')
    if os.name == 'nt':
        sdk = Path(installed).resolve().parent.parent
        command = [str(sdk / 'bin/cache/dart-sdk/bin/dart.exe'),
                   str(sdk / 'bin/cache/flutter_tools.snapshot')]
    else:
        command = [installed]
    version = json.loads(subprocess.check_output(command + ['--version', '--machine'], text=True))
    if version['frameworkVersion'] != '3.47.9':
        raise RuntimeError('Native playback validation requires Flutter 3.47.9.')
    return command


def hosted_versions(path):
    result = {}
    name = None
    fields = {}
    for line in path.read_text().splitlines() + ['  end:']:
        if line.startswith('  ') and not line.startswith('   ') and line.endswith(':'):
            if name and fields.get('source') == 'hosted':
                result[name] = tuple(fields.get(key) for key in ['version', 'url', 'sha256'])
            name = line.strip()[:-1]
            fields = {}
        elif name and ':' in line:
            key, value = line.strip().split(':', 1)
            if key in ['source', 'version', 'url', 'sha256']:
                fields[key] = value.strip().strip('"')
    return result


def copy_package(source, destination):
    shutil.copytree(source, destination, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('.dart_tool', 'build', 'coverage'))
    pubspec = destination / 'pubspec.yaml'
    pubspec.write_text(pubspec.read_text().replace('resolution: workspace\n', ''),
                       encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['linux', 'windows'], required=True)
    parser.add_argument('--workspace', type=Path)
    args = parser.parse_args()
    flutter = flutter_command()
    workspace = contextlib.nullcontext(str(args.workspace)) if args.workspace else tempfile.TemporaryDirectory(prefix='divine-playback-')
    with workspace as temporary:
        root = Path(temporary).resolve()
        root.mkdir(parents=True, exist_ok=True)
        for name in ['divine_video_player', 'unified_logger', 'logging_types']:
            copy_package(PACKAGE.parent / name, root / name)
        app = root / 'app'
        if not app.exists():
            subprocess.run(flutter + ['create', '--empty', '--no-pub',
                '--platforms=' + args.platform, '--project-name=playback_probe', str(app)], check=True)
        (app / 'pubspec.yaml').write_text('''name: playback_probe
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  divine_video_player:
    path: ../divine_video_player
''', encoding='utf-8')
        (app / 'lib/main.dart').write_text(MAIN, encoding='utf-8')
        (app / 'analysis_options.yaml').write_text(
            'linter:\n  rules:\n    discarded_futures: true\n    unawaited_futures: true\n', encoding='utf-8')
        lock = PACKAGE.parents[1] / 'pubspec.lock'
        if not lock.is_file():
            raise RuntimeError('The application dependency lockfile is required.')
        shutil.copyfile(lock, app / 'pubspec.lock')
        subprocess.run(flutter + ['pub', 'get'], cwd=app, check=True)
        expected = hosted_versions(lock)
        actual = hosted_versions(app / 'pubspec.lock')
        if any(expected.get(name) != version for name, version in actual.items()):
            raise RuntimeError('Playback probe diverged from application dependency versions.')
        subprocess.run(flutter + ['analyze', '--no-pub'], cwd=app, check=True)
        subprocess.run(flutter + ['build', args.platform, '--release', '--no-pub'], cwd=app, check=True)
        if args.platform == 'linux':
            command = ['xvfb-run', '-a', str(app / 'build/linux/x64/release/bundle/playback_probe')]
        else:
            command = [str(app / 'build/windows/x64/runner/Release/playback_probe.exe')]
        environment = dict(os.environ,
            DIVINE_PLAYBACK_LOCAL=str(PACKAGE / 'test/fixtures/desktop_audio_portrait.mp4'),
            DIVINE_PLAYBACK_HTTP=str(PACKAGE / 'test/fixtures/desktop_changing_portrait.mp4'))
        environment.pop('DIVINE_LINUX_NO_VIDEO_OUTPUT', None)
        environment.pop('DIVINE_PLAYBACK_HOLD', None)
        child = subprocess.Popen(command, cwd=app, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            start_new_session=os.name != 'nt')
        try:
            output, errors = child.communicate(timeout=90)
        finally:
            if child.poll() is None:
                if os.name == 'nt':
                    subprocess.run(['taskkill', '/PID', str(child.pid), '/T', '/F'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                else:
                    os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=10)
        observed = set()
        for line in (output + errors).splitlines():
            if line in MARKERS or line.startswith('DIVINE_PLAYBACK_FAIL '):
                print(line, flush=True)
                observed.add(line)
        if child.returncode != 0 or not MARKERS.issubset(observed):
            raise RuntimeError('Native playback probe failed; exit=' + str(child.returncode))


if __name__ == '__main__':
    main()
