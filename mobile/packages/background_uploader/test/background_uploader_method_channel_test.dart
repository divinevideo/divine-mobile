import 'package:background_uploader/background_uploader.dart';
import 'package:background_uploader/background_uploader_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelBackgroundUploader platform;
  const channel = MethodChannel('background_uploader_test');
  final calls = <MethodCall>[];

  setUp(() {
    platform = MethodChannelBackgroundUploader(methodChannel: channel);
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          calls.add(methodCall);
          switch (methodCall.method) {
            case 'isSupported':
              return true;
            case 'activeTaskIds':
              return <String>['task-a', 'task-b'];
            case 'enqueue':
            case 'cancel':
              return null;
          }
          return null;
        });
  });

  tearDown(() async {
    await platform.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('native platform calls', () {
    test('isSupported delegates to native platform', () async {
      expect(await platform.isSupported(), isTrue);
    });

    test('enqueue serializes the request for the native platform', () async {
      final request = BackgroundUploadRequest(
        taskId: 'upload-1',
        url: Uri.parse('https://media.divine.video/upload'),
        filePath: '/tmp/video.mp4',
        headers: const <String, String>{'Authorization': 'Nostr abc'},
      );

      await platform.enqueue(request);

      expect(calls.single.method, 'enqueue');
      expect(calls.single.arguments, request.toMap());
      expect(
        (calls.single.arguments as Map)['method'],
        'PUT',
        reason: 'defaults to the Blossom BUD-01 PUT method',
      );
    });

    test('cancel passes the task id to the native platform', () async {
      await platform.cancel('upload-1');

      expect(calls.single.method, 'cancel');
      expect(calls.single.arguments, <String, Object?>{'taskId': 'upload-1'});
    });

    test('beginForegroundSession passes the session id to native', () async {
      await platform.beginForegroundSession('publish-1');

      expect(calls.single.method, 'beginForegroundSession');
      expect(calls.single.arguments, <String, Object?>{
        'sessionId': 'publish-1',
      });
    });

    test('endForegroundSession passes the session id to native', () async {
      await platform.endForegroundSession('publish-1');

      expect(calls.single.method, 'endForegroundSession');
      expect(calls.single.arguments, <String, Object?>{
        'sessionId': 'publish-1',
      });
    });

    test('activeTaskIds returns the native list', () async {
      expect(await platform.activeTaskIds(), <String>['task-a', 'task-b']);
    });
  });

  group('upload event stream', () {
    test('native upload events are emitted on the stream', () async {
      final emitted = expectLater(
        platform.events,
        emits(
          isA<BackgroundUploadEvent>()
              .having((e) => e.taskId, 'taskId', 'upload-1')
              .having(
                (e) => e.status,
                'status',
                BackgroundUploadStatus.completed,
              )
              .having((e) => e.httpStatusCode, 'httpStatusCode', 200)
              .having((e) => e.isTerminal, 'isTerminal', isTrue),
        ),
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('onUploadEvent', <String, Object?>{
                'taskId': 'upload-1',
                'status': 'completed',
                'progress': 1.0,
                'httpStatusCode': 200,
              }),
            ),
            (_) {},
          );

      await emitted;
    });

    test('malformed native events are ignored', () async {
      final emitted = <BackgroundUploadEvent>[];
      final subscription = platform.events.listen(emitted.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('onUploadEvent', <String, Object?>{
                'status': 'completed',
              }),
            ),
            (_) {},
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emitted, isEmpty);
      await subscription.cancel();
    });

    test(
      'a terminal event with no listener is buffered and claimable',
      () async {
        // No events subscription: the terminal would be dropped by the
        // broadcast stream, but reconciliation can still recover it from the
        // buffer.
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(
                const MethodCall('onUploadEvent', <String, Object?>{
                  'taskId': 'buffered-task',
                  'status': 'completed',
                  'progress': 1.0,
                  'httpStatusCode': 200,
                }),
              ),
              (_) {},
            );

        final claimed = await platform.takeBufferedTerminalEvent(
          'buffered-task',
        );
        expect(claimed, isNotNull);
        expect(claimed!.taskId, 'buffered-task');
        expect(claimed.status, BackgroundUploadStatus.completed);

        // Claiming removes it, so a given terminal is handed out at most once.
        expect(
          await platform.takeBufferedTerminalEvent('buffered-task'),
          isNull,
        );
      },
    );

    test('running (non-terminal) events are not buffered', () async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('onUploadEvent', <String, Object?>{
                'taskId': 'running-task',
                'status': 'running',
                'progress': 0.5,
              }),
            ),
            (_) {},
          );

      expect(await platform.takeBufferedTerminalEvent('running-task'), isNull);
    });

    test('dispose releases the incoming channel handler', () async {
      await platform.dispose();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('onUploadEvent', <String, Object?>{
                'taskId': 'after-dispose',
                'status': 'completed',
                'progress': 1.0,
              }),
            ),
            (_) {},
          );

      expect(await platform.takeBufferedTerminalEvent('after-dispose'), isNull);
    });
  });
}
