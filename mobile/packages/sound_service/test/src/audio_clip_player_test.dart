// ABOUTME: Tests for AudioClipPlayer clipped audio playback wrapper
// ABOUTME: Validates setClip, playback controls, completionStream, dispose

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _FakeAudioSource extends Fake implements AudioSource {}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, List<int> bytes)
    : _bytes = List<int>.unmodifiable(bytes);

  @override
  final int statusCode;

  final List<int> _bytes;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<HttpClientResponse> _okHttpResponse(Invocation _) async =>
    _FakeHttpClientResponse(HttpStatus.ok, const [1, 2, 3, 4]);

Future<HttpClientResponse> _notFoundHttpResponse(Invocation _) async =>
    _FakeHttpClientResponse(HttpStatus.notFound, const []);

/// A `List<int>` that reports an arbitrary [length] without allocating
/// any backing storage. Used to drive the maxBytes guard in the default
/// remote audio loader without allocating ~50 MB of real bytes.
class _FakeOversizedChunk with ListMixin<int> {
  _FakeOversizedChunk(this._length);

  final int _length;

  @override
  int get length => _length;

  @override
  set length(int newLength) => throw UnsupportedError('readonly');

  @override
  int operator [](int index) => 0;

  @override
  void operator []=(int index, int value) => throw UnsupportedError('readonly');
}

