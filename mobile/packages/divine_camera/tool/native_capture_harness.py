"""Exercise the actual desktop capture plugin with synthetic devices only."""
import argparse
import contextlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

PACKAGE = Path(__file__).resolve().parents[1]
MAIN = r"""
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:divine_camera/src/desktop/desktop_camera_backend.dart';

const channel = MethodChannel('video.divine/desktop_capture');
final previewFrames = <int, Completer<void>>{};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  channel.setMethodCallHandler((call) async {
    if (call.method == 'imageStreamFrame' && call.arguments is Map) {
      final frame = call.arguments as Map;
      final pending = previewFrames[frame['cameraId']];
      if (pending != null && !pending.isCompleted && (frame['width'] as num) > 0 &&
          (frame['height'] as num) > 0 && (frame['bytes'] as List).isNotEmpty) {
        pending.complete();
      }
    }
  });
  runApp(const SizedBox());
  final root = Directory(Platform.environment['DIVINE_CAPTURE_OUTPUT']!);
  final testCase = Platform.environment['DIVINE_CAPTURE_CASE'] ?? 'video';
  final audio = testCase != 'video' && testCase != 'startup-failure';
  int? id;
  var stage = 'enumeration';
  void setStage(String value) {
    stage = value;
    stdout.writeln('DIVINE_CAPTURE_STAGE $value');
  }
  try {
    setStage('bundled-native-license');
    final notices = await rootBundle.load('NOTICES.Z');
    final text = utf8.decode(gzip.decode(notices.buffer.asUint8List(
      notices.offsetInBytes, notices.lengthInBytes)));
    if (!text.contains('Copyright (c) 2026 Hugo Cornellier') ||
        !text.contains('Permission is hereby granted, free of charge')) {
      throw StateError('Native source attribution is missing from bundled notices');
    }
    if (Platform.isLinux) {
      setStage('portal-denial');
      final denied = await channel.invokeListMethod<Object?>('testPortalDenied');
      if (denied == null || denied.isNotEmpty) throw StateError('Camera denial offered a fallback device');
    }
    final devices = await channel.invokeListMethod<Map<Object?, Object?>>('availableCameras');
    final device = devices!.firstWhere((item) => (item['name']! as String).contains('Synthetic') ||
      (item['name']! as String).contains('Fake Red Camera'));
    Map<String, Object?>? created;
    try {
      created = await channel.invokeMapMethod<String, Object?>('create', {
        'cameraName': device['name'], 'resolutionPreset': 1,
        'enableAudio': audio, 'fps': 30,
      });
    } on PlatformException catch (error) {
      if (testCase != 'texture-unavailable' || error.code != 'texture_registration_failed') rethrow;
      await verifySourcesReleased();
      stdout.writeln('DIVINE_CAPTURE_PASS');
      exit(0);
    }
    if (testCase == 'texture-unavailable') throw StateError('Texture allocation failure was ignored');
    id = created!['cameraId']! as int;
    setStage('initialization');
    Map<String, Object?>? initialized;
    try {
      initialized = await channel.invokeMapMethod<String, Object?>('initialize', {'cameraId': id});
    } on PlatformException catch (error) {
      if (testCase != 'startup-failure' || error.code != 'initialization_failed') rethrow;
      await channel.invokeMethod<void>('dispose', {'cameraId': id});
      id = null;
      setStage('startup-watch-release');
      final watches = await channel.invokeMethod<int>('testActiveBusWatches');
      stdout.writeln('DIVINE_CAPTURE_RESOURCE_COUNT bus_watch $watches');
      if (watches != 0) throw StateError('Failed camera retained its native bus watch');
      stdout.writeln('DIVINE_CAPTURE_PASS');
      exit(0);
    }
    if (testCase == 'startup-failure') throw StateError('Pipeline startup failure was ignored');
    if ((initialized!['previewWidth']! as num) <= 0) throw StateError('No preview');
    await verifyFirstPreviewFrame(id);
    if (testCase == 'audio-unavailable') {
      setStage('audio-unavailable');
      final directory = await Directory.fromUri(root.uri.resolve('failed-audio/')).create();
      var rejected = false;
      try {
        await channel.invokeMethod<void>('startVideoRecording', {
          'cameraId': id, 'outputDirectory': directory.path,
        });
      } on PlatformException catch (error) {
        rejected = error.code == 'recording_setup_failed';
      }
      await channel.invokeMethod<void>('dispose', {'cameraId': id});
      id = null;
      await verifySourcesReleased();
      if (!rejected) throw StateError('Requested microphone failure was ignored');
      stdout.writeln('DIVINE_CAPTURE_PASS');
      exit(0);
    }
    setStage('photo-ownership');
    final photoDirectory = await Directory.fromUri(root.uri.resolve('photo/')).create();
    final photoPath = await channel.invokeMethod<String>('takePicture', {
      'cameraId': id, 'outputDirectory': photoDirectory.path,
    });
    final photo = File(photoPath!);
    if (await photo.parent.resolveSymbolicLinks() != await photoDirectory.resolveSymbolicLinks() || await photo.length() == 0) {
      throw StateError('Photo escaped its owned directory');
    }
    await verifyWriterReleased(photo);
    final capturedBytes = await photo.readAsBytes();
    var replacementRejected = false;
    try {
      await channel.invokeMethod<String>('takePicture', {
        'cameraId': id, 'outputDirectory': photoDirectory.path,
      });
    } on PlatformException catch (error) {
      replacementRejected = error.code == 'invalid_args' || error.code == 'invalid_output_directory';
    }
    if (!replacementRejected || !listEquals(capturedBytes, await photo.readAsBytes())) {
      throw StateError('Native capture overwrote an existing output');
    }
    await photo.copy(File.fromUri(root.uri.resolve('photo.jpg')).path);
    setStage('repeated-recording');
    for (var index = 0; index < 2; index++) {
      setStage('recording-$index-start');
      final directory = await Directory.fromUri(root.uri.resolve('take$index/')).create();
      await channel.invokeMethod<void>('startVideoRecording', {
        'cameraId': id, 'outputDirectory': directory.path,
      });
      // A controlled wall-clock interval generates a real live media segment.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      setStage('recording-$index-stop');
      final stopped = await channel.invokeMethod<Object?>('stopVideoRecording', {'cameraId': id}).timeout(const Duration(seconds: 15));
      final path = stopped is Map ? stopped['path']! as String : stopped! as String;
      final file = File(path);
      if (await file.parent.resolveSymbolicLinks() != await directory.resolveSymbolicLinks() || await file.length() == 0) {
        throw StateError('Recording escaped its owned directory');
      }
      setStage('recording-$index-writer-release');
      await verifyWriterReleased(file);
      await file.copy(File.fromUri(root.uri.resolve('take$index.mp4')).path);
    }
    setStage('photo-disposal-writer-release');
    if (Platform.isLinux) {
      await verifyPhotoRelease(root, id);
    } else {
      await channel.invokeMethod<void>('dispose', {'cameraId': id});
    }
    id = null;
    await verifySourcesReleased();
    setStage('concurrent-stop-dispose');
    await verifyConcurrentStop(device, audio);
    if (Platform.isLinux) {
      setStage('completed-private-transfer');
      await verifyPrivateTransfer(root);
    }
    if (Platform.isWindows) {
      setStage('initialization-disposal');
      await verifyInitializationDisposal(device);
    }
    stdout.writeln('DIVINE_CAPTURE_PASS');
  } on Object catch (error) {
    stderr.writeln('DIVINE_CAPTURE_FAIL $stage ${error is PlatformException ? error.code : error.runtimeType}');
    if (error is FileSystemException) stderr.writeln('DIVINE_CAPTURE_FILESYSTEM ${error.message} ${error.osError?.errorCode} ${error.path}');
    if (id != null) await channel.invokeMethod<void>('dispose', {'cameraId': id});
    exit(1);
  }
  exit(0);
}

Future<void> verifyFirstPreviewFrame(int id) async {
  final first = previewFrames[id] = Completer<void>();
  try {
    await channel.invokeMethod<void>('startImageStream', {'cameraId': id});
    await first.future.timeout(const Duration(seconds: 15));
  } finally {
    await channel.invokeMethod<void>('stopImageStream', {'cameraId': id});
    previewFrames.remove(id);
  }
}

Future<void> verifyInitializationDisposal(Map<Object?, Object?> device) async {
  for (var index = 0; index < 5; index++) {
    final created = await channel.invokeMapMethod<String, Object?>('create', {
      'cameraName': device['name'], 'resolutionPreset': 1, 'enableAudio': true,
    });
    final id = created!['cameraId']! as int;
    final initialized = channel.invokeMethod<Object?>('initialize', {'cameraId': id})
      .then<void>((_) {}, onError: (Object error) {
        if (error is! PlatformException || error.code != 'disposed') throw error;
      });
    final released = channel.invokeMethod<void>('dispose', {'cameraId': id});
    await Future.wait([initialized, released]).timeout(const Duration(seconds: 15));
    await verifySourcesReleased();
  }
}

Future<void> verifyConcurrentStop(Map<Object?, Object?> device, bool audio) async {
  for (var index = 0; index < 5; index++) {
    stdout.writeln('DIVINE_CAPTURE_CYCLE $index');
    final created = await channel.invokeMapMethod<String, Object?>('create', {
      'cameraName': device['name'], 'resolutionPreset': 1, 'enableAudio': audio, 'fps': 30,
    });
    final id = created!['cameraId']! as int;
    await channel.invokeMethod<Object?>('initialize', {'cameraId': id});
    final directory = await Directory(Platform.environment['DIVINE_CAPTURE_OUTPUT']!)
      .createTemp('concurrent-stop-');
    await channel.invokeMethod<void>('startVideoRecording', {
      'cameraId': id, 'outputDirectory': directory.path,
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final stopped = channel.invokeMethod<Object?>('stopVideoRecording', {'cameraId': id})
      .then<void>((_) {}, onError: (Object error) {
        if (error is! PlatformException) throw error;
      });
    final disposed = channel.invokeMethod<void>('dispose', {'cameraId': id});
    await Future.wait([stopped, disposed]).timeout(const Duration(seconds: 10));
    await verifySourcesReleased();
    for (final file in directory.listSync().whereType<File>()) {
      await verifyWriterReleased(file);
    }
    await directory.delete(recursive: true);
  }
}

Future<void> verifySourcesReleased() async {
  if (Platform.isWindows &&
      await channel.invokeMethod<int>('testCaptureSourcesInUse') != 0) {
    throw StateError('Dispose acknowledged an active capture source');
  }
}

Future<void> verifyPrivateTransfer(Directory root) async {
  final backend = DesktopCameraBackend(temporaryDirectory: () async => root);
  try {
    final device = (await backend.availableCameras()).first;
    final id = await backend.createCameraWithSettings(device,
      const MediaSettings(enableAudio: false, resolutionPreset: ResolutionPreset.low));
    await backend.initializeCamera(id);
    final captured = await backend.takePicture(id);
    final file = File(captured.path);
    if (file.parent.path != root.path) throw StateError('Transfer fixture did not leave its operation directory');
    await verifyWriterReleased(file);
    final retained = File.fromUri(root.uri.resolve('retained-private.jpg'));
    await captured.saveTo(retained.path);
    await verifyWriterReleased(retained);
    await backend.dispose(id);
    if (!file.existsSync() || !retained.existsSync()) throw StateError('Release removed transferred media');
    await file.delete();
    await retained.delete();
  } finally {
    await backend.close();
  }
}

Future<void> verifyWriterReleased(File file) async {
  if (Platform.isLinux) {
    if ((file.statSync().mode & 0x3f) != 0) {
      throw StateError('Capture output did not preserve private permissions');
    }
    for (final descriptor in Directory('/proc/self/fd').listSync(followLinks: false)) {
      String target;
      try {
        target = Link(descriptor.path).targetSync();
      } on FileSystemException {
        // Unrelated engine descriptors may close while the list is read.
        continue;
      }
      if (target == file.path) throw StateError('Capture writer is still open');
    }
  } else if (Platform.isWindows) {
    final check = await Process.run('python', ['-c', r'''
import ctypes, sys
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
    ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
kernel.CreateFileW.restype = ctypes.c_void_p
handle = kernel.CreateFileW(sys.argv[1], 0xC0000000, 0, None, 3, 0, None)
if handle == ctypes.c_void_p(-1).value:
    raise RuntimeError('Capture output is still held by a native writer')
kernel.CloseHandle.argtypes = [ctypes.c_void_p]
kernel.CloseHandle(handle)
''', file.path]);
    if (check.exitCode != 0) throw StateError('Capture writer is still open');
  }
}

Future<void> verifyPhotoRelease(Directory root, int id) async {
  // A small FIFO deterministically holds a real JPEG writer open. No sleeps,
  // physical camera, microphone, test account or production entry point.
  if (await File.fromUri(root.uri.resolve('photo.jpg')).length() <= 4096) throw StateError('JPEG fixture is too small for the barrier');
  final directory = await Directory.fromUri(root.uri.resolve('blocked-photo/')).create();
  final fifo = File.fromUri(directory.uri.resolve('photo.jpg'));
  if (Process.runSync('mkfifo', [fifo.path]).exitCode != 0) throw StateError('FIFO creation');
  final reader = await Process.start('python3', ['-u', '-c', r'''
import os, sys, fcntl, select
fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
fcntl.fcntl(fd, fcntl.F_SETPIPE_SZ, 4096)
print('READER_READY', flush=True)
if not select.select([fd], [], [], 15)[0]:
    raise RuntimeError('JPEG writer did not start')
if os.read(fd, 1) != b'\xff':
    raise RuntimeError('JPEG writer did not supply a JPEG header')
print('WRITER_READY', flush=True)
sys.stdin.readline()
os.set_blocking(fd, True)
while os.read(fd, 8192):
    pass
os.close(fd)
''', fifo.path]);
  final lines = StreamIterator(reader.stdout.transform(utf8.decoder).transform(const LineSplitter()));
  Future<void> marker(String expected) async {
    if (!await lines.moveNext().timeout(const Duration(seconds: 20)) || lines.current != expected) {
      throw StateError('FIFO synchronization');
    }
  }
  Future<void>? photo;
  Future<void>? disposal;
  var releasedEarly = false;
  try {
    await marker('READER_READY');
    photo = channel.invokeMethod<Object?>('takePicture', {
      'cameraId': id, 'outputDirectory': directory.path,
    }).then<void>((_) {});
    await marker('WRITER_READY');
    var released = false;
    disposal = channel.invokeMethod<void>('dispose', {'cameraId': id}).then((_) { released = true; });
    // A lower-priority native main-loop reply drains earlier idle callbacks while
    // the JPEG writer is still blocked, without relying on a timing window.
    await channel.invokeMethod<Object?>('testMainLoopBarrier');
    releasedEarly = released;
  } finally {
    reader.stdin.writeln('drain');
    await reader.stdin.flush();
    await reader.stdin.close();
    await reader.exitCode.timeout(const Duration(seconds: 20));
    await lines.cancel();
    await photo;
    await disposal;
  }
  if (releasedEarly) throw StateError('Dispose acknowledged an active JPEG writer');
}
"""


