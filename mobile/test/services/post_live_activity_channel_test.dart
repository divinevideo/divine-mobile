// ABOUTME: Tests the post Live Activity channel wrapper: arguments sent,
// ABOUTME: parsing of lists and events, and the no-op off-iOS behavior.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/post_live_activity_channel.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(
    PostLiveActivityChannel.methodChannelName,
  );
  const eventChannel = EventChannel(PostLiveActivityChannel.eventChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? Function(MethodCall) respond;
  late StreamController<Object?> nativeEvents;
  late PostLiveActivityChannel channel;

  PostLiveActivityChannel build({required bool supported}) =>
      PostLiveActivityChannel(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
        isSupported: () => supported,
      );

  setUp(() {
    calls = [];
    respond = (_) => null;
    nativeEvents = StreamController<Object?>();
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return respond(call);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (_, sink) {
              nativeEvents.stream.listen(
                sink.success,
                onDone: sink.endOfStream,
              );
            },
          ),
        );
    channel = build(supported: true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
    // Never awaited: a controller nobody listened to does not complete close.
    unawaited(nativeEvents.close());
  });

  group(PostLiveActivityChannel, () {
    group('supported', () {
      test('isEnabled returns the native answer', () async {
        respond = (_) => true;

        expect(await channel.isEnabled(), isTrue);
        expect(calls.single.method, 'isEnabled');
      });

      test(
        'writeThumbnail sends the bytes and returns the file name',
        () async {
          respond = (_) => 'thumb.jpg';

          final name = await channel.writeThumbnail(Uint8List.fromList([1, 2]));

          expect(name, 'thumb.jpg');
          expect(calls.single.method, 'writeThumbnail');
          expect(calls.single.arguments, {
            'bytes': Uint8List.fromList([1, 2]),
          });
        },
      );

      test('start sends the owner, thumbnail and note flag', () async {
        respond = (_) => 'activity-1';

        final id = await channel.start(
          ownerPubkey: 'a' * 64,
          showFirstRunNote: true,
          thumbnailFileName: 'thumb.jpg',
        );

        expect(id, 'activity-1');
        expect(calls.single.arguments, {
          'ownerPubkey': 'a' * 64,
          'thumbnailFileName': 'thumb.jpg',
          'showFirstRunNote': true,
        });
      });

      test('update sends the phase name and post identity', () async {
        await channel.update(
          'activity-1',
          phase: LiveActivityPhase.notFound,
          showFirstRunNote: false,
          postCoordinate: '34236:${'a' * 64}:d',
          postEventId: 'b' * 64,
        );

        expect(calls.single.method, 'update');
        expect(calls.single.arguments, {
          'activityId': 'activity-1',
          'phase': 'notFound',
          'postCoordinate': '34236:${'a' * 64}:d',
          'postEventId': 'b' * 64,
          'showFirstRunNote': false,
        });
      });

      test('end sends the id and immediacy', () async {
        await channel.end('activity-1', immediate: true);

        expect(calls.single.method, 'end');
        expect(calls.single.arguments, {
          'activityId': 'activity-1',
          'immediate': true,
        });
      });

      test('list parses every state and drops malformed entries', () async {
        respond = (_) => [
          for (final state in ['active', 'ended', 'dismissed', 'stale'])
            {
              'activityId': 'id-$state',
              'ownerPubkey': 'a' * 64,
              'startedAtMs': 1000,
              'postCoordinate': 'coord',
              'state': state,
            },
          {'activityId': 'bad', 'state': 'active'},
          {
            'activityId': 'weird',
            'ownerPubkey': 'a' * 64,
            'startedAtMs': 1,
            'state': 'mystery',
          },
        ];

        final running = await channel.list();

        expect(running.map((a) => a.state), [
          LiveActivityState.active,
          LiveActivityState.ended,
          LiveActivityState.dismissed,
          LiveActivityState.stale,
        ]);
        expect(running.first.startedAt.millisecondsSinceEpoch, 1000);
        expect(running.first.postCoordinate, 'coord');
        expect(running.first.postEventId, isNull);
      });

      test('events parses the three event types and drops the rest', () async {
        final received = <LiveActivityPlatformEvent>[];
        final sub = channel.events.listen(received.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        nativeEvents
          ..add({'type': 'enablement', 'enabled': false})
          ..add({'type': 'pushToken', 'activityId': 'a1', 'token': 'ab12'})
          ..add({'type': 'state', 'activityId': 'a1', 'state': 'dismissed'})
          ..add({'type': 'state', 'activityId': 'a1', 'state': 'bogus'})
          ..add({'type': 'enablement'})
          ..add({'type': 'unknown'})
          ..add('not a map');
        await pumpEventQueue();

        expect(received, const [
          EnablementChanged(enabled: false),
          PushTokenChanged(activityId: 'a1', token: 'ab12'),
          ActivityStateChanged(
            activityId: 'a1',
            state: LiveActivityState.dismissed,
          ),
        ]);
      });

      test('events is a broadcast stream', () {
        expect(channel.events.isBroadcast, isTrue);
      });
    });

    group('unsupported', () {
      setUp(() => channel = build(supported: false));

      test('isEnabled is false without touching the channel', () async {
        expect(await channel.isEnabled(), isFalse);
        expect(calls, isEmpty);
      });

      test('start throws UnsupportedError', () {
        expect(
          () => channel.start(ownerPubkey: 'a' * 64, showFirstRunNote: false),
          throwsUnsupportedError,
        );
      });

      test('everything else no-ops and never touches the channel', () async {
        await channel.writeThumbnail(Uint8List(1));
        await channel.update(
          'id',
          phase: LiveActivityPhase.live,
          showFirstRunNote: false,
        );
        await channel.end('id', immediate: false);

        expect(await channel.list(), isEmpty);
        expect(await channel.events.isEmpty, isTrue);
        expect(calls, isEmpty);
      });
    });
  });
}
