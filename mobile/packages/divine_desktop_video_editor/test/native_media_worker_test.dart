import 'dart:io';

import 'package:divine_desktop_video_editor/src/media_worker_client.dart';
import 'package:divine_desktop_video_editor/src/native_media_worker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('video.divine/desktop_media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  group('NativeMediaWorker', () {
    late Directory directory;
    late File executable;
    late NativeMediaWorker worker;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('native locator ');
      executable = await File('${directory.path}/worker')
          .writeAsBytes([1, 2, 3]);
      worker = NativeMediaWorker();
    });
    tearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    });

    test(
      'locates a real installed file without changing the parent environment',
      () async {
        final originalPath = Platform.environment['PATH'];
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'locate');
          return {
            'executable': executable.path,
            'environment': {'PATH': 'private-runtime-path'},
          };
        });
        final command = await worker.locate();
        expect(command.executable, executable.path);
        expect(command.environment, {'PATH': 'private-runtime-path'});
        expect(Platform.environment['PATH'], originalPath);
        expect(
          () => command.environment['PATH'] = 'changed',
          throwsUnsupportedError,
        );
      },
    );

    for (final response in [
      null,
      <String, Object?>{},
      {'executable': 'relative-worker'},
      {'executable': '/missing-worker'},
      {'executable': 42},
    ]) {
      test(
        'rejects unavailable or invalid helper configuration ($response)',
        () async {
          messenger.setMockMethodCallHandler(channel, (_) async => response);
          await expectLater(
            worker.locate(),
            throwsA(
              isA<MediaWorkerFailure>().having(
                (failure) => failure.code,
                'code',
                'locate',
              ),
            ),
          );
        },
      );
    }

    test('rejects invalid child environment values', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        return {
          'executable': executable.path,
          'environment': {'PATH': 123},
        };
      });
      await expectLater(
        worker.locate(),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.code,
            'code',
            'locate',
          ),
        ),
      );
    });

    test('does not expose a native lookup error', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'native',
          message: 'synthetic-private-payload',
        );
      });
      await expectLater(
        worker.locate(),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.toString(),
            'sanitized error',
            'MediaWorkerFailure(locate)',
          ),
        ),
      );
    });

    test(
      'requires a positive pid before requesting native ownership',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        await expectLater(
          worker.claimProcess(0),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'ownership',
            ),
          ),
        );
        expect(calls, isEmpty);
      },
    );

    test('requests ownership of the supplied child', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'claimProcess');
        expect(call.arguments, 12345);
        return null;
      });
      await worker.claimProcess(12345);
    });

    test('sanitizes a rejected native child claim', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'ownership',
          message: 'synthetic-private-payload',
        );
      });
      await expectLater(
        worker.claimProcess(12345),
        throwsA(
          isA<MediaWorkerFailure>().having(
            (failure) => failure.toString(),
            'sanitized error',
            'MediaWorkerFailure(ownership)',
          ),
        ),
      );
    });

    test(
      'rejects missing-helper startup before allocating job files',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => null);
        final client = worker.createClient(
          temporaryDirectory: () async {
            fail('A missing installation allocated job files.');
          },
        );
        await expectLater(
          client.execute('renderVideo', {}, taskId: 'missing', consume: (_) {}),
          throwsA(
            isA<MediaWorkerFailure>().having(
              (failure) => failure.code,
              'code',
              'locate',
            ),
          ),
        );
        await client.dispose();
      },
    );
  });
}
