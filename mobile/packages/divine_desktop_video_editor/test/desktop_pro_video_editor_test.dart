import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:divine_desktop_video_editor/src/desktop_pro_video_editor.dart';
import 'package:divine_desktop_video_editor/src/media_worker_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DesktopProVideoEditor', () {
    late Directory root;
    late DesktopProVideoEditor editor;
    late EditorVideo video;
    var locations = 0;

    setUp(() async {
      locations = 0;
      root = await Directory.systemTemp.createTemp('editor adapter ');
      var directory = Directory.current;
      while (!File('${directory.path}/.dart_tool/package_config.json')
          .existsSync()) {
        directory = directory.parent;
      }
      final config = File('${directory.path}/.dart_tool/package_config.json');
      final json =
          jsonDecode(await config.readAsString()) as Map<String, dynamic>;
      final flutter = (json['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((package) => package['name'] == 'flutter');
      final sdk = Directory.fromUri(
        config.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      final executable =
          '${sdk.path}/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
      editor = DesktopProVideoEditor(
        client: MediaWorkerClient(
          locate: () async {
            locations++;
            return MediaWorkerCommand(
              executable,
              arguments: [
                File('test/fixtures/worker.dart').absolute.path,
              ],
            );
          },
          temporaryDirectory: () async => root,
        ),
      );
      video = EditorVideo.file(
        File('test/fixtures/synthetic-colors.mp4').absolute,
      );
    });
    tearDown(() async {
      await editor.dispose();
      await root.delete(recursive: true);
    });

    test('returns encoded metadata through the existing SDK parser', () async {
      final metadata = await editor.getMetadata(video);
      expect(metadata.resolution.width, 128);
      expect(metadata.resolution.height, 240);
      expect(metadata.duration, const Duration(seconds: 1));
      expect(metadata.frameRate, 20.0);
      expect(await editor.hasAudioTrack(video), isTrue);
    });

    test(
      'accepts audio metadata only with an explicit no-video result',
      () async {
        final result = await editor.methodChannel
            .invokeMethod<Map<Object?, Object?>>('getMetadata', {
              'fixtureResult': {
                'width': 0,
                'height': 0,
                'duration': 1000,
                'hasVideo': false,
              },
            });
        expect(result!['width'], 0);
        expect(result['height'], 0);
        expect(result['duration'], 1000);
        expect(root.listSync(), isEmpty);
      },
    );

    test(
      'commits a completed file before returning its requested path',
      () async {
        final destination = File('${root.path}/finished.mp4');
        await destination.writeAsBytes([42]);
        final values = <double>[];
        final subscription = editor.progressStreamById('render').listen((
          event,
        ) {
          values.add(event.progress);
        });
        final path = await editor.renderVideoToFile(
          destination.path,
          VideoRenderData(
            id: 'render',
            videoSegments: [VideoSegment(video: video)],
          ),
        );
        await pumpEventQueue();
        await subscription.cancel();
        expect(path, destination.path);
        expect(await destination.readAsBytes(), [7, 8, 9]);
        expect(values, [0.25, 1.0]);
        expect(root.listSync().map((file) => file.path), [destination.path]);
      },
    );

    test('returns encoded bytes while retiring its native files', () async {
      final result = await editor.renderVideo(
        VideoRenderData(
          id: 'bytes',
          videoSegments: [VideoSegment(video: video)],
        ),
      );
      expect(result, [7, 8, 9]);
      expect(root.listSync(), isEmpty);
    });

    test(
      'preserves the previous destination after native encoder failure',
      () async {
        final destination = File('${root.path}/keep.mp4');
        await destination.writeAsBytes([42]);
        await expectLater(
          editor.renderVideoToFile(
            destination.path,
            VideoRenderData(
              id: 'fixture-encoder',
              videoSegments: [VideoSegment(video: video)],
            ),
          ),
          throwsA(isA<RenderEncoderException>()),
        );
        expect(await destination.readAsBytes(), [42]);
        expect(root.listSync().map((file) => file.path), [destination.path]);
      },
    );

    test(
      'maps native cancellation to the SDK cancellation exception',
      () async {
        final started = editor.progressStreamById('fixture-block').first;
        final result = editor.renderVideo(
          VideoRenderData(
            id: 'fixture-block',
            videoSegments: [VideoSegment(video: video)],
          ),
        );
        final rejected = expectLater(
          result,
          throwsA(isA<RenderCanceledException>()),
        );
        await started;
        await editor.cancel('fixture-block');
        await rejected;
        expect(root.listSync(), isEmpty);
      },
    );
    test('rejects an empty native artifact before returning bytes', () async {
      await expectLater(
        editor.methodChannel.invokeMethod('renderVideo', {
          'fixtureBytes': <int>[],
        }),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'DESKTOP_MEDIA_PROTOCOL',
          ),
        ),
      );
      expect(root.listSync(), isEmpty);
    });

    test(
      'does not consume an artifact outside the owned job directory',
      () async {
        final protected = await File('${root.path}/protected.bin')
            .writeAsBytes([42]);
        final destination = File('${root.path}/wrong.mp4');
        await expectLater(
          editor.methodChannel.invokeMethod('renderVideo', {
            'outputPath': destination.path,
            'fixtureResult': {'path': protected.path},
          }),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'DESKTOP_MEDIA_PROTOCOL',
            ),
          ),
        );
        expect(await protected.readAsBytes(), [42]);
        expect(destination.existsSync(), isFalse);
        expect(root.listSync().map((file) => file.path), [protected.path]);
      },
    );

    test(
      'cleans staging files when an existing directory cannot be replaced',
      () async {
        final directory = await Directory('${root.path}/keep').create();
        final protected = await File('${directory.path}/keep.bin')
            .writeAsBytes([42]);
        await expectLater(
          editor.renderVideoToFile(
            directory.path,
            VideoRenderData(
              id: 'bad-target',
              videoSegments: [VideoSegment(video: video)],
            ),
          ),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'DESKTOP_MEDIA_STORAGE',
            ),
          ),
        );
        expect(await protected.readAsBytes(), [42]);
        expect(root.listSync().map((file) => file.path), [directory.path]);
      },
    );

    for (final arguments in <Object?>[
      42,
      {1: 'bad-key'},
      {'id': 42},
      {'id': ''},
      {'outputPath': 42},
    ]) {
      test('rejects invalid native request arguments ($arguments)', () async {
        await expectLater(
          editor.methodChannel.invokeMethod('renderVideo', arguments),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'INVALID_REQUEST',
            ),
          ),
        );
        expect(root.listSync(), isEmpty);
      });
    }

    for (final result in <Object?>[
      null,
      [],
      {'width': 0, 'height': 240, 'duration': 1000},
      {'width': 128, 'height': 240, 'duration': -1},
      {'width': 128, 'height': 240, 'duration': 1000, 'frameRate': 'invalid'},
    ]) {
      test('rejects incomplete native metadata ($result)', () async {
        await expectLater(
          editor.methodChannel.invokeMethod('getMetadata', {
            'fixtureResult': result,
          }),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'DESKTOP_MEDIA_PROTOCOL',
            ),
          ),
        );
      });
    }

    test(
      'does not report invalid audio-track output as a valid silent video',
      () async {
        await expectLater(
          editor.methodChannel.invokeMethod('hasAudioTrack', {
            'fixtureResult': null,
          }),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'DESKTOP_MEDIA_PROTOCOL',
            ),
          ),
        );
      },
    );

    test(
      'keeps unsupported operations distinct from encoder failures',
      () async {
        await expectLater(
          editor.renderVideo(
            VideoRenderData(
              id: 'fixture-unsupported',
              videoSegments: [VideoSegment(video: video)],
            ),
          ),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'DESKTOP_MEDIA_UNSUPPORTED',
            ),
          ),
        );
      },
    );

    test(
      'rejects a duplicate SDK task without retiring its existing owner',
      () async {
        final started = editor.progressStreamById('fixture-block').first;
        final request = VideoRenderData(
          id: 'fixture-block',
          videoSegments: [VideoSegment(video: video)],
        );
        final work = editor.renderVideo(request);
        final rejected = expectLater(
          work,
          throwsA(isA<RenderCanceledException>()),
        );
        await started;
        try {
          await expectLater(
            editor.renderVideo(request),
            throwsA(
              isA<PlatformException>().having(
                (error) => error.code,
                'code',
                'TASK_ALREADY_EXISTS',
              ),
            ),
          );
        } finally {
          await editor.cancel('fixture-block');
          await rejected;
        }
      },
    );

    test(
      'retains the SDK not-found result for an unknown cancellation',
      () async {
        await expectLater(
          editor.cancel('unknown'),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'TASK_NOT_FOUND',
            ),
          ),
        );
      },
    );

    test(
      'rejects a response that does not match the SDK result type',
      () async {
        await expectLater(
          editor.getPlatformVersion(),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'DESKTOP_MEDIA_PROTOCOL',
            ),
          ),
        );
      },
    );

    test('disposal cancels native work and closes progress', () async {
      final done = editor.progressStream.drain<void>();
      final started = editor.progressStreamById('fixture-block').first;
      final work = editor.renderVideo(
        VideoRenderData(
          id: 'fixture-block',
          videoSegments: [VideoSegment(video: video)],
        ),
      );
      final rejected = expectLater(
        work,
        throwsA(isA<RenderCanceledException>()),
      );
      await started;
      await editor.dispose();
      await rejected;
      await done;
      expect(root.listSync(), isEmpty);
      await expectLater(
        editor.renderVideo(
          VideoRenderData(
            id: 'late',
            videoSegments: [VideoSegment(video: video)],
          ),
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'DESKTOP_MEDIA_DISPOSED',
          ),
        ),
      );
    });

    group('frame readers', () {
      ThumbnailConfigs thumbnails({String id = 'thumbnails'}) =>
          ThumbnailConfigs(
            id: id,
            video: video,
            outputSize: const Size(64, 64),
            timestamps: const [
              Duration(milliseconds: 100),
              Duration(milliseconds: 800),
            ],
          );

      test('copies thumbnail lists before deleting native artifacts', () async {
        final bytes = await editor.getThumbnails(thumbnails());
        expect(bytes, [
          [1, 2, 3],
          [2, 3, 4],
        ]);
        expect(root.listSync(), isEmpty);
      });

      test('copies streamed images before acknowledging file reuse', () async {
        final frames = await editor.getThumbnailStream(thumbnails()).toList();
        expect(frames.map((frame) => frame.indices), [
          [0],
          [1],
        ]);
        expect(frames.map((frame) => frame.bytes), [
          [1, 2, 3],
          [2, 3, 4],
        ]);
        expect(frames.map((frame) => frame.progress), [0.5, 1]);
        expect(root.listSync(), isEmpty);
      });

      test(
        'parses luma dimensions, source time and owned frame bytes',
        () async {
          final frames = await editor
              .getLumaFrameStream(
                LumaFrameConfigs(
                  video: video,
                  outputSize: const Size(64, 64),
                ),
              )
              .toList();
          expect(frames.map((frame) => frame.width), [3, 3]);
          expect(frames.map((frame) => frame.height), [1, 1]);
          expect(frames.map((frame) => frame.time.inMicroseconds), [
            100000,
            200000,
          ]);
          expect(frames.map((frame) => frame.bytes), [
            [1, 2, 3],
            [2, 3, 4],
          ]);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'subscription cancellation retires its native child and files',
        () async {
          final first = Completer<void>();
          final subscription = editor
              .getThumbnailStream(
                thumbnails(id: 'fixture-stream-block'),
              )
              .listen((frame) {
                first.complete();
              });
          await first.future;
          await subscription.cancel();
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'public cancellation delivers the SDK cancellation exception',
        () async {
          final first = Completer<void>();
          final frames = <ThumbnailFrame>[];
          final errors = <Object>[];
          final done = Completer<void>();
          final subscription = editor
              .getThumbnailStream(
                thumbnails(id: 'fixture-stream-block'),
              )
              .listen(
                (frame) {
                  frames.add(frame);
                  first.complete();
                },
                onError: (Object error) {
                  errors.add(error);
                },
                onDone: done.complete,
              );
          await first.future;
          await editor.cancel('fixture-stream-block');
          await done.future;
          await subscription.cancel();
          expect(frames, hasLength(1));
          expect(errors.single, isA<RenderCanceledException>());
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'rejects a duplicate stream without cancelling its existing owner',
        () async {
          final first = Completer<void>();
          final subscription = editor
              .getThumbnailStream(
                thumbnails(id: 'fixture-stream-block'),
              )
              .listen((frame) {
                first.complete();
              });
          await first.future;
          await expectLater(
            editor
                .getThumbnailStream(thumbnails(id: 'fixture-stream-block'))
                .toList(),
            throwsA(
              isA<PlatformException>().having(
                (error) => error.code,
                'code',
                'TASK_ALREADY_EXISTS',
              ),
            ),
          );
          expect(root.listSync(), hasLength(1));
          await subscription.cancel();
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'disposal awaits active stream cleanup and reports cancellation',
        () async {
          final first = Completer<void>();
          final done = Completer<void>();
          final errors = <Object>[];
          final subscription = editor
              .getThumbnailStream(
                thumbnails(id: 'fixture-stream-block'),
              )
              .listen(
                (frame) {
                  first.complete();
                },
                onError: (Object error) {
                  errors.add(error);
                },
                onDone: done.complete,
              );
          await first.future;
          await editor.dispose();
          await done.future;
          await subscription.cancel();
          expect(errors.single, isA<RenderCanceledException>());
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'preserves empty slots for out-of-range thumbnail requests',
        () async {
          final bytes = await editor.methodChannel.invokeMethod<List<Object?>>(
            'getThumbnails',
            {
              'fixtureResult': [null],
            },
          );
          expect(bytes!.single, isEmpty);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'cancels during input preparation without starting a native child',
        () async {
          final frames = editor
              .getThumbnailStream(thumbnails(id: 'before-dispatch'))
              .toList();
          final rejected = expectLater(
            frames,
            throwsA(isA<RenderCanceledException>()),
          );
          await editor.cancel('before-dispatch');
          await rejected;
          expect(locations, 0);
          expect(root.listSync(), isEmpty);
        },
      );

      test('rejects new frame streams after disposal', () async {
        await editor.dispose();
        await expectLater(
          editor.getThumbnailStream(thumbnails()).toList(),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (error) => error.code,
              'code',
              'disposed',
            ),
          ),
        );
        expect(locations, 0);
      });

      test('holds the frame lease while its subscriber is paused', () async {
        final first = Completer<void>();
        final completed = Completer<void>();
        final nativeCompleted = editor.client.progress.firstWhere(
          (event) => event.value == 1,
        );
        final received = <ThumbnailFrame>[];
        late final StreamSubscription<ThumbnailFrame> subscription;
        subscription = editor.getThumbnailStream(thumbnails()).listen((frame) {
          received.add(frame);
          if (!first.isCompleted) {
            subscription.pause();
            first.complete();
          }
        }, onDone: completed.complete);
        await first.future;
        // Completion is forbidden while a native frame is held by a paused
        // reader. The deadline asserts that absence; it does not settle a race.
        await expectLater(
          nativeCompleted.timeout(const Duration(milliseconds: 200)),
          throwsA(isA<TimeoutException>()),
        );
        expect(root.listSync(), hasLength(1));
        subscription.resume();
        await completed.future;
        await subscription.cancel();
        expect(received.map((frame) => frame.bytes), [
          [1, 2, 3],
          [2, 3, 4],
        ]);
        expect(root.listSync(), isEmpty);
      });

      test(
        'cancelling a paused subscription releases the frame lease',
        () async {
          final first = Completer<void>();
          late final StreamSubscription<ThumbnailFrame> subscription;
          subscription = editor.getThumbnailStream(thumbnails()).listen((
            frame,
          ) {
            subscription.pause();
            first.complete();
          });
          await first.future;
          await subscription.cancel();
          expect(root.listSync(), isEmpty);
        },
      );

      for (final fault in ['progress', 'indices', 'luma']) {
        test('rejects malformed native frame $fault before delivery', () async {
          final id = 'fixture-bad-$fault';
          final stream = fault == 'luma'
              ? editor.getLumaFrameStream(
                  LumaFrameConfigs(
                    id: id,
                    video: video,
                    outputSize: const Size(64, 64),
                  ),
                )
              : editor.getThumbnailStream(thumbnails(id: id));
          await expectLater(
            stream.toList(),
            throwsA(
              isA<PlatformException>().having(
                (error) => error.code,
                'code',
                'DESKTOP_MEDIA_PROTOCOL',
              ),
            ),
          );
          expect(root.listSync(), isEmpty);
        });
      }
    });
  });
}
