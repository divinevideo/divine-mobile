// ABOUTME: Tests for readDmVideoPreview: the blurhash and displayed size a
// ABOUTME: video DM carries, read through a mocked pro_video_editor channel.

import 'dart:async';
import 'dart:io';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openvine/services/dm_video_preview.dart';
// Not exported from pro_video_editor's barrel. Imported by path so the test
// can subclass MethodChannelProVideoEditor without its EventChannel setup.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

/// A PNG frame filled with one colour, as the native thumbnailer returns.
Uint8List _solidFrame(int red, int green, int blue) => img.encodePng(
  img.fill(
    img.Image(width: 32, height: 32),
    color: img.ColorRgb8(red, green, blue),
  ),
);

const _portraitMetadata = <String, Object>{
  'width': 1080,
  'height': 1920,
  'rotation': 0,
  'duration': 6300,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('readDmVideoPreview', () {
    const channel = MethodChannel('pro_video_editor');
    late ProVideoEditor originalProVideoEditor;
    late Directory tempDir;
    late File video;
    late Future<Object?> Function(MethodCall call) answer;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _NoopInitProVideoEditor();
      tempDir = Directory.systemTemp.createTempSync('dm_video_preview_');
      video = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) => answer(call));
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('reads a blurhash of the frame and the displayed size', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[_solidFrame(255, 0, 0)],
        'getMetadata' => _portraitMetadata,
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.dimensions, equals('1080x1920'));
      final decoded = BlurhashService.decodeBlurhash(preview.blurhash ?? '');
      expect(decoded, isNotNull);
      expect(decoded!.primaryColor.r, closeTo(1, 0.05));
      expect(decoded.primaryColor.g, closeTo(0, 0.05));
      expect(decoded.primaryColor.b, closeTo(0, 0.05));
    });

    test('keeps the size when no frame can be extracted', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[],
        'getMetadata' => _portraitMetadata,
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.blurhash, isNull);
      expect(preview.dimensions, equals('1080x1920'));
    });

    test('keeps the blurhash when the size cannot be read', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[_solidFrame(0, 0, 255)],
        'getMetadata' => throw PlatformException(code: 'unreadable'),
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.blurhash, isNotNull);
      expect(preview.dimensions, isNull);
    });

    test('leaves out a size the platform reports as empty', () async {
      answer = (call) async => switch (call.method) {
        'getThumbnails' => <Uint8List>[_solidFrame(0, 255, 0)],
        'getMetadata' => const <String, Object>{'width': 0, 'height': 0},
        _ => null,
      };

      final preview = await readDmVideoPreview(video);

      expect(preview.blurhash, isNotNull);
      expect(preview.dimensions, isNull);
    });

    test(
      'gives up on a platform call that never answers, so the send is not '
      'held',
      () async {
        final never = Completer<Object?>();
        answer = (call) => never.future;

        final preview = await readDmVideoPreview(
          video,
          timeout: const Duration(milliseconds: 50),
        );

        expect(preview.blurhash, isNull);
        expect(preview.dimensions, isNull);
      },
    );
  });
}
