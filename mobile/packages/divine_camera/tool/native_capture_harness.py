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
final previewFrames = <int, Completer<Map>>{};
final cameraErrors = <int, Completer<String>>{};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  channel.setMethodCallHandler((call) async {
    if (call.method == 'cameraError' && call.arguments is Map) {
      final error = call.arguments as Map;
      final pending = cameraErrors[error['cameraId']];
      if (pending != null && !pending.isCompleted) pending.complete(error['description'] as String);
    }
    if (call.method == 'imageStreamFrame' && call.arguments is Map) {
      final frame = call.arguments as Map;
      final pending = previewFrames[frame['cameraId']];
      if (pending != null && !pending.isCompleted && (frame['width'] as num) > 0 &&
          (frame['height'] as num) > 0 && (frame['bytes'] as List).isNotEmpty) {
        pending.complete(frame);
      }
    }
  });
  runApp(const SizedBox());
  final root = Directory(Platform.environment['DIVINE_CAPTURE_OUTPUT']!);
  final testCase = Platform.environment['DIVINE_CAPTURE_CASE'] ?? 'video';
  final audio = testCase == 'audio' || testCase == 'audio-unavailable';
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
        'enableAudio': audio, 'fps': 30, 'mirrorOutput': (Platform.environment['DIVINE_CAPTURE_CASE'] ?? '').startsWith('mirror'),
      });
    } on PlatformException catch (error) {
      if (testCase != 'texture-unavailable' || error.code != 'texture_registration_failed') rethrow;
      await verifySourcesReleased();
      stdout.writeln('DIVINE_CAPTURE_PASS');
      exit(0);
    }
    if (testCase == 'texture-unavailable') throw StateError('Texture allocation failure was ignored');
    id = created!['cameraId']! as int;
    cameraErrors[id] = Completer<String>();
    setStage('initialization');
    Map<String, Object?>? initialized;
    try {
      initialized = await channel.invokeMapMethod<String, Object?>('initialize', {'cameraId': id});
    } on PlatformException catch (error) {
      if (['mirror-timeout', 'mirror-error', 'mirror-status', 'mirror-start-timeout', 'mirror-frame-before-start-timeout'].contains(testCase)) {
        if (error.code != (testCase == 'mirror-error' ? 'disposed' : 'initialization_failed')) rethrow;
        final injected = await channel.invokeMethod<int>('testMirrorFailure', {'cameraId': id});
        final expectedInjection = {'mirror-timeout': 1, 'mirror-error': 2, 'mirror-status': 3, 'mirror-start-timeout': 4, 'mirror-frame-before-start-timeout': 6}[testCase];
        if (injected != expectedInjection) throw StateError('Real mirror acknowledgement did not reach the intended failure');
        final starts = await channel.invokeMethod<int>('testPreviewStarts', {'cameraId': id});
        if (starts != (['mirror-start-timeout', 'mirror-frame-before-start-timeout'].contains(testCase) ? 1 : 0)) throw StateError('Unexpected preview startup after terminal failure');
        if (await channel.invokeMethod<int>('testNativePreviewStarts', {'cameraId': id}) != (testCase == 'mirror-frame-before-start-timeout' ? 1 : 0)) throw StateError('Terminal failure issued a native preview start');
        if (await channel.invokeMethod<bool>('testCameraRunning', {'cameraId': id}) != false) throw StateError('Failed camera became ready');
        var retryRejected = false;
        try {
          await channel.invokeMethod<void>('initialize', {'cameraId': id});
        } on PlatformException catch (retry) {
          retryRejected = retry.code == 'already_initialized';
        }
        if (!retryRejected) throw StateError('Failed camera session was reused');
        await channel.invokeMethod<void>('dispose', {'cameraId': id});
        id = null;
        await verifySourcesReleased();
        stdout.writeln('DIVINE_CAPTURE_PASS');
        exit(0);
      }
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
    if (['mirror-timeout', 'mirror-error', 'mirror-status', 'mirror-start-timeout', 'mirror-frame-before-start-timeout'].contains(testCase)) throw StateError('Terminal mirror failure was ignored');
    if (testCase == 'startup-failure') throw StateError('Pipeline startup failure was ignored');
    if ((initialized!['previewWidth']! as num) <= 0) throw StateError('No preview');
    if (testCase == 'mirror-no-frames') {
      final description = await cameraErrors[id]!.future.timeout(const Duration(seconds: 15));
      if (description != 'Camera started but no frames were received') throw StateError('First-frame watchdog did not report the missing sample');
      if (await channel.invokeMethod<int>('testMirrorFailure', {'cameraId': id}) != 5) throw StateError('Native preview did not withhold a real frame');
      if (await channel.invokeMethod<int>('testPreviewStarts', {'cameraId': id}) != 1) throw StateError('Preview did not start');
      if (await channel.invokeMethod<int>('testNativePreviewStarts', {'cameraId': id}) != 1) throw StateError('Native preview did not start');
      if (await channel.invokeMethod<bool>('testCameraRunning', {'cameraId': id}) != false) throw StateError('Missing-frame failure retained readiness');
      await channel.invokeMethod<void>('dispose', {'cameraId': id});
      id = null;
      await verifySourcesReleased();
      stdout.writeln('DIVINE_CAPTURE_PASS');
      exit(0);
    }
    await verifyFirstPreviewFrame(id);
    if (testCase == 'mirror-valid-frame-deadline') {
      await channel.invokeMethod<void>('testInitializationDeadline', {'cameraId': id});
      if (await channel.invokeMethod<bool>('testCameraRunning', {'cameraId': id}) != true) throw StateError('A valid frame was retired by the deadline');
    }
    setStage('independent-output-orientation');
    final capabilities = await channel.invokeMapMethod<String, Object?>('getPlatformCapabilities');
    if (capabilities?['supportsMirrorControl'] != false) {
      throw StateError('Native preview mirroring can alter saved-output orientation');
    }
    var nativeMirrorRejected = false;
    try {
      await channel.invokeMethod<void>('setMirror', {'cameraId': id, 'mirrored': false});
    } on PlatformException catch (error) {
      nativeMirrorRejected = error.code == 'unsupported';
    }
    if (!nativeMirrorRejected) throw StateError('Native preview mirror override was accepted');
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
    await verifyFirstPreviewFrame(id);
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
    await verifyFirstPreviewFrame(id);
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
  final first = previewFrames[id] = Completer<Map>();
  try {
    await channel.invokeMethod<void>('startImageStream', {'cameraId': id});
    final frame = await first.future.timeout(const Duration(seconds: 15));
    final width = (frame['width'] as num).toInt();
    final height = (frame['height'] as num).toInt();
    final pixels = frame['bytes'] as List;
    if (pixels.length != width * height * 4) throw StateError('Invalid stream frame size');
    final left = (height ~/ 10 * width + width ~/ 14) * 4;
    final right = (height ~/ 10 * width + width * 13 ~/ 14) * 4;
    // The native BGRA stream stays natural; Flutter owns preview mirroring.
    if ((pixels[left + 2] as int) < (pixels[right + 2] as int) + 120 ||
        (Platform.isWindows && (pixels[right] as int) < (pixels[left] as int) + 120)) {
      throw StateError('Saved-output mirroring changed the native preview');
    }
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
      'cameraName': device['name'], 'resolutionPreset': 1, 'enableAudio': audio, 'fps': 30, 'mirrorOutput': (Platform.environment['DIVINE_CAPTURE_CASE'] ?? '').startsWith('mirror'),
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


def trace_attribute_failures(trace):
    """Retain public SDK key names only; unknown key names and values stay private."""
    # Public key identifiers from Microsoft win32metadata a40ed3186943620f304649a077b78f8271034736.
    attributes = {
        'MFT_FRIENDLY_NAME_Attribute': '314ffbae-5b41-4c95-9c19-4e7d586face3',
        'MFT_INPUT_TYPES_Attributes': '4276c9b1-759d-4bf3-9cd0-0d723d138f96',
        'MFT_OUTPUT_TYPES_Attributes': '8eae8cf3-a44f-4306-ba5c-bf5dda242818',
        'MFT_TRANSFORM_CLSID_Attribute': '6821c42b-65a4-4e82-99bc-9a88205ecd0c',
        'MF_CAPTURE_ENGINE_D3D_MANAGER': '76e25e7b-d595-4283-962c-c594afd78ddf',
        'MF_CAPTURE_ENGINE_EVENT_GENERATOR_GUID': 'abfa8ad5-fc6d-4911-87e0-961945f8f7ce',
        'MF_CAPTURE_ENGINE_EVENT_STREAM_INDEX': '82697f44-b1cf-42eb-9753-f86d649c8865',
        'MF_DEVICESTREAM_STREAM_CATEGORY': '2939e7b8-a62e-4579-b674-d4073dfabbba',
        'MF_DEVICESTREAM_STREAM_ID': '11bd5120-d124-446b-88e6-17060257fff9',
        'MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE': 'c60ac5fe-252a-478f-a0ef-bc8fa5f7cad3',
        'MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_AUDCAP_ENDPOINT_ID': '30da9258-feb9-47a7-a453-763a7a8e1c5f',
        'MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_CATEGORY': '77f0ae69-c3bd-4509-941d-467e4d24899e',
        'MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_MAX_BUFFERS': '7dd9b730-4f2d-41d5-8f95-0cc9a912ba26',
        'MF_MT_ALL_SAMPLES_INDEPENDENT': 'c9173739-5e56-461c-b713-46fb995cb95f',
        'MF_MT_AUDIO_AVG_BYTES_PER_SECOND': '1aab75c8-cfef-451c-ab95-ac034b8e1731',
        'MF_MT_AUDIO_BITS_PER_SAMPLE': 'f2deb57f-40fa-4764-aa33-ed4f2d1ff669',
        'MF_MT_AUDIO_BLOCK_ALIGNMENT': '322de230-9eeb-43bd-ab7a-ff412251541d',
        'MF_MT_AUDIO_NUM_CHANNELS': '37e48bf5-645e-4c5b-89de-ada9e29b696a',
        'MF_MT_AUDIO_SAMPLES_PER_SECOND': '5faeeae7-0290-4c31-9e8a-c534f68d9dba',
        'MF_MT_DEFAULT_STRIDE': '644b4e48-1e02-4516-b0eb-c01ca9d49ac6',
        'MF_MT_FIXED_SIZE_SAMPLES': 'b8ebefaf-b718-4e04-b0a9-116775e3321b',
        'MF_MT_FRAME_RATE': 'c459a2e8-3d2c-4e44-b132-fee5156c7bb0',
        'MF_MT_FRAME_SIZE': '1652c33d-d6b2-4012-b834-72030849a37d',
        'MF_MT_INTERLACE_MODE': 'e2724bb8-e676-4806-b4b2-a8d6efb44ccd',
        'MF_MT_MAJOR_TYPE': '48eba18e-f8c9-4687-bf11-0a74c9f96a8f',
        'MF_MT_PIXEL_ASPECT_RATIO': 'c6376a1e-8d0a-4027-be45-6d9a0ad39bb6',
        'MF_MT_SAMPLE_SIZE': 'dad3ab78-1990-408b-bce2-eba673dacc10',
        'MF_MT_SUBTYPE': 'f7e34c9a-42e8-4714-b74b-cb29d72c35e5',
        'MF_READWRITE_D3D_OPTIONAL': '216479d9-3071-42ca-bb6c-4c22102e1d18',
        'MF_SA_D3D11_AWARE': '206b4fc8-fcf9-4c51-afe3-9764369e33a0',
        'MF_SA_D3D_AWARE': 'eaa35c29-775e-488e-9b61-b3283e49583b',
        'MF_TOPONODE_TRANSFORM_OBJECTID': None,
        'MF_TRANSFORM_ASYNC': 'f81a699a-649a-497d-8c73-29f8fed6ad7a',
        'MF_TRANSFORM_ASYNC_UNLOCK': 'e5666d6b-3422-4eb6-a421-da7db1f8e207',
        'MF_TRANSFORM_CATEGORY_Attribute': 'ceabba49-506d-4757-a6ff-66c184987e4e',
        'MF_TRANSFORM_FLAGS_Attribute': '9359bb7e-6275-46c4-a025-1c01e45f1a86',
    }
    guids = {value: name for name, value in attributes.items() if value}

    failures = []
    unknown = 0
    for line in trace.splitlines():
        api = re.search(r'\b(CMF(?:Attributes|Activate|MediaType|MediaEvent|TopologyNode|PresentationDescriptor|StreamDescriptor)Detours)::(GetGUID|GetUINT32|GetUnknown|GetItem)\b', line)
        if not api or 'attribute not found' not in line:
            continue
        status = re.search(r'\b(?:hr|hresult|status)\s*[:=]\s*(0x[0-9a-f]{8})(?![0-9a-f])', line, re.I)
        if status and status.group(1).lower() != '0xc00d36e6':
            continue
        key = re.search(r'\bguidKey\s*=\s*([A-Za-z][A-Za-z0-9_]*|\{[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\})(?=\s|$|[;,])', line)
        name = None
        if key:
            token = key.group(1)
            name = token if token in attributes else guids.get(token.strip('{}').lower())
        if name:
            failures.append((api.group(0), name, '0xc00d36e6'))
        else:
            unknown += 1
    return failures, unknown


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
    attributes, unknown = trace_attribute_failures(text)
    print('DIVINE_CAPTURE_TRACE_ATTRIBUTE_COUNT', len(attributes), flush=True)
    for index, (symbol, attribute, code) in enumerate(attributes[:80], 1):
        print('DIVINE_CAPTURE_TRACE_ATTRIBUTE', index, symbol, attribute, code, flush=True)
    print('DIVINE_CAPTURE_TRACE_UNKNOWN_ATTRIBUTE_COUNT', unknown, flush=True)


def native_failure_status(line):
    status = re.search(r'capture-status (create|initialize|error|record_start|record_stop|other|event_type|event_status|negotiate|preview|mirror_effect|mirror_(?:source|record_index|preview_index|factory|class|category|flags|control|mode|direct_query|add)):(0x[89a-fA-F][0-9a-fA-F]{7})(?![0-9a-fA-F])', line)
    return status.groups() if status else None


def require_capture_success(result, platform, capture_case, command, app, env):
    if env.get('DIVINE_CAPTURE_TEST_DIRECT_EFFECT') == '1' and 'capture-stage effect_direct_applied' not in (result.stdout + result.stderr):
        raise RuntimeError('Direct effect variant was not applied')
    if env.get('DIVINE_CAPTURE_TEST_EFFECT_FLAGS') == '1' and 'capture-stage effect_flags_applied' not in (result.stdout + result.stderr):
        raise RuntimeError('Effect flags variant was not applied')
    if result.returncode != 0 or 'DIVINE_CAPTURE_PASS' not in result.stdout:
        if platform == 'windows' and capture_case == 'audio' and 'DIVINE_CAPTURE_FAIL initialization' in (result.stdout + result.stderr):
            trace_capture_failure(command, app, env)
        if (platform == 'windows' and capture_case == 'mirrored-video' and
                env.get('DIVINE_CAPTURE_TEST_EFFECT_FLAGS') == '1' and
                'DIVINE_CAPTURE_FAIL initialization' in (result.stdout + result.stderr)):
            for name, case in [('video_control', 'video'), ('mirrored_comparison', 'mirrored-video')]:
                print('DIVINE_CAPTURE_TRACE_CASE', name, flush=True)
                comparison = dict(env, DIVINE_CAPTURE_CASE=case)
                if case == 'video':
                    comparison.pop('DIVINE_CAPTURE_TEST_EFFECT_FLAGS', None)
                trace_capture_failure(command, app, comparison)
        raise RuntimeError('Native capture failed; exit=' + str(result.returncode))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['linux', 'windows'], required=True)
    parser.add_argument('--case', choices=['video', 'audio', 'audio-unavailable', 'texture-unavailable', 'startup-failure', 'mirrored-video', 'mirror-timeout', 'mirror-error', 'mirror-status', 'mirror-start-timeout', 'mirror-no-frames', 'mirror-frame-before-start-timeout', 'mirror-valid-frame-deadline'], default='video')
    parser.add_argument('--workspace', type=Path, help='Optional private incremental build directory.')
    comparison = parser.add_mutually_exclusive_group()
    comparison.add_argument('--test-effect-flags', action='store_true',
                        help='Compare explicit synchronous transform flags in the Windows Debug fixture.')
    comparison.add_argument('--test-direct-effect', action='store_true',
                            help='Compare a direct IMFTransform in the Windows Debug fixture.')
    args = parser.parse_args()
    if (args.test_effect_flags or args.test_direct_effect) and (args.platform != 'windows' or args.case != 'mirrored-video'):
        parser.error('Effect comparison requires the Windows mirrored-video case')
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
        env.pop('DIVINE_CAPTURE_TEST_EFFECT_FLAGS', None)
        env.pop('DIVINE_CAPTURE_TEST_DIRECT_EFFECT', None)
        if args.test_effect_flags:
            env['DIVINE_CAPTURE_TEST_EFFECT_FLAGS'] = '1'
        if args.test_direct_effect:
            env['DIVINE_CAPTURE_TEST_DIRECT_EFFECT'] = '1'
        if args.platform == 'windows':
            env['CAMERA_DESKTOP_LOG'] = '1'
        if args.case == 'audio-unavailable':
            env['DIVINE_CAPTURE_TEST_AUDIO_UNAVAILABLE'] = '1'
        if args.case == 'startup-failure':
            env['DIVINE_CAPTURE_TEST_PIPELINE_START_FAILURE'] = '1'
        if args.case in ['mirror-timeout', 'mirror-error', 'mirror-status']:
            env['DIVINE_CAPTURE_TEST_MIRROR_ACK_FAILURE'] = args.case.removeprefix('mirror-')
        if args.case == 'mirror-start-timeout':
            env['DIVINE_CAPTURE_TEST_PREVIEW_DEADLINE'] = '1'
        if args.case == 'mirror-frame-before-start-timeout':
            env['DIVINE_CAPTURE_TEST_EARLY_FRAME_DEADLINE'] = '1'
        if args.case == 'mirror-no-frames':
            env['DIVINE_CAPTURE_TEST_NO_PREVIEW_FRAMES'] = '1'
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
            status = native_failure_status(line)
            if status:
                print('DIVINE_CAPTURE_NATIVE_STATUS', status[0], status[1], flush=True)
            if 'capture-stage timeout' in line:
                print('DIVINE_CAPTURE_NATIVE_STAGE timeout', flush=True)
            if 'capture-stage effect_direct_applied' in line:
                print('DIVINE_CAPTURE_EFFECT_DIRECT_APPLIED', flush=True)
            if 'capture-stage effect_flags_applied' in line:
                print('DIVINE_CAPTURE_EFFECT_FLAGS_APPLIED', flush=True)
            if line.startswith('DIVINE_CAPTURE_') or 'GStreamer error:' in line or 'RecordHandler::Setup failed:' in line or 'Audio setup failed:' in line:
                print(line, flush=True)
        require_capture_success(result, args.platform, args.case, command, app, env)
        if args.case in ['audio-unavailable', 'texture-unavailable', 'startup-failure', 'mirror-timeout', 'mirror-error', 'mirror-status', 'mirror-start-timeout', 'mirror-no-frames', 'mirror-frame-before-start-timeout']:
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
            if args.case in ['mirrored-video', 'mirror-valid-frame-deadline']:
                if args.platform == 'linux':
                    if frame[right] < frame[left] + 120:
                        raise RuntimeError('Saved capture did not honor mirrored output')
                elif frame[right] < frame[right + 2] + 120 or frame[left + 2] < frame[left] + 120:
                    raise RuntimeError('Saved capture did not honor mirrored output')
            elif args.platform == 'linux':
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