def trace_failure_signatures(trace):
    """Keep known API names and HRESULTs; discard attributes and raw messages."""
    classes = {
        'CMFCaptureEngineDetours', 'CMFCaptureSourceDetours',
        'CMFMediaSourceDetours', 'CMFMediaSourceExDetours',
        'CMFMediaEventDetours', 'CMFActivateDetours', 'CMFAttributesDetours',
        'CMFSourceReaderDetours', 'CMFReadWriteClassFactoryDetours',
        'COle32ExportDetours',
    }
    methods = {
        'Initialize', 'ActivateObject', 'QueryInterface', 'GetSourceAttributes',
        'GetStreamAttributes', 'GetService', 'GetUnknown', 'GetGUID',
        'GetString', 'GetAllocatedString', 'GetUINT32', 'GetStatus', 'GetEvent',
        'BeginGetEvent', 'EndGetEvent', 'CreateInstance', 'CoCreateInstance',
        'Trace', 'HandleEvent', 'SetCurrentMediaType',
    }
    signatures = set()
    for line in trace.splitlines():
        codes = re.findall(r'\b(?:hr|hresult|status)\s*[:=]\s*(0x[89a-f][0-9a-f]{7})(?![0-9a-f])', line, re.I)
        if not codes:
            continue
        symbol = next((owner + '::' + method
                       for owner, method in re.findall(r'\b([A-Za-z][A-Za-z0-9_]*)::([A-Za-z][A-Za-z0-9_]*)\b', line)
                       if owner in classes and method in methods), 'unattributed')
        signatures.update((symbol, code.lower()) for code in codes)
    return sorted(signatures, key=lambda value: (value[1] != '0x80070005', value))


