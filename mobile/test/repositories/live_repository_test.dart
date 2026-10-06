import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/live_nostr_codec.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockLiveNostrCodec extends Mock implements LiveNostrCodec {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockLiveApiService extends Mock implements LiveApiService {}

void main() {
  group('LiveRepository', () {
    late _MockNostrClient mockNostrClient;
    late _MockLiveNostrCodec mockCodec;
    late _MockNostrSigner mockSigner;
    late _MockLiveApiService mockLiveApiService;
    late LiveRepository repository;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const speakerPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const roomId = 'room-abc';
    const roomAddress = '30312:$hostPubkey:$roomId';
    const sessionId = 'session-abc';
    const sessionAddress = '30313:$hostPubkey:$sessionId';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(const Duration(seconds: 5));
      registerFallbackValue(
        const LiveRoom(
          id: roomId,
          hostPubkey: hostPubkey,
          title: 'Divine Live',
          summary: 'Public room',
          imageUrl: null,
          relays: <String>[],
          visibility: LiveRoomVisibility.public,
        ),
      );
      registerFallbackValue(
        LiveSession(
          id: sessionId,
          roomId: roomId,
          status: LiveSessionStatus.live,
          startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          endedAt: null,
          speakerPubkeys: const <String>[hostPubkey],
          audienceCount: 12,
        ),
      );
      registerFallbackValue(
        LivePresence(
          sessionId: sessionId,
          pubkey: hostPubkey,
          role: LiveRole.host,
          handRaised: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        ),
      );
      registerFallbackValue(_MockNostrSigner());
      registerFallbackValue(Event.fromJson(_eventJson(kind: 1)));
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockCodec = _MockLiveNostrCodec();
      mockSigner = _MockNostrSigner();
      mockLiveApiService = _MockLiveApiService();

      when(() => mockNostrClient.signer).thenReturn(mockSigner);
      when(
        () => mockNostrClient.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => const <Event>[]);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => mockNostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      repository = LiveRepository(
        nostrClient: mockNostrClient,
        codec: mockCodec,
        liveApiService: mockLiveApiService,
      );
    });

    test(
      'watchPublicRooms emits the queried rooms and live subscription updates',
      () async {
        final liveEvents = StreamController<Event>.broadcast();
        final roomOneEvent = Event.fromJson(
          _eventJson(
            idChar: '1',
            kind: 30312,
            content: 'Public room one',
            tags: <List<String>>[
              const <String>['d', roomId],
              const <String>['title', 'Divine Live'],
              const <String>['status', 'open'],
            ],
          ),
        );
        final roomTwoEvent = Event.fromJson(
          _eventJson(
            idChar: '2',
            pubkey: speakerPubkey,
            kind: 30312,
            content: 'Public room two',
            tags: const <List<String>>[
              <String>['d', 'room-two'],
              <String>['title', 'Second Room'],
              <String>['status', 'public'],
            ],
          ),
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => <Event>[roomOneEvent]);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => liveEvents.stream);
        when(() => mockCodec.parseRoom(roomOneEvent)).thenReturn(
          const LiveRoom(
            id: roomId,
            hostPubkey: hostPubkey,
            title: 'Divine Live',
            summary: 'Public room one',
            imageUrl: null,
            relays: <String>[],
            visibility: LiveRoomVisibility.public,
          ),
        );
        when(() => mockCodec.parseRoom(roomTwoEvent)).thenReturn(
          const LiveRoom(
            id: 'room-two',
            hostPubkey: speakerPubkey,
            title: 'Second Room',
            summary: 'Public room two',
            imageUrl: null,
            relays: <String>[],
            visibility: LiveRoomVisibility.public,
          ),
        );

        final queue = StreamQueue<List<LiveRoom>>(
          repository.watchPublicRooms(limit: 20),
        );

        final firstEmission = await queue.next;
        expect(firstEmission.map((room) => room.id), <String>[roomId]);

        liveEvents.add(roomTwoEvent);
        final secondEmission = await queue.next;
        expect(
          secondEmission.map((room) => room.id),
          containsAll(<String>[roomId, 'room-two']),
        );

        final filters =
            verify(
                  () => mockNostrClient.queryEvents(
                    captureAny(),
                    subscriptionId: any(named: 'subscriptionId'),
                    tempRelays: any(named: 'tempRelays'),
                    relayTypes: any(named: 'relayTypes'),
                    sendAfterAuth: any(named: 'sendAfterAuth'),
                    useCache: any(named: 'useCache'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as List<Filter>;
        expect(filters.single.kinds, <int>[30312]);
        expect(filters.single.limit, 20);

        await queue.cancel();
        await liveEvents.close();
        verify(
          () => mockNostrClient.unsubscribe(any()),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test(
      'watchSessions filters by room address and emits live updates',
      () async {
        final liveEvents = StreamController<Event>.broadcast();
        final sessionEvent = Event.fromJson(
          _eventJson(
            idChar: '3',
            kind: 30313,
            tags: <List<String>>[
              const <String>['d', sessionId],
              const <String>['a', roomAddress],
              const <String>['status', 'live'],
            ],
          ),
        );
        final updatedSessionEvent = Event.fromJson(
          _eventJson(
            idChar: '4',
            createdAt: 1700000001,
            kind: 30313,
            tags: <List<String>>[
              const <String>['d', sessionId],
              const <String>['a', roomAddress],
              const <String>['status', 'ended'],
            ],
          ),
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => <Event>[sessionEvent]);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => liveEvents.stream);
        when(() => mockCodec.parseSession(sessionEvent)).thenReturn(
          LiveSession(
            id: sessionId,
            roomId: roomId,
            status: LiveSessionStatus.live,
            startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
            endedAt: null,
            speakerPubkeys: const <String>[hostPubkey],
            audienceCount: 21,
          ),
        );
        when(() => mockCodec.parseSession(updatedSessionEvent)).thenReturn(
          LiveSession(
            id: sessionId,
            roomId: roomId,
            status: LiveSessionStatus.ended,
            startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
            endedAt: DateTime.fromMillisecondsSinceEpoch(1700003600 * 1000),
            speakerPubkeys: const <String>[hostPubkey, speakerPubkey],
            audienceCount: 34,
          ),
        );

        final queue = StreamQueue<List<LiveSession>>(
          repository.watchSessions(roomAddress: roomAddress, limit: 10),
        );

        final firstEmission = await queue.next;
        expect(firstEmission.single.status, LiveSessionStatus.live);

        liveEvents.add(updatedSessionEvent);
        final secondEmission = await queue.next;
        expect(secondEmission.single.status, LiveSessionStatus.ended);
        expect(secondEmission.single.audienceCount, 34);

        final filters =
            verify(
                  () => mockNostrClient.queryEvents(
                    captureAny(),
                    subscriptionId: any(named: 'subscriptionId'),
                    tempRelays: any(named: 'tempRelays'),
                    relayTypes: any(named: 'relayTypes'),
                    sendAfterAuth: any(named: 'sendAfterAuth'),
                    useCache: any(named: 'useCache'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as List<Filter>;
        expect(filters.single.kinds, <int>[30313]);
        expect(filters.single.a, <String>[roomAddress]);
        expect(filters.single.limit, 10);

        await queue.cancel();
        await liveEvents.close();
      },
    );

    test(
      'fetchPublicRooms keeps rooms distinct by full address when hosts reuse the same room id',
      () async {
        final firstRoomEvent = Event.fromJson(
          _eventJson(
            idChar: 'p',
            kind: 30312,
            content: 'First host room',
            tags: const <List<String>>[
              <String>['d', roomId],
              <String>['title', 'First host room'],
              <String>['status', 'open'],
            ],
          ),
        );
        final secondRoomEvent = Event.fromJson(
          _eventJson(
            idChar: 'q',
            pubkey: speakerPubkey,
            kind: 30312,
            content: 'Second host room',
            tags: const <List<String>>[
              <String>['d', roomId],
              <String>['title', 'Second host room'],
              <String>['status', 'open'],
            ],
          ),
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => <Event>[firstRoomEvent, secondRoomEvent]);
        when(() => mockCodec.parseRoom(any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments.first as Event;
          return LiveRoom(
            id: roomId,
            hostPubkey: event.pubkey,
            title: event.pubkey == hostPubkey
                ? 'First host room'
                : 'Second host room',
            summary: event.content,
            imageUrl: null,
            relays: const <String>[],
            visibility: LiveRoomVisibility.public,
          );
        });

        final rooms = await repository.fetchPublicRooms();

        expect(rooms, hasLength(2));
        expect(
          rooms.map((room) => room.address),
          containsAll(<String>[
            '30312:$hostPubkey:$roomId',
            '30312:$speakerPubkey:$roomId',
          ]),
        );
      },
    );

    test(
      'fetchSessions keeps sessions distinct by full address when hosts reuse the same session id',
      () async {
        final firstSessionEvent = Event.fromJson(
          _eventJson(
            idChar: 'r',
            kind: 30313,
            tags: const <List<String>>[
              <String>['d', sessionId],
              <String>['a', roomAddress],
              <String>['status', 'live'],
            ],
          ),
        );
        final secondSessionEvent = Event.fromJson(
          _eventJson(
            idChar: 's',
            pubkey: speakerPubkey,
            kind: 30313,
            tags: <List<String>>[
              const <String>['d', sessionId],
              <String>['a', '30312:$speakerPubkey:$roomId'],
              const <String>['status', 'planned'],
            ],
          ),
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => <Event>[firstSessionEvent, secondSessionEvent],
        );
        when(() => mockCodec.parseSession(any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments.first as Event;
          return LiveSession(
            id: sessionId,
            roomId: roomId,
            hostPubkey: event.pubkey,
            status: event.pubkey == hostPubkey
                ? LiveSessionStatus.live
                : LiveSessionStatus.planned,
            startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
            endedAt: null,
            speakerPubkeys: <String>[event.pubkey],
            audienceCount: event.pubkey == hostPubkey ? 21 : 0,
          );
        });

        final sessions = await repository.fetchSessions();

        expect(sessions, hasLength(2));
        expect(
          sessions.map((session) => session.address),
          containsAll(<String>[
            '30313:$hostPubkey:$sessionId',
            '30313:$speakerPubkey:$sessionId',
          ]),
        );
      },
    );

    test(
      'late initial query cannot replace an ended subscription session',
      () async {
        final initial = Completer<List<Event>>();
        final liveEvents = StreamController<Event>();
        final older = Event.fromJson(_eventJson(kind: 30313, idChar: '2'));
        final newer = Event.fromJson(
          _eventJson(kind: 30313, idChar: '1', createdAt: 1700000001),
        );
        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => initial.future);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => liveEvents.stream);
        when(() => mockCodec.parseSession(any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments.first as Event;
          return LiveSession(
            id: sessionId,
            roomId: roomId,
            hostPubkey: hostPubkey,
            status: event == newer
                ? LiveSessionStatus.ended
                : LiveSessionStatus.live,
            startedAt: DateTime.utc(2026),
            endedAt: null,
            speakerPubkeys: const [],
            audienceCount: 0,
          );
        });
        final queue = StreamQueue(repository.watchSessions());
        final first = queue.next;
        liveEvents.add(newer);
        expect((await first).single.status, LiveSessionStatus.ended);
        initial.complete([older]);
        expect((await queue.next).single.status, LiveSessionStatus.ended);
        await queue.cancel();
        await liveEvents.close();
      },
    );

    test(
      'older public room cannot restore a newer private replacement',
      () async {
        final newer = Event.fromJson(
          _eventJson(kind: 30312, idChar: '1', createdAt: 1700000001),
        );
        final older = Event.fromJson(_eventJson(kind: 30312, idChar: '2'));
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [newer, older]);
        when(() => mockCodec.parseRoom(any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments.first as Event;
          return LiveRoom(
            id: roomId,
            hostPubkey: hostPubkey,
            title: 'Room',
            summary: '',
            imageUrl: null,
            relays: const [],
            visibility: event == newer
                ? LiveRoomVisibility.private
                : LiveRoomVisibility.public,
          );
        });
        expect(await repository.fetchPublicRooms(), isEmpty);
      },
    );

    for (final sameTimestamp in <bool>[false, true]) {
      test(
        'fetchSessions retains newest replacement (tie: $sameTimestamp)',
        () async {
          final newer = Event.fromJson(
            _eventJson(kind: 30313, idChar: '1', createdAt: 1700000001),
          );
          final older = Event.fromJson(
            _eventJson(
              kind: 30313,
              idChar: '2',
              createdAt: sameTimestamp ? 1700000001 : 1700000000,
            ),
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [newer, older]);
          when(() => mockCodec.parseSession(any())).thenAnswer((invocation) {
            final event = invocation.positionalArguments.first as Event;
            return LiveSession(
              id: sessionId,
              roomId: roomId,
              hostPubkey: hostPubkey,
              status: event == newer
                  ? LiveSessionStatus.ended
                  : LiveSessionStatus.live,
              startedAt: DateTime.utc(2026),
              endedAt: null,
              speakerPubkeys: const [],
              audienceCount: 0,
            );
          });
          expect(
            (await repository.fetchSessions()).single.status,
            LiveSessionStatus.ended,
          );
        },
      );
    }

    test(
      'publishRoom signs with the client signer and sends the event',
      () async {
        const room = LiveRoom(
          id: roomId,
          hostPubkey: hostPubkey,
          title: 'Divine Live',
          summary: 'Room summary',
          imageUrl: 'https://example.com/cover.jpg',
          relays: <String>['wss://relay.example.com'],
          visibility: LiveRoomVisibility.public,
        );
        final signedEvent = Event.fromJson(
          _eventJson(idChar: '5', kind: 30312),
        );

        when(
          () => mockCodec.buildRoomEvent(room, mockSigner),
        ).thenAnswer((_) async => signedEvent);

        final published = await repository.publishRoom(room);

        expect(published, same(signedEvent));
        verify(() => mockCodec.buildRoomEvent(room, mockSigner)).called(1);
        verify(
          () => mockNostrClient.publishEvent(
            signedEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test(
      'publishRoom returns null when the Nostr client does not publish the event',
      () async {
        const room = LiveRoom(
          id: roomId,
          hostPubkey: hostPubkey,
          title: 'Divine Live',
          summary: 'Room summary',
          imageUrl: null,
          relays: <String>[],
          visibility: LiveRoomVisibility.public,
        );
        final signedEvent = Event.fromJson(
          _eventJson(idChar: '8', kind: 30312),
        );

        when(
          () => mockCodec.buildRoomEvent(room, mockSigner),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrClient.publishEvent(
            signedEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => const PublishNoRelays());

        final published = await repository.publishRoom(room);

        expect(published, isNull);
        verify(() => mockCodec.buildRoomEvent(room, mockSigner)).called(1);
        verify(
          () => mockNostrClient.publishEvent(
            signedEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test(
      'publishSession and publishPresence route through the codec and Nostr client',
      () async {
        final session = LiveSession(
          id: sessionId,
          roomId: roomId,
          status: LiveSessionStatus.live,
          startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          endedAt: null,
          speakerPubkeys: const <String>[hostPubkey, speakerPubkey],
          audienceCount: 42,
        );
        final signedSessionEvent = Event.fromJson(
          _eventJson(idChar: '6', kind: 30313),
        );
        final signedPresenceEvent = Event.fromJson(
          _eventJson(idChar: '7', kind: 10312),
        );

        when(
          () => mockCodec.buildSessionEvent(
            session: session,
            roomAddress: roomAddress,
            hostPubkey: hostPubkey,
            signer: mockSigner,
          ),
        ).thenAnswer((_) async => signedSessionEvent);
        when(
          () => mockCodec.buildPresenceEvent(
            sessionAddress: sessionAddress,
            role: LiveRole.speaker,
            handRaised: true,
            signer: mockSigner,
          ),
        ).thenAnswer((_) async => signedPresenceEvent);

        final publishedSession = await repository.publishSession(
          session: session,
          roomAddress: roomAddress,
          hostPubkey: hostPubkey,
        );
        final publishedPresence = await repository.publishPresence(
          sessionAddress: sessionAddress,
          role: LiveRole.speaker,
          handRaised: true,
        );

        expect(publishedSession, same(signedSessionEvent));
        expect(publishedPresence, same(signedPresenceEvent));
        verify(
          () => mockCodec.buildSessionEvent(
            session: session,
            roomAddress: roomAddress,
            hostPubkey: hostPubkey,
            signer: mockSigner,
          ),
        ).called(1);
        verify(
          () => mockCodec.buildPresenceEvent(
            sessionAddress: sessionAddress,
            role: LiveRole.speaker,
            handRaised: true,
            signer: mockSigner,
          ),
        ).called(1);
        verify(
          () => mockNostrClient.publishEvent(
            signedSessionEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
        verify(
          () => mockNostrClient.publishEvent(
            signedPresenceEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test(
      'fetchRecording delegates replay lookup to the live api service',
      () async {
        const recording = LiveRoomRecording(
          playbackUrl: 'https://example.com/replay.m3u8',
          status: RecordingStatus.ready,
        );
        when(
          () => mockLiveApiService.fetchRecording(roomId: roomId),
        ).thenAnswer((_) async => recording);

        final result = await repository.fetchRecording(roomId: roomId);

        expect(result, recording);
        verify(
          () => mockLiveApiService.fetchRecording(roomId: roomId),
        ).called(1);
      },
    );
  });
}

Map<String, dynamic> _eventJson({
  required int kind,
  String idChar = 'a',
  String pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  List<List<String>> tags = const <List<String>>[],
  String content = '',
  int createdAt = 1700000000,
}) {
  return <String, dynamic>{
    'id': idChar * 64,
    'pubkey': pubkey,
    'kind': kind,
    'tags': tags,
    'content': content,
    'created_at': createdAt,
    'sig': 'f' * 128,
  };
}
