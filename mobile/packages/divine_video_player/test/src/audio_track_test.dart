import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(AudioTrack, () {
    group('default constructor', () {
      test('sets uri and defaults', () {
        const track = AudioTrack(uri: '/path/to/audio.mp3');

        expect(track.uri, equals('/path/to/audio.mp3'));
        expect(track.volume, equals(1.0));
        expect(track.videoStartTime, equals(Duration.zero));
        expect(track.videoEndTime, isNull);
        expect(track.trackStart, equals(Duration.zero));
        expect(track.trackEnd, isNull);
      });

      test('accepts all parameters', () {
        const track = AudioTrack(
          uri: '/path/to/audio.mp3',
          volume: 0.5,
          videoStartTime: Duration(seconds: 5),
          videoEndTime: Duration(seconds: 30),
          trackStart: Duration(seconds: 10),
          trackEnd: Duration(seconds: 40),
        );

        expect(track.volume, equals(0.5));
        expect(track.videoStartTime, equals(const Duration(seconds: 5)));
        expect(track.videoEndTime, equals(const Duration(seconds: 30)));
        expect(track.trackStart, equals(const Duration(seconds: 10)));
        expect(track.trackEnd, equals(const Duration(seconds: 40)));
      });
    });

    group('file constructor', () {
      test('sets uri from path', () {
        const track = AudioTrack.file('/local/song.mp3');

        expect(track.uri, equals('/local/song.mp3'));
        expect(track.volume, equals(1.0));
        expect(track.videoStartTime, equals(Duration.zero));
        expect(track.trackStart, equals(Duration.zero));
      });

      test('accepts all parameters', () {
        const track = AudioTrack.file(
          '/local/song.mp3',
          volume: 0.8,
          videoStartTime: Duration(seconds: 2),
          videoEndTime: Duration(seconds: 20),
          trackStart: Duration(seconds: 5),
          trackEnd: Duration(seconds: 15),
        );

        expect(track.volume, equals(0.8));
        expect(track.videoStartTime, equals(const Duration(seconds: 2)));
        expect(track.videoEndTime, equals(const Duration(seconds: 20)));
        expect(track.trackStart, equals(const Duration(seconds: 5)));
        expect(track.trackEnd, equals(const Duration(seconds: 15)));
      });
    });

    group('network constructor', () {
      test('sets uri from url', () {
        const track = AudioTrack.network('https://example.com/audio.mp3');

        expect(track.uri, equals('https://example.com/audio.mp3'));
        expect(track.volume, equals(1.0));
      });

      test('accepts all parameters', () {
        const track = AudioTrack.network(
          'https://example.com/audio.mp3',
          volume: 0.3,
          videoStartTime: Duration(seconds: 1),
          videoEndTime: Duration(seconds: 10),
          trackEnd: Duration(seconds: 9),
        );

        expect(track.volume, equals(0.3));
        expect(track.videoStartTime, equals(const Duration(seconds: 1)));
        expect(track.videoEndTime, equals(const Duration(seconds: 10)));
        expect(track.trackEnd, equals(const Duration(seconds: 9)));
      });
    });

    group('toMap', () {
      test('serializes all fields', () {
        const track = AudioTrack(
          uri: '/audio.mp3',
          volume: 0.7,
          videoStartTime: Duration(seconds: 5),
          videoEndTime: Duration(seconds: 25),
          trackStart: Duration(seconds: 10),
          trackEnd: Duration(seconds: 30),
          fadeInDuration: Duration(milliseconds: 500),
          fadeOutDuration: Duration(seconds: 2),
        );
        final map = track.toMap();

        expect(map['uri'], equals('/audio.mp3'));
        expect(map['volume'], equals(0.7));
        expect(map['videoStartMs'], equals(5000));
        expect(map['videoEndMs'], equals(25000));
        expect(map['trackStartMs'], equals(10000));
        expect(map['trackEndMs'], equals(30000));
        expect(map['fadeInMs'], equals(500));
        expect(map['fadeOutMs'], equals(2000));
      });

      test('serializes null end times', () {
        const track = AudioTrack(uri: '/audio.mp3');
        final map = track.toMap();

        expect(map['videoEndMs'], isNull);
        expect(map['trackEndMs'], isNull);
      });

      test('serializes defaults', () {
        const track = AudioTrack(uri: '/audio.mp3');
        final map = track.toMap();

        expect(map['volume'], equals(1.0));
        expect(map['videoStartMs'], isZero);
        expect(map['trackStartMs'], isZero);
        expect(map['fadeInMs'], isZero);
        expect(map['fadeOutMs'], isZero);
        expect(map.containsKey('equalizer'), isFalse);
      });

      test('serializes an equalizer and leaves out a flat one', () {
        const bass = AudioEqualizer(
          bands: [
            AudioEqualizerBand(
              type: AudioEqualizerBandType.lowShelf,
              frequency: 200,
              gain: 6,
            ),
          ],
        );

        expect(
          const AudioTrack(uri: '/a.mp3', equalizer: bass).toMap()['equalizer'],
          bass.toMap(),
        );
        expect(
          const AudioTrack(
            uri: '/a.mp3',
            equalizer: AudioEqualizer(),
          ).toMap().containsKey('equalizer'),
          isFalse,
        );
      });
    });

    group('asset', () {
      late Directory tempDir;
      late PathProviderPlatform originalPathProvider;

      setUp(() async {
        originalPathProvider = PathProviderPlatform.instance;
        tempDir = await Directory.systemTemp.createTemp('audio_track_test_');
        PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      });

      tearDown(() async {
        // Restore the process-global platform singleton so the fake (whose
        // temp dir is about to be deleted) does not leak into later files in
        // the package's merged isolate.
        PathProviderPlatform.instance = originalPathProvider;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('copies asset data to temp file', () async {
        final testBytes = Uint8List.fromList([11, 22, 33, 44]);
        final bundle = _FakeAssetBundle(testBytes);

        final track = await AudioTrack.asset(
          'assets/test_audio.mp3',
          volume: 0.6,
          videoStartTime: const Duration(seconds: 2),
          videoEndTime: const Duration(seconds: 20),
          trackStart: const Duration(seconds: 5),
          trackEnd: const Duration(seconds: 15),
          fadeInDuration: const Duration(seconds: 1),
          fadeOutDuration: const Duration(seconds: 2),
          bundle: bundle,
        );

        expect(track.uri, contains('test_audio.mp3'));
        expect(track.volume, equals(0.6));
        expect(
          track.videoStartTime,
          equals(const Duration(seconds: 2)),
        );
        expect(track.videoEndTime, equals(const Duration(seconds: 20)));
        expect(track.trackStart, equals(const Duration(seconds: 5)));
        expect(track.trackEnd, equals(const Duration(seconds: 15)));
        expect(track.fadeInDuration, equals(const Duration(seconds: 1)));
        expect(track.fadeOutDuration, equals(const Duration(seconds: 2)));
        expect(File(track.uri).existsSync(), isTrue);
        expect(File(track.uri).readAsBytesSync(), equals(testBytes));
      });
    });

    group('memory', () {
      late Directory tempDir;
      late PathProviderPlatform originalPathProvider;

      setUp(() async {
        originalPathProvider = PathProviderPlatform.instance;
        tempDir = await Directory.systemTemp.createTemp('audio_track_test_');
        PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      });

      tearDown(() async {
        // Restore the process-global platform singleton so the fake (whose
        // temp dir is about to be deleted) does not leak into later files in
        // the package's merged isolate.
        PathProviderPlatform.instance = originalPathProvider;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('writes bytes to temp file', () async {
        final bytes = Uint8List.fromList([55, 66, 77, 88]);

        final track = await AudioTrack.memory(
          bytes,
          fileName: 'test_audio.mp3',
          volume: 0.4,
          videoStartTime: const Duration(seconds: 1),
          videoEndTime: const Duration(seconds: 10),
          trackStart: const Duration(seconds: 3),
          trackEnd: const Duration(seconds: 8),
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 700),
        );

        expect(track.uri, contains('test_audio.mp3'));
        expect(track.volume, equals(0.4));
        expect(
          track.videoStartTime,
          equals(const Duration(seconds: 1)),
        );
        expect(track.videoEndTime, equals(const Duration(seconds: 10)));
        expect(track.trackStart, equals(const Duration(seconds: 3)));
        expect(track.trackEnd, equals(const Duration(seconds: 8)));
        expect(track.fadeInDuration, equals(const Duration(milliseconds: 300)));
        expect(
          track.fadeOutDuration,
          equals(const Duration(milliseconds: 700)),
        );
        expect(File(track.uri).existsSync(), isTrue);
        expect(File(track.uri).readAsBytesSync(), equals(bytes));
      });
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._tempPath);

  final String _tempPath;

  @override
  Future<String?> getTemporaryPath() async => _tempPath;
}

class _FakeAssetBundle extends Fake implements AssetBundle {
  _FakeAssetBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async => _bytes.buffer.asByteData();
}