def capture_trace_tool():
    """Use an already-installed x64 Windows SDK tool, without changing access."""
    direct = shutil.which('mftrace.exe')
    if direct:
        return Path(direct)
    sdk = Path(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')) / 'Windows Kits/10/bin'
    versions = sorted(sdk.glob('*/x64/mftrace.exe'))
    return versions[-1] if versions else None


def trace_capture_failure(command, app, env):
    """Supplement an unchanged failing assertion; tracing cannot make it pass."""
    tracer = capture_trace_tool()
    print('DIVINE_CAPTURE_TRACE_TOOL', 'present' if tracer else 'unavailable', flush=True)
    if not tracer:
        return
    launcher = env.get('DIVINE_CAPTURE_TRACE_LAUNCHER')
    if not launcher or not Path(launcher).is_file():
        print('DIVINE_CAPTURE_TRACE_STAGE launcher_unavailable', flush=True)
        return
    try:
        # MFTrace defaults to stdout. Keep it in memory, never in a raw log.
        traced = subprocess.run([launcher, str(tracer), '-dc', '-l', '5'] + command,
                                cwd=app, env=env, capture_output=True, timeout=40)
        print('DIVINE_CAPTURE_TRACE_LAUNCHER_EXIT', traced.returncode, flush=True)
        streams = [traced.stdout, traced.stderr]
    except subprocess.TimeoutExpired as failure:
        print('DIVINE_CAPTURE_TRACE_STAGE timeout', flush=True)
        streams = [failure.stdout or b'', failure.stderr or b'']
    except OSError:
        print('DIVINE_CAPTURE_TRACE_STAGE execution_failed', flush=True)
        return
    text = '\n'.join(stream.decode('utf-16' if stream.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8',
                                   errors='replace') for stream in streams)
    signatures = trace_failure_signatures(text)
    print('DIVINE_CAPTURE_TRACE_FAILURE_COUNT', len(signatures), flush=True)
    for symbol, code in signatures[:80]:
        print('DIVINE_CAPTURE_TRACE_STATUS', symbol, code, flush=True)


def require_capture_success(result, platform, capture_case, command, app, env):
    if result.returncode != 0 or 'DIVINE_CAPTURE_PASS' not in result.stdout:
        if platform == 'windows' and capture_case == 'audio' and 'DIVINE_CAPTURE_FAIL initialization' in (result.stdout + result.stderr):
            trace_capture_failure(command, app, env)
        raise RuntimeError('Native capture failed; exit=' + str(result.returncode))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['linux', 'windows'], required=True)
    parser.add_argument('--case', choices=['video', 'audio', 'audio-unavailable', 'texture-unavailable', 'startup-failure'], default='video')
    parser.add_argument('--workspace', type=Path, help='Optional private incremental build directory.')
    args = parser.parse_args()
    flutter = ['flutter']
    if os.name == 'nt':
        sdk = Path(shutil.which('flutter')).resolve().parent.parent
        flutter = [str(sdk / 'bin/cache/dart-sdk/bin/dart.exe'),
                   str(sdk / 'bin/cache/flutter_tools.snapshot')]
    if args.workspace:
        args.workspace.mkdir(parents=True, exist_ok=True)
    workspace = contextlib.nullcontext(str(args.workspace)) if args.workspace else tempfile.TemporaryDirectory(prefix='divine-capture-native-')
    with workspace as temporary:
        root = Path(temporary)
        plugin = root / 'plugin'
        plugin.mkdir(exist_ok=True)
        shutil.copytree(PACKAGE / args.platform, plugin / args.platform,
                        dirs_exist_ok=True)
        shutil.copytree(PACKAGE / 'native/include', plugin / 'native/include',
                        dirs_exist_ok=True)
        (plugin / 'lib').mkdir(exist_ok=True)
        dart_backend = plugin / 'lib/src/desktop/desktop_camera_backend.dart'
        dart_backend.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PACKAGE / 'lib/src/desktop/desktop_camera_backend.dart', dart_backend)
        license_changed = False
        if (PACKAGE / 'LICENSE').exists():
            license_changed = not (plugin / 'LICENSE').exists() or (
                (PACKAGE / 'LICENSE').read_bytes() != (plugin / 'LICENSE').read_bytes())
            shutil.copyfile(PACKAGE / 'LICENSE', plugin / 'LICENSE')
        elif (plugin / 'LICENSE').exists():
            license_changed = True
            (plugin / 'LICENSE').unlink()
        (plugin / 'lib/divine_camera.dart').write_text('', encoding='utf-8')
        (plugin / 'pubspec.yaml').write_text('''name: divine_camera
version: 0.0.1
environment:
  sdk: ^3.13.0
dependencies:
  camera_platform_interface: ^2.7.0
  flutter:
    sdk: flutter
flutter:
  plugin:
    platforms:
      linux:
        pluginClass: DivineCameraPlugin
      windows:
        pluginClass: DivineCameraPlugin
''', encoding='utf-8')
        app = root / 'app'
        if license_changed and app.exists():
            # Flutter's incremental asset inputs cannot notice a LICENSE that
            # was absent on the previous build. Rebuild that private consumer.
            subprocess.run(flutter + ['clean'], cwd=app, check=True)
        if not app.exists():
            subprocess.run(flutter + ['create', '--empty', '--no-pub',
                '--platforms=' + args.platform, '--project-name=capture_probe', str(app)], check=True)
        (app / 'pubspec.yaml').write_text('''name: capture_probe
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  divine_camera:
    path: ../plugin
''', encoding='utf-8')
        (app / 'lib/main.dart').write_text(MAIN, encoding='utf-8')
        cmake = app / args.platform / 'CMakeLists.txt'
        # Only this isolated Debug consumer enables synthetic capture devices.
        cmake_source = cmake.read_text()
        if 'set(DIVINE_CAMERA_TEST_CAPTURE ON' not in cmake_source:
            cmake.write_text(cmake_source.replace('project(',
                'set(DIVINE_CAMERA_TEST_CAPTURE ON CACHE BOOL "Synthetic capture test")\nproject(', 1))
        subprocess.run(flutter + ['pub', 'get'], cwd=app, check=True)
        subprocess.run(flutter + ['build', args.platform, '--debug'], cwd=app, check=True)
        output = root / 'output'
        if output.exists():
            shutil.rmtree(output)
        output.mkdir()
        native_temp = root / 'native-temp'
        if native_temp.exists():
            shutil.rmtree(native_temp)
        native_temp.mkdir()
        env = dict(os.environ, G_MESSAGES_DEBUG='all', DIVINE_CAPTURE_CASE=args.case, DIVINE_CAPTURE_OUTPUT=str(output),
                   TMPDIR=str(native_temp), TEMP=str(native_temp), TMP=str(native_temp))
        if args.platform == 'windows':
            env['CAMERA_DESKTOP_LOG'] = '1'
        if args.case == 'audio-unavailable':
            env['DIVINE_CAPTURE_TEST_AUDIO_UNAVAILABLE'] = '1'
        if args.case == 'startup-failure':
            env['DIVINE_CAPTURE_TEST_PIPELINE_START_FAILURE'] = '1'
        if args.case == 'texture-unavailable':
            env['DIVINE_CAPTURE_TEST_TEXTURE_FAILURE'] = '1'
        if args.platform == 'linux':
            binary = app / 'build/linux/x64/debug/bundle/capture_probe'
            command = ['xvfb-run', '-a', str(binary)]

        else:
            command = [str(app / 'build/windows/x64/runner/Debug/capture_probe.exe')]
        try:
            result = subprocess.run(command, cwd=app, env=env, capture_output=True,
                text=True, timeout=60)
        except subprocess.TimeoutExpired as error:
            for stream in [error.stdout, error.stderr]:
                if stream:
                    for line in (stream.decode(errors='replace') if isinstance(stream, bytes) else stream).splitlines():
                        if line.startswith('DIVINE_CAPTURE_'):
                            print(line, flush=True)
            raise RuntimeError('Native capture did not release before the harness deadline') from None
        for line in (result.stdout + result.stderr).splitlines():
            status = re.search(r'capture-status (create|initialize|error|record_start|record_stop|other|event_type|event_status|negotiate|preview):(0x[0-9a-fA-F]+)', line)
            if status:
                print('DIVINE_CAPTURE_NATIVE_STATUS', status.group(1), status.group(2), flush=True)
            if 'capture-stage timeout' in line:
                print('DIVINE_CAPTURE_NATIVE_STAGE timeout', flush=True)
            if line.startswith('DIVINE_CAPTURE_') or 'GStreamer error:' in line or 'RecordHandler::Setup failed:' in line or 'Audio setup failed:' in line:
                print(line, flush=True)
        require_capture_success(result, args.platform, args.case, command, app, env)
        if args.case in ['audio-unavailable', 'texture-unavailable', 'startup-failure']:
            print('DIVINE_CAPTURE_EXPECTED_FAILURE_PASS', flush=True)
            return
        # FFmpeg is an independent test oracle, never a production dependency.
        for name in ['photo.jpg', 'take0.mp4', 'take1.mp4']:
            probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries',
                'stream=codec_name,codec_type,width,height,start_time:format=duration', '-of', 'json', str(output / name)],
                check=True, capture_output=True, text=True)
            metadata = json.loads(probe.stdout)
            video = next(item for item in metadata['streams'] if item['codec_type'] == 'video')
            if video['width'] <= 0 or video['height'] <= 0:
                raise RuntimeError('Native capture has no video dimensions')
            frame = subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(output / name),
                '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                check=True, capture_output=True).stdout
            width, height = video['width'], video['height']
            left = (height // 10 * width + width // 14) * 3
            right = (height // 10 * width + width * 13 // 14) * 3
            if args.platform == 'linux':
                # SMPTE bars are white on the left and blue on the right.
                # This checks the captured image, independently of preview/UI transforms.
                if frame[left] < frame[right] + 120:
                    raise RuntimeError('Native capture unexpectedly mirrored its natural output')
            elif frame[left] < frame[left + 2] + 120 or frame[right + 2] < frame[right] + 120:
                raise RuntimeError('Native capture unexpectedly mirrored its red/blue test source')
            if name.endswith('.mp4') and float(metadata['format']['duration']) < 0.25:
                raise RuntimeError('Native capture is shorter than its controlled live interval')
            if name.endswith('.mp4'):
                audio_streams = [item for item in metadata['streams'] if item['codec_type'] == 'audio']
                if args.case == 'audio':
                    if len(audio_streams) != 1 or audio_streams[0]['codec_name'] != 'aac':
                        raise RuntimeError('Capture must contain AAC microphone audio')
                    if abs(float(video.get('start_time', 0)) - float(audio_streams[0].get('start_time', 0))) > 0.15:
                        raise RuntimeError('Capture audio/video start times diverge')
                    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(output / name),
                        '-map', '0:a:0', '-t', '3', '-ac', '1', '-ar', '16000', '-f', 'f32le', '-'],
                        check=True, capture_output=True, timeout=20)
                    import array, math
                    samples = array.array('f')
                    samples.frombytes(decoded.stdout)
                    if not samples or math.sqrt(sum(value * value for value in samples) / len(samples)) < 0.1:
                        raise RuntimeError('Capture microphone track is silent')
                elif audio_streams:
                    raise RuntimeError('Audio-disabled capture acquired an audio track')
                if float(metadata['format']['duration']) > 2.0:
                    raise RuntimeError('Capture includes time before the live take')
            subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(output / name), '-f', 'null', '-'],
                check=True, capture_output=True)
        print('DIVINE_CAPTURE_INDEPENDENT_DECODE_PASS', flush=True)


if __name__ == '__main__':
    main()