/// HTTP response that yields a single fake chunk reporting [byteCount]
/// bytes. Never materializes the bytes — useful for size-limit tests.
class _OversizedHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _OversizedHttpClientResponse(this.byteCount);

  final int byteCount;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => byteCount;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([
      _FakeOversizedChunk(byteCount),
    ]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<HttpClientRequest> Function(Invocation) _httpRequestAnswer(
  HttpClientRequest request,
) {
  return (_) async => request;
}

HttpClient Function(SecurityContext?) _httpClientFactory(HttpClient client) {
  return (_) => client;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAudioSource());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group(AudioClipPlayer, () {
    late AudioClipPlayer player;
    late _MockAudioPlayer mockAudioPlayer;

    setUp(() {
      mockAudioPlayer = _MockAudioPlayer();

      when(() => mockAudioPlayer.playing).thenReturn(false);
      when(
        () => mockAudioPlayer.playerStateStream,
      ).thenAnswer((_) => const Stream<PlayerState>.empty());
      when(
        () => mockAudioPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 10));
      when(() => mockAudioPlayer.play()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.pause()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.stop()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});

      player = AudioClipPlayer(audioPlayer: mockAudioPlayer);
    });

    tearDown(() async {
      await player.dispose();
    });

    group('isPlaying', () {
      test('returns false when not playing', () {
        when(() => mockAudioPlayer.playing).thenReturn(false);

        expect(player.isPlaying, isFalse);
      });

      test('returns true when playing', () {
        when(() => mockAudioPlayer.playing).thenReturn(true);

        expect(player.isPlaying, isTrue);
      });
    });

    group('completionStream', () {
      test('emits when processing state is completed', () async {
        final controller = StreamController<PlayerState>();
        when(
          () => mockAudioPlayer.playerStateStream,
        ).thenAnswer((_) => controller.stream);

        final emissions = <void>[];
        final sub = player.completionStream.listen(emissions.add);

        controller
          ..add(PlayerState(false, ProcessingState.ready))
          ..add(PlayerState(true, ProcessingState.ready))
          ..add(PlayerState(false, ProcessingState.completed));

        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(1));

        await sub.cancel();
        await controller.close();
      });

      test('does not emit for non-completed states', () async {
        final controller = StreamController<PlayerState>();
        when(
          () => mockAudioPlayer.playerStateStream,
        ).thenAnswer((_) => controller.stream);

        final emissions = <void>[];
        final sub = player.completionStream.listen(emissions.add);

        controller
          ..add(PlayerState(false, ProcessingState.idle))
          ..add(PlayerState(true, ProcessingState.loading))
          ..add(PlayerState(true, ProcessingState.buffering))
          ..add(PlayerState(true, ProcessingState.ready));

        await Future<void>.delayed(Duration.zero);

        expect(emissions, isEmpty);

        await sub.cancel();
        await controller.close();
      });
    });

    group('setClip', () {
      test('sets network audio source', () async {
        var loaderCallCount = 0;
        player = AudioClipPlayer(
          audioPlayer: mockAudioPlayer,
          remoteAudioFileLoader: (uri, cachedFile, cachedUri) async {
            loaderCallCount++;
            final dir = Directory.systemTemp.createTempSync('audio_clip_test_');
            final file = File('${dir.path}/clip.mp3')
              ..writeAsBytesSync(const [1, 2, 3], flush: true);
            return file;
          },
        );

        await player.setClip(
          const AudioSourceConfig.network(
            'https://example.com/audio.mp3',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5),
          ),
        );

        final capturedSource =
            verify(
                  () => mockAudioPlayer.setAudioSource(captureAny()),
                ).captured.single
                as ClippingAudioSource;
        expect(capturedSource.child.uri.scheme, 'file');
        expect(loaderCallCount, 1);
      });

      test(
        'reuses cached file for repeated network clips from same URI',
        () async {
          File? cachedFile;
          var loaderCallCount = 0;
          player = AudioClipPlayer(
            audioPlayer: mockAudioPlayer,
            remoteAudioFileLoader: (uri, existingFile, existingUri) async {
              loaderCallCount++;
              if (existingFile != null &&
                  existingUri == uri &&
                  existingFile.existsSync()) {
                return existingFile;
              }

              final dir = Directory.systemTemp.createTempSync(
                'audio_clip_test_',
              );
              cachedFile = File('${dir.path}/clip.mp3');
              cachedFile!.writeAsBytesSync(const [1, 2, 3], flush: true);
              return cachedFile!;
            },
          );

          const source = AudioSourceConfig.network(
            'https://example.com/audio.mp3',
            start: Duration(seconds: 1),
            end: Duration(seconds: 5),
          );

          await player.setClip(source);
          await player.setClip(
            const AudioSourceConfig.network(
              'https://example.com/audio.mp3',
              start: Duration(seconds: 2),
              end: Duration(seconds: 6),
            ),
          );

          verify(() => mockAudioPlayer.setAudioSource(any())).called(2);
          expect(loaderCallCount, 2);
          expect(cachedFile, isNotNull);
          expect(cachedFile!.existsSync(), isTrue);
        },
      );

      test(
        'clears cached remote file when switching away from network audio',
        () async {
          late File cachedFile;
          late File siblingFile;
          player = AudioClipPlayer(
            audioPlayer: mockAudioPlayer,
            remoteAudioFileLoader: (uri, existingFile, existingUri) async {
              final dir = Directory.systemTemp.createTempSync(
                'audio_clip_test_',
              );
              siblingFile = File('${dir.path}/keep.txt')
                ..writeAsStringSync('keep', flush: true);
              return cachedFile = File('${dir.path}/clip.mp3')
                ..writeAsBytesSync(const [1, 2, 3], flush: true);
            },
          );

          await player.setClip(
            const AudioSourceConfig.network(
              'https://example.com/audio.mp3',
              start: Duration(seconds: 1),
              end: Duration(seconds: 5),
            ),
          );

          await player.setClip(
            const AudioSourceConfig.asset(
              'assets/sounds/clip.mp3',
              start: Duration.zero,
              end: Duration(seconds: 3),
            ),
          );

          expect(cachedFile.existsSync(), isFalse);
          expect(siblingFile.existsSync(), isTrue);
        },
      );

      test(
        'downloads and caches network audio with the default loader',
        () async {
          final mockHttpClient = _MockHttpClient();
          final mockRequest = _MockHttpClientRequest();
          when(
            () => mockHttpClient.getUrl(any()),
          ).thenAnswer(_httpRequestAnswer(mockRequest));
          when(mockRequest.close).thenAnswer(_okHttpResponse);

          await HttpOverrides.runZoned(
            () => player.setClip(
              const AudioSourceConfig.network(
                'https://example.com/remote clip.m4a',
                start: Duration.zero,
                end: Duration(seconds: 2),
              ),
            ),
            createHttpClient: _httpClientFactory(mockHttpClient),
          );

          final capturedSource =
              verify(
                    () => mockAudioPlayer.setAudioSource(captureAny()),
                  ).captured.single
                  as ClippingAudioSource;
          expect(capturedSource.child.uri.scheme, 'file');
          expect(capturedSource.child.uri.pathSegments.last, 'remote_clip.m4a');
        },
      );

      test(
        'reuses the default cached file for repeated network clips',
        () async {
          final mockHttpClient = _MockHttpClient();
          final mockRequest = _MockHttpClientRequest();
          when(
            () => mockHttpClient.getUrl(any()),
          ).thenAnswer(_httpRequestAnswer(mockRequest));
          when(mockRequest.close).thenAnswer(_okHttpResponse);

          const uri = 'https://example.com';

          await HttpOverrides.runZoned(
            () => player.setClip(
              const AudioSourceConfig.network(
                uri,
                start: Duration.zero,
                end: Duration(seconds: 2),
              ),
            ),
            createHttpClient: _httpClientFactory(mockHttpClient),
          );
          await HttpOverrides.runZoned(
            () => player.setClip(
              const AudioSourceConfig.network(
                uri,
                start: Duration(seconds: 1),
                end: Duration(seconds: 3),
              ),
            ),
            createHttpClient: _httpClientFactory(mockHttpClient),
          );

          final capturedSources = verify(
            () => mockAudioPlayer.setAudioSource(captureAny()),
          ).captured.cast<ClippingAudioSource>();
          expect(capturedSources, hasLength(2));
          expect(
            capturedSources.first.child.uri.path,
            capturedSources.last.child.uri.path,
          );
          expect(
            capturedSources.last.child.uri.pathSegments.last,
            'audio_clip',
          );
          verify(() => mockHttpClient.getUrl(any())).called(1);
        },
      );

      test(
        'replaces the default cached file when the network URI changes',
        () async {
          final mockHttpClient = _MockHttpClient();
          final mockRequest = _MockHttpClientRequest();
          when(
            () => mockHttpClient.getUrl(any()),
          ).thenAnswer(_httpRequestAnswer(mockRequest));
          when(mockRequest.close).thenAnswer(_okHttpResponse);

          await HttpOverrides.runZoned(
            () => player.setClip(
              const AudioSourceConfig.network(
                'https://example.com/first.m4a',
                start: Duration.zero,
                end: Duration(seconds: 2),
              ),
            ),
            createHttpClient: _httpClientFactory(mockHttpClient),
          );

          final firstSource =
              verify(
                    () => mockAudioPlayer.setAudioSource(captureAny()),
                  ).captured.single
                  as ClippingAudioSource;
          final firstFile = File(firstSource.child.uri.toFilePath());
          expect(firstFile.existsSync(), isTrue);

          await HttpOverrides.runZoned(
            () => player.setClip(
              const AudioSourceConfig.network(
                'https://example.com/second.m4a',
                start: Duration.zero,
                end: Duration(seconds: 2),
              ),
            ),
            createHttpClient: _httpClientFactory(mockHttpClient),
          );

          final secondSource =
              verify(
                    () => mockAudioPlayer.setAudioSource(captureAny()),
                  ).captured.last
                  as ClippingAudioSource;
          expect(
            secondSource.child.uri.path,
            isNot(firstSource.child.uri.path),
          );
          expect(firstFile.existsSync(), isFalse);
        },
      );

      test(
        'throws when the default network loader gets a non-success response',
        () async {
          final mockHttpClient = _MockHttpClient();
          final mockRequest = _MockHttpClientRequest();
          when(
            () => mockHttpClient.getUrl(any()),
          ).thenAnswer(_httpRequestAnswer(mockRequest));
          when(mockRequest.close).thenAnswer(_notFoundHttpResponse);

          await expectLater(
            HttpOverrides.runZoned(
              () => player.setClip(
                const AudioSourceConfig.network(
                  'https://example.com/missing.m4a',
                  start: Duration.zero,
                  end: Duration(seconds: 2),
                ),
              ),
              createHttpClient: _httpClientFactory(mockHttpClient),
            ),
            throwsA(isA<HttpException>()),
          );
        },
      );

      test(
        'throws when the default network loader exceeds the byte limit',
        () async {
          final mockHttpClient = _MockHttpClient();
          final mockRequest = _MockHttpClientRequest();
          when(
            () => mockHttpClient.getUrl(any()),
          ).thenAnswer(_httpRequestAnswer(mockRequest));
          // 50 MiB + 1 byte — exceeds the loader's hard cap.
          when(mockRequest.close).thenAnswer(
            (_) async => _OversizedHttpClientResponse(50 * 1024 * 1024 + 1),
          );

          await expectLater(
            HttpOverrides.runZoned(
              () => player.setClip(
                const AudioSourceConfig.network(
                  'https://example.com/huge.m4a',
                  start: Duration.zero,
                  end: Duration(seconds: 2),
                ),
              ),
              createHttpClient: _httpClientFactory(mockHttpClient),
            ),
            throwsA(
              isA<HttpException>().having(
                (e) => e.message,
                'message',
                contains('byte limit'),
              ),
            ),
          );
        },
      );

      test('sets asset audio source', () async {
        await player.setClip(
          const AudioSourceConfig.asset(
            'assets/sounds/clip.mp3',
            start: Duration.zero,
            end: Duration(seconds: 3),
          ),
        );

        verify(() => mockAudioPlayer.setAudioSource(any())).called(1);
      });

      test('sets file audio source', () async {
        await player.setClip(
          const AudioSourceConfig.file(
            '/path/to/audio.mp3',
            start: Duration(seconds: 2),
            end: Duration(seconds: 8),
          ),
        );

        verify(() => mockAudioPlayer.setAudioSource(any())).called(1);
      });

      // Regression coverage for #4395: a caller that mis-classifies a
      // local file path as network audio must hit an actionable
      // ArgumentError before the default loader reaches HttpClient.
      test(
        'default network loader rejects non-http(s) URIs with ArgumentError',
        () async {
          final mockHttpClient = _MockHttpClient();

          await expectLater(
            HttpOverrides.runZoned(
              () => player.setClip(
                const AudioSourceConfig.network(
                  '/var/mobile/extracted_audio.wav',
                  start: Duration.zero,
                  end: Duration(seconds: 2),
                ),
              ),
              createHttpClient: _httpClientFactory(mockHttpClient),
            ),
            throwsA(isA<ArgumentError>()),
          );

          verifyNever(() => mockHttpClient.getUrl(any()));
        },
      );

      test('AudioSourceConfig.file never invokes the remote loader', () async {
        var loaderCallCount = 0;
        player = AudioClipPlayer(
          audioPlayer: mockAudioPlayer,
          remoteAudioFileLoader: (_, _, _) async {
            loaderCallCount++;
            throw StateError('remote loader must not be called');
          },
        );

        await player.setClip(
          const AudioSourceConfig.file(
            '/var/mobile/extracted_audio.wav',
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
        );

        expect(loaderCallCount, 0);
        verify(() => mockAudioPlayer.setAudioSource(any())).called(1);
      });
    });

    group('play', () {
      test('delegates to audio player', () async {
        await player.play();

        verify(() => mockAudioPlayer.play()).called(1);
      });
    });

    group('pause', () {
      test('delegates to audio player', () async {
        await player.pause();

        verify(() => mockAudioPlayer.pause()).called(1);
      });
    });

    group('stop', () {
      test('delegates to audio player', () async {
        await player.stop();

        verify(() => mockAudioPlayer.stop()).called(1);
      });
    });

    group('seek', () {
      test('delegates to audio player', () async {
        const position = Duration(seconds: 3);
        await player.seek(position);

        verify(() => mockAudioPlayer.seek(position)).called(1);
      });
    });

    group('setVolume', () {
      setUp(() {
        when(() => mockAudioPlayer.setVolume(any())).thenAnswer((_) async {});
      });

      test('delegates to audio player', () async {
        await player.setVolume(0.5);

        verify(() => mockAudioPlayer.setVolume(0.5)).called(1);
      });

      test('clamps out-of-range volumes to 0..1', () async {
        await player.setVolume(1.7);
        await player.setVolume(-0.3);

        verifyInOrder([
          () => mockAudioPlayer.setVolume(1),
          () => mockAudioPlayer.setVolume(0),
        ]);
      });
    });

    group('setSpeed', () {
      test('delegates to audio player', () async {
        when(() => mockAudioPlayer.setSpeed(any())).thenAnswer((_) async {});

        await player.setSpeed(1.5);

        verify(() => mockAudioPlayer.setSpeed(1.5)).called(1);
      });
    });

    group('dispose', () {
      test('disposes the audio player', () async {
        await player.dispose();

        verify(() => mockAudioPlayer.dispose()).called(1);
      });

      test('logs error when dispose throws', () async {
        when(
          () => mockAudioPlayer.dispose(),
        ).thenThrow(Exception('dispose failed'));

        // Should not throw — error is caught and logged.
        await expectLater(player.dispose(), completes);
      });

      test(
        'still deletes cached remote file when audio player dispose throws',
        () async {
          late File cachedFile;
          player = AudioClipPlayer(
            audioPlayer: mockAudioPlayer,
            remoteAudioFileLoader: (uri, existingFile, existingUri) async {
              final dir = Directory.systemTemp.createTempSync(
                'audio_clip_test_',
              );
              return cachedFile = File('${dir.path}/clip.mp3')
                ..writeAsBytesSync(const [1, 2, 3], flush: true);
            },
          );

          await player.setClip(
            const AudioSourceConfig.network(
              'https://example.com/audio.mp3',
              start: Duration.zero,
              end: Duration(seconds: 2),
            ),
          );

          when(
            () => mockAudioPlayer.dispose(),
          ).thenThrow(Exception('dispose failed'));

          await player.dispose();

          expect(cachedFile.existsSync(), isFalse);
        },
      );

      test('deletes cached remote file during dispose', () async {
        late File cachedFile;
        player = AudioClipPlayer(
          audioPlayer: mockAudioPlayer,
          remoteAudioFileLoader: (uri, existingFile, existingUri) async {
            final dir = Directory.systemTemp.createTempSync('audio_clip_test_');
            return cachedFile = File('${dir.path}/clip.mp3')
              ..writeAsBytesSync(const [1, 2, 3], flush: true);
          },
        );

        await player.setClip(
          const AudioSourceConfig.network(
            'https://example.com/audio.mp3',
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
        );

        await player.dispose();

        expect(cachedFile.existsSync(), isFalse);
      });
    });
  });
}
