// ABOUTME: Tests for AudioPlaybackService audio playback/ headphone detection
// ABOUTME: Validates playback controls, position streams, audio session config

// Reason: audio_session (AudioDeviceType, getDevices) is marked experimental
// but no stable alternative exists. Tracked: github.com/ryanheise/audio_session
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _MockAudioSessionWrapper extends Mock implements AudioSessionWrapper {}

class _FakeAudioSource extends Fake implements AudioSource {}

class _FakeAudioSessionConfig extends Fake
    implements audio_session.AudioSessionConfiguration {}

class _FakeAudioDevice extends Fake implements audio_session.AudioDevice {
  _FakeAudioDevice(this.type);
  @override
  final audio_session.AudioDeviceType type;
}

/// The local file [_FakeRemoteAudioCache] hands out for [url].
File _cachedFileFor(String url) =>
    File('/cache/${Uri.parse(url).pathSegments.last}');

/// Hands out a local file for every sound URL without touching the network,
/// or throws [error] when one is given.
class _FakeRemoteAudioCache extends Fake implements RemoteAudioCache {
  _FakeRemoteAudioCache({this.error});

  final Exception? error;
  final requested = <Uri>[];

  @override
  Future<File> fileFor(Uri uri) async {
    requested.add(uri);
    final error = this.error;
    if (error != null) throw error;
    return _cachedFileFor(uri.toString());
  }
}

/// Holds every download until the test finishes it.
class _HeldRemoteAudioCache extends Fake implements RemoteAudioCache {
  final _downloads = <Uri, Completer<File>>{};

  @override
  Future<File> fileFor(Uri uri) => (_downloads[uri] = Completer<File>()).future;

  void finish(String url) =>
      _downloads[Uri.parse(url)]!.complete(_cachedFileFor(url));
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakeAudioSource());
    registerFallbackValue(Duration.zero);
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(_FakeAudioSessionConfig());
  });

  group(AudioPlaybackService, () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      // Set up default mock behaviors for just_audio API
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('creates with audio player dependency', () {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      expect(service, isNotNull);
    });

    test('loadAudio plays a remote sound from its downloaded file', () async {
      const testUrl = 'https://example.com/audio.aac';
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 10));
      final cache = _FakeRemoteAudioCache();

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: cache,
      );
      final duration = await service.loadAudio(testUrl);

      final capturedSource =
          verify(() => mockPlayer.setAudioSource(captureAny())).captured.single
              as UriAudioSource;
      expect(cache.requested, [Uri.parse(testUrl)]);
      expect(capturedSource.uri, Uri.file(_cachedFileFor(testUrl).path));
      expect(duration, const Duration(seconds: 10));
    });

    test('loadAudio loads bundled audio from asset:// URL', () async {
      const assetUrl = 'asset://assets/sounds/bruh-sound-effect.mp3';
      const expectedAssetPath = 'assets/sounds/bruh-sound-effect.mp3';
      when(
        () => mockPlayer.setAsset(expectedAssetPath),
      ).thenAnswer((_) async => const Duration(seconds: 5));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.loadAudio(assetUrl);

      verify(() => mockPlayer.setAsset(expectedAssetPath)).called(1);
      expect(duration, const Duration(seconds: 5));
    });

    test('loadAudioFromFile loads audio from file path', () async {
      const testPath = '/path/to/audio.aac';
      when(
        () => mockPlayer.setFilePath(testPath),
      ).thenAnswer((_) async => const Duration(seconds: 15));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.loadAudioFromFile(testPath);

      verify(() => mockPlayer.setFilePath(testPath)).called(1);
      expect(duration, const Duration(seconds: 15));
    });

    test(
      'setAudioSource plays a remote sound from its downloaded file',
      () async {
        const testUrl = 'https://example.com/audio.mp3';
        when(
          () => mockPlayer.setAudioSource(any()),
        ).thenAnswer((_) async => const Duration(seconds: 20));
        final cache = _FakeRemoteAudioCache();

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
          remoteAudioCache: cache,
        );
        final duration = await service.setAudioSource(
          const AudioSourceConfig.network(testUrl),
        );

        final capturedSource =
            verify(
                  () => mockPlayer.setAudioSource(captureAny()),
                ).captured.single
                as UriAudioSource;
        expect(cache.requested, [Uri.parse(testUrl)]);
        expect(capturedSource.uri, Uri.file(_cachedFileFor(testUrl).path));
        expect(duration, const Duration(seconds: 20));
      },
    );

    test(
      'setAudioSource creates clipped source when boundaries given',
      () async {
        when(
          () => mockPlayer.setAudioSource(any()),
        ).thenAnswer((_) async => const Duration(seconds: 5));

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );
        final duration = await service.setAudioSource(
          const AudioSourceConfig.asset(
            'assets/sounds/clip.mp3',
            start: Duration(seconds: 2),
            end: Duration(seconds: 7),
          ),
        );

        verify(() => mockPlayer.setAudioSource(any())).called(1);
        expect(duration, const Duration(seconds: 5));
      },
    );

    test('setAudioSource creates clipped source from file path', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 5));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.setAudioSource(
        const AudioSourceConfig.file(
          '/path/to/local.mp3',
          start: Duration(seconds: 1),
          end: Duration(seconds: 4),
        ),
      );

      final capturedSource =
          verify(() => mockPlayer.setAudioSource(captureAny())).captured.single
              as ClippingAudioSource;
      expect(capturedSource.child.uri.scheme, 'file');
      expect(duration, const Duration(seconds: 5));
    });

    test('setAudioSource sets audio source from file path', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 12));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.setAudioSource(
        const AudioSourceConfig.file('/path/to/local.mp3'),
      );

      verify(() => mockPlayer.setAudioSource(any())).called(1);
      expect(duration, const Duration(seconds: 12));
    });

    test('setAudioSource keeps non-http URIs as direct URI sources', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 7));
      final cache = _FakeRemoteAudioCache();

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: cache,
      );
      final duration = await service.setAudioSource(
        const AudioSourceConfig.network('ftp://example.com/audio.mp3'),
      );

      final capturedSource =
          verify(() => mockPlayer.setAudioSource(captureAny())).captured.single
              as UriAudioSource;
      expect(cache.requested, isEmpty);
      expect(capturedSource.uri.scheme, 'ftp');
      expect(duration, const Duration(seconds: 7));
    });

    test(
      'setAudioSource clips a remote sound from its downloaded file',
      () async {
        const testUrl = 'https://example.com/audio.mp3';
        when(
          () => mockPlayer.setAudioSource(any()),
        ).thenAnswer((_) async => const Duration(seconds: 6));

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
          remoteAudioCache: _FakeRemoteAudioCache(),
        );
        final duration = await service.setAudioSource(
          const AudioSourceConfig.network(
            testUrl,
            start: Duration(seconds: 1),
            end: Duration(seconds: 4),
          ),
        );

        final capturedSource =
            verify(
                  () => mockPlayer.setAudioSource(captureAny()),
                ).captured.single
                as ClippingAudioSource;
        expect(
          capturedSource.child.uri,
          Uri.file(_cachedFileFor(testUrl).path),
        );
        expect(capturedSource.start, const Duration(seconds: 1));
        expect(capturedSource.end, const Duration(seconds: 4));
        expect(duration, const Duration(seconds: 6));
      },
    );

    test('play starts playback', () async {
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.play();

      verify(() => mockPlayer.play()).called(1);
    });

    test('pause pauses playback', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.pause();

      verify(() => mockPlayer.pause()).called(1);
    });

    test('stop stops playback', () async {
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.stop();

      verify(() => mockPlayer.stop()).called(1);
    });

    test('seek seeks to position', () async {
      const position = Duration(seconds: 5);
      when(() => mockPlayer.seek(position)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.seek(position);

      verify(() => mockPlayer.seek(position)).called(1);
    });

    test('positionStream exposes player position stream', () async {
      final positionController = BehaviorSubject<Duration>.seeded(
        Duration.zero,
      );
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => positionController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.positionStream, emits(Duration.zero));

      await positionController.close();
    });

    test('durationStream exposes player duration stream', () async {
      final durationController = BehaviorSubject<Duration?>.seeded(
        const Duration(seconds: 10),
      );
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => durationController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.durationStream, emits(const Duration(seconds: 10)));

      await durationController.close();
    });

    test('playingStream exposes player playing stream', () async {
      final playingController = BehaviorSubject<bool>.seeded(false);
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => playingController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.playingStream, emits(false));

      await playingController.close();
    });

    test('duration returns current duration from player', () {
      when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 10));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.duration, const Duration(seconds: 10));
    });

    test('dispose cleans up resources', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      verify(() => mockPlayer.dispose()).called(1);
    });

    test('isPlaying returns current playing state', () {
      when(() => mockPlayer.playing).thenReturn(true);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.isPlaying, isTrue);
    });

    test('setVolume sets the volume', () async {
      when(() => mockPlayer.setVolume(0.5)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.setVolume(0.5);

      verify(() => mockPlayer.setVolume(0.5)).called(1);
    });

    group('setLooping', () {
      late StreamController<Duration> positions;
      late StreamController<ProcessingState> states;

      setUp(() {
        positions = StreamController<Duration>.broadcast();
        states = StreamController<ProcessingState>.broadcast();
        addTearDown(positions.close);
        addTearDown(states.close);
        when(
          () => mockPlayer.positionStream,
        ).thenAnswer((_) => positions.stream);
        when(
          () => mockPlayer.processingStateStream,
        ).thenAnswer((_) => states.stream);
        when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 4));
        when(() => mockPlayer.playing).thenReturn(true);
        when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );
      });

      test('starts the audio over when its position reaches the end', () async {
        service.setLooping(looping: true);

        positions.add(const Duration(seconds: 2));
        await pumpEventQueue();
        verifyNever(() => mockPlayer.seek(any()));

        positions.add(const Duration(seconds: 4));
        await pumpEventQueue();
        verify(() => mockPlayer.seek(Duration.zero)).called(1);
      });

      test('starts the audio over when the player completes', () async {
        service.setLooping(looping: true);

        states.add(ProcessingState.completed);
        await pumpEventQueue();

        verify(() => mockPlayer.seek(Duration.zero)).called(1);
      });

      test('leaves paused audio at its end', () async {
        when(() => mockPlayer.playing).thenReturn(false);
        service.setLooping(looping: true);

        positions.add(const Duration(seconds: 4));
        await pumpEventQueue();

        verifyNever(() => mockPlayer.seek(any()));
      });

      test('stops starting over once turned off', () async {
        service
          ..setLooping(looping: true)
          ..setLooping(looping: false);

        states.add(ProcessingState.completed);
        await pumpEventQueue();

        verifyNever(() => mockPlayer.seek(any()));
      });

      test('keeps going when starting over fails', () async {
        when(() => mockPlayer.seek(any())).thenThrow(Exception('seek failed'));
        service.setLooping(looping: true);

        states.add(ProcessingState.completed);
        await pumpEventQueue();

        verify(() => mockPlayer.seek(Duration.zero)).called(1);
      });
    });

    test('setVolume clamps volume above 1.0', () async {
      when(() => mockPlayer.setVolume(1)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.setVolume(1.5);

      verify(() => mockPlayer.setVolume(1)).called(1);
    });

    test('setVolume clamps volume below 0.0', () async {
      when(() => mockPlayer.setVolume(0)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.setVolume(-0.5);

      verify(() => mockPlayer.setVolume(0)).called(1);
    });

    test('dispose does nothing if already disposed', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();
      await service.dispose(); // Second call should be no-op

      verify(() => mockPlayer.dispose()).called(1);
    });
  });

  group('$AudioPlaybackService error handling', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('loadAudio rethrows on error', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenThrow(Exception('Network error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: _FakeRemoteAudioCache(),
      );

      expect(
        () => service.loadAudio('https://example.com/audio.mp3'),
        throwsException,
      );
    });

    test('loadAudioFromFile rethrows on error', () async {
      when(
        () => mockPlayer.setFilePath(any()),
      ).thenThrow(Exception('File not found'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(
        () => service.loadAudioFromFile('/path/to/file.mp3'),
        throwsException,
      );
    });

    test('setAudioSource rethrows on error', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenThrow(Exception('Invalid source'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: _FakeRemoteAudioCache(),
      );

      expect(
        () => service.setAudioSource(
          const AudioSourceConfig.network('https://example.com/bad.mp3'),
        ),
        throwsException,
      );
    });

    test('play rethrows on error', () async {
      when(() => mockPlayer.play()).thenThrow(Exception('Playback failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.play(), throwsException);
    });

    test('pause rethrows on error', () async {
      when(() => mockPlayer.pause()).thenThrow(Exception('Pause failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.pause(), throwsException);
    });

    test('stop rethrows on error', () async {
      when(() => mockPlayer.stop()).thenThrow(Exception('Stop failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.stop(), throwsException);
    });

    test('seek rethrows on error', () async {
      when(() => mockPlayer.seek(any())).thenThrow(Exception('Seek failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.seek(Duration.zero), throwsException);
    });

    test('setVolume rethrows on error', () async {
      when(
        () => mockPlayer.setVolume(any()),
      ).thenThrow(Exception('Volume failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.setVolume(0.5), throwsException);
    });

    test('loadAudio from asset rethrows on error', () async {
      when(
        () => mockPlayer.setAsset(any()),
      ).thenThrow(Exception('Asset not found'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(
        () => service.loadAudio('asset://assets/sounds/test.mp3'),
        throwsException,
      );
    });
  });

  group('$AudioPlaybackService loading interrupted retry', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'play retries and succeeds after Loading interrupted with URL source',
      () async {
        when(
          () => mockPlayer.setAudioSource(any()),
        ).thenAnswer((_) async => const Duration(seconds: 10));

        var playCallCount = 0;
        when(() => mockPlayer.play()).thenAnswer((_) async {
          if (playCallCount++ == 0) {
            throw Exception('Loading interrupted');
          }
        });

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
          remoteAudioCache: _FakeRemoteAudioCache(),
        );
        await service.loadAudio('https://example.com/audio.mp3');
        await service.play();

        verify(() => mockPlayer.play()).called(2);
      },
    );

    test(
      'play rethrows after Loading interrupted when reload also fails',
      () async {
        var playCallCount = 0;
        when(() => mockPlayer.play()).thenAnswer((_) async {
          if (playCallCount++ == 0) {
            throw Exception('Loading interrupted');
          }
        });

        // Reload throws on the second load attempt.
        var setSourceCallCount = 0;
        when(() => mockPlayer.setAudioSource(any())).thenAnswer((_) async {
          if (setSourceCallCount++ > 0) throw Exception('Reload failed');
          return const Duration(seconds: 10);
        });

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
          remoteAudioCache: _FakeRemoteAudioCache(),
        );
        await service.loadAudio('https://example.com/audio.mp3');

        await expectLater(service.play(), throwsException);
      },
    );

    test(
      'play retries and succeeds after Loading interrupted with file source',
      () async {
        when(
          () => mockPlayer.setFilePath(any()),
        ).thenAnswer((_) async => const Duration(seconds: 10));

        var playCallCount = 0;
        when(() => mockPlayer.play()).thenAnswer((_) async {
          if (playCallCount++ == 0) {
            throw Exception('Loading interrupted');
          }
        });

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );
        await service.loadAudioFromFile('/local/audio.mp3');
        await service.play();

        verify(() => mockPlayer.play()).called(2);
      },
    );

    test(
      'play retries and succeeds after Loading interrupted with audio source',
      () async {
        when(
          () => mockPlayer.setAudioSource(any()),
        ).thenAnswer((_) async => const Duration(seconds: 10));

        var playCallCount = 0;
        when(() => mockPlayer.play()).thenAnswer((_) async {
          if (playCallCount++ == 0) {
            throw Exception('Loading interrupted');
          }
        });

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
          remoteAudioCache: _FakeRemoteAudioCache(),
        );
        await service.setAudioSource(
          const AudioSourceConfig.network('https://example.com/audio.mp3'),
        );
        await service.play();

        verify(() => mockPlayer.play()).called(2);
      },
    );

    test('seek retries and succeeds after Loading interrupted', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 10));

      var seekCallCount = 0;
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {
        if (seekCallCount++ == 0) {
          throw Exception('Loading interrupted');
        }
      });

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: _FakeRemoteAudioCache(),
      );
      await service.loadAudio('https://example.com/audio.mp3');
      await service.seek(const Duration(seconds: 5));

      verify(() => mockPlayer.seek(any())).called(2);
    });
  });

  group('$AudioPlaybackService remote sounds', () {
    const soundUrl = 'https://example.com/sound';
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
    });

    AudioPlaybackService serviceWith(RemoteAudioCache cache) {
      final service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: cache,
      );
      addTearDown(service.dispose);
      return service;
    }

    // Regression for the HTTP 502/404 crash: just_audio's
    // LockCachingAudioSource downloaded inside the player, so a server error
    // escaped as an unhandled error instead of failing loadAudio.
    test('loadAudio throws a failed download to its caller', () async {
      final error = RemoteAudioDownloadException(
        Uri.parse(soundUrl),
        statusCode: 502,
      );
      final service = serviceWith(_FakeRemoteAudioCache(error: error));

      await expectLater(
        service.loadAudio(soundUrl),
        throwsA(
          isA<RemoteAudioDownloadException>().having(
            (e) => e.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
      verifyNever(() => mockPlayer.setAudioSource(any()));
    });

    test('setAudioSource throws a failed download to its caller', () async {
      final error = RemoteAudioDownloadException(
        Uri.parse(soundUrl),
        statusCode: 404,
      );
      final service = serviceWith(_FakeRemoteAudioCache(error: error));

      await expectLater(
        service.setAudioSource(const AudioSourceConfig.network(soundUrl)),
        throwsA(isA<RemoteAudioDownloadException>()),
      );
      verifyNever(() => mockPlayer.setAudioSource(any()));
    });

    test(
      'a sound that finishes downloading after a later load gives way',
      () async {
        when(
          () => mockPlayer.setFilePath(any()),
        ).thenAnswer((_) async => const Duration(seconds: 3));
        final cache = _HeldRemoteAudioCache();
        final service = serviceWith(cache);

        final first = service.loadAudio(soundUrl);
        await service.loadAudioFromFile('/imported.m4a');
        cache.finish(soundUrl);

        await expectLater(first, throwsA(isA<PlayerInterruptedException>()));
        verify(() => mockPlayer.setFilePath('/imported.m4a')).called(1);
        verifyNever(() => mockPlayer.setAudioSource(any()));
      },
    );

    test('play waiting on a load that gave way is released', () async {
      when(
        () => mockPlayer.setFilePath(any()),
      ).thenAnswer((_) async => const Duration(seconds: 3));
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      final cache = _HeldRemoteAudioCache();
      final service = serviceWith(cache);

      final first = service.loadAudio(soundUrl);
      var played = false;
      final playing = service.play().then((_) => played = true);
      await service.loadAudioFromFile('/imported.m4a');
      cache.finish(soundUrl);
      await expectLater(first, throwsA(isA<PlayerInterruptedException>()));
      await pumpEventQueue();

      expect(played, isTrue);
      await playing;
      verify(() => mockPlayer.play()).called(1);
    });

    test('plays a remote URL directly when downloads are off', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 2));
      final cache = _FakeRemoteAudioCache();
      final service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: cache,
        downloadRemoteAudio: false,
      );
      addTearDown(service.dispose);

      await service.loadAudio(soundUrl);

      final capturedSource =
          verify(() => mockPlayer.setAudioSource(captureAny())).captured.single
              as UriAudioSource;
      expect(capturedSource.uri, Uri.parse(soundUrl));
      expect(cache.requested, isEmpty);
    });

    test('loadAudio returns null when disposed during the download', () async {
      final cache = _HeldRemoteAudioCache();
      final service = serviceWith(cache);

      final loading = service.loadAudio(soundUrl);
      await service.dispose();
      cache.finish(soundUrl);

      expect(await loading, isNull);
      verifyNever(() => mockPlayer.setAudioSource(any()));
    });

    test(
      'setAudioSource returns null when disposed during the download',
      () async {
        final cache = _HeldRemoteAudioCache();
        final service = serviceWith(cache);

        final loading = service.setAudioSource(
          const AudioSourceConfig.network(soundUrl),
        );
        await service.dispose();
        cache.finish(soundUrl);

        expect(await loading, isNull);
        verifyNever(() => mockPlayer.setAudioSource(any()));
      },
    );
  });

  group('AudioPlaybackService headphone detection', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('headphonesConnectedStream emits headphone state', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // The service should expose a stream for headphone state
      expect(service.headphonesConnectedStream, isA<Stream<bool>>());
    });

    test('areHeadphonesConnected returns current state', () {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should return a boolean indicating current headphone state
      expect(service.areHeadphonesConnected, isA<bool>());
    });

    test('detects wired headphones', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Allow async initialization to complete
      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('detects wired headset', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadset),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('detects Bluetooth A2DP devices', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.bluetoothA2dp),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('detects Bluetooth SCO devices', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.bluetoothSco),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('returns false when no headphones connected', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.builtInSpeaker),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isFalse);
    });

    test('handles getDevices exception gracefully', () async {
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenThrow(Exception('Device error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      // Should default to false on error
      expect(service.areHeadphonesConnected, isFalse);
    });

    test('handles device change stream events', () async {
      final deviceChangeController =
          StreamController<audio_session.AudioDevicesChangedEvent>.broadcast();

      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => deviceChangeController.stream);

      // First call returns no headphones
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isFalse);

      // Update mock to return headphones
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
        },
      );

      // Simulate device change event
      deviceChangeController.add(
        audio_session.AudioDevicesChangedEvent(
          devicesAdded: {
            _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
          },
          devicesRemoved: {},
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isTrue);

      await deviceChangeController.close();
    });

    test('discards stale getDevices result from earlier event', () async {
      final deviceChangeController =
          StreamController<audio_session.AudioDevicesChangedEvent>.broadcast();

      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => deviceChangeController.stream);

      // Initial call: no headphones
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isFalse);

      // Simulate race: first event triggers a slow getDevices call,
      // second event triggers a fast one. The slow (stale) result
      // must be discarded so the fast (latest) result wins.
      final slowCompleter = Completer<Set<audio_session.AudioDevice>>();
      var callCount = 0;

      when(() => mockSessionWrapper.getDevices()).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          // First call is slow — returns headphones eventually
          return slowCompleter.future;
        }
        // Second call resolves immediately — no headphones
        return Future.value(<audio_session.AudioDevice>{});
      });

      // Fire two device change events in rapid succession
      final dummyEvent = audio_session.AudioDevicesChangedEvent(
        devicesAdded: <audio_session.AudioDevice>{},
        devicesRemoved: <audio_session.AudioDevice>{},
      );
      deviceChangeController
        ..add(dummyEvent)
        ..add(dummyEvent);

      // Let the second (fast) call resolve
      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isFalse);

      // Now the slow first call resolves with headphones attached
      slowCompleter.complete({
        _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
      });
      await Future<void>.delayed(Duration.zero);

      // Stale result must be discarded — state must still be false
      expect(service.areHeadphonesConnected, isFalse);

      await deviceChangeController.close();
    });

    test('handles device change stream errors', () async {
      final deviceChangeController =
          StreamController<audio_session.AudioDevicesChangedEvent>.broadcast();

      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => deviceChangeController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      // Simulate error in stream
      deviceChangeController.addError(Exception('Stream error'));

      await Future<void>.delayed(Duration.zero);

      // Service should still be functional
      expect(service.areHeadphonesConnected, isA<bool>());

      await deviceChangeController.close();
    });
  });

  group('AudioPlaybackService audio session configuration', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'configureForRecording sets up audio session for recording mode',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        // Should not throw
        await expectLater(service.configureForRecording(), completes);
      },
    );

    test('resetAudioSession resets to default configuration', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw
      await expectLater(service.resetAudioSession(), completes);
    });

    test('configureForRecording handles errors gracefully', () async {
      when(
        () => mockSessionWrapper.configure(any()),
      ).thenThrow(Exception('Configure error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw - errors are caught internally
      await expectLater(service.configureForRecording(), completes);
    });

    test('resetAudioSession handles errors gracefully', () async {
      when(
        () => mockSessionWrapper.configure(any()),
      ).thenThrow(Exception('Reset error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw - errors are caught internally
      await expectLater(service.resetAudioSession(), completes);
    });

    test(
      'configureForRecording calls configure with correct parameters',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        await service.configureForRecording();

        verify(() => mockSessionWrapper.configure(any())).called(1);
      },
    );

    test('resetAudioSession calls configure with correct parameters', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await service.resetAudioSession();

      verify(() => mockSessionWrapper.configure(any())).called(1);
    });

    test(
      'configureForMixedPlayback sets up audio session for mixed playback',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        // Should not throw
        await expectLater(service.configureForMixedPlayback(), completes);
      },
    );

    test('configureForMixedPlayback handles errors gracefully', () async {
      when(
        () => mockSessionWrapper.configure(any()),
      ).thenThrow(Exception('Configure error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw - errors are caught internally
      await expectLater(service.configureForMixedPlayback(), completes);
    });

    test(
      'configureForMixedPlayback calls configure with correct parameters',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        await service.configureForMixedPlayback();

        verify(() => mockSessionWrapper.configure(any())).called(1);
      },
    );
  });

  group('$AudioPlaybackService after dispose', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    test('loadAudio returns null after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: _FakeRemoteAudioCache(),
      );
      await service.dispose();

      final result = await service.loadAudio('https://example.com/audio.aac');

      expect(result, isNull);
      verifyNever(() => mockPlayer.setAudioSource(any()));
    });

    test('loadAudioFromFile returns null after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      final result = await service.loadAudioFromFile('/path/to/file.aac');

      expect(result, isNull);
      verifyNever(() => mockPlayer.setFilePath(any()));
    });

    test('setAudioSource returns null after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
        remoteAudioCache: _FakeRemoteAudioCache(),
      );
      await service.dispose();

      final result = await service.setAudioSource(
        const AudioSourceConfig.network('https://example.com/audio.mp3'),
      );

      expect(result, isNull);
      verifyNever(() => mockPlayer.setAudioSource(any()));
    });

    test('play does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.play();

      verifyNever(() => mockPlayer.play());
    });

    test('pause does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.pause();

      verifyNever(() => mockPlayer.pause());
    });

    test('stop does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.stop();

      verifyNever(() => mockPlayer.stop());
    });

    test('seek does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.seek(const Duration(seconds: 5));

      verifyNever(() => mockPlayer.seek(any()));
    });

    test('setVolume does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.setVolume(0.5);

      verifyNever(() => mockPlayer.setVolume(any()));
    });

    test('configureForRecording does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.configureForRecording();

      verifyNever(() => mockSessionWrapper.configure(any()));
    });

    test('configureForMixedPlayback does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.configureForMixedPlayback();

      verifyNever(() => mockSessionWrapper.configure(any()));
    });

    test('resetAudioSession does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.resetAudioSession();

      verifyNever(() => mockSessionWrapper.configure(any()));
    });
  });
}
