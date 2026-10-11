import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/services/live_nostr_codec.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockLiveNostrCodec extends Mock implements LiveNostrCodec {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  group('LiveChatRepository', () {
    late _MockNostrClient mockNostrClient;
    late _MockLiveNostrCodec mockCodec;
    late _MockNostrSigner mockSigner;
    late LiveChatRepository repository;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const speakerPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const sessionId = 'session-abc';
    const sessionAddress = '30313:$hostPubkey:$sessionId';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(const Duration(seconds: 5));
      registerFallbackValue(_MockNostrSigner());
      registerFallbackValue(Event.fromJson(_eventJson(kind: 1)));
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockCodec = _MockLiveNostrCodec();
      mockSigner = _MockNostrSigner();

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

      repository = LiveChatRepository(
        nostrClient: mockNostrClient,
        codec: mockCodec,
      );
    });

    test(
      'watchChatMessages emits queried messages and live chat updates for a session',
      () async {
        final liveEvents = StreamController<Event>.broadcast();
        final firstMessageEvent = Event.fromJson(
          _eventJson(
            idChar: '1',
            tags: const <List<String>>[
              <String>['a', sessionAddress],
            ],
            content: 'First message',
          ),
        );
        final secondMessageEvent = Event.fromJson(
          _eventJson(
            idChar: '2',
            pubkey: speakerPubkey,
            tags: const <List<String>>[
              <String>['a', sessionAddress],
            ],
            content: 'Second message',
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
        ).thenAnswer((_) async => <Event>[firstMessageEvent]);
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
        when(() => mockCodec.parseChatMessage(firstMessageEvent)).thenReturn(
          LiveChatMessage(
            id: '1' * 64,
            sessionAddress: sessionAddress,
            pubkey: hostPubkey,
            content: 'First message',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          ),
        );
        when(() => mockCodec.parseChatMessage(secondMessageEvent)).thenReturn(
          LiveChatMessage(
            id: '2' * 64,
            sessionAddress: sessionAddress,
            pubkey: speakerPubkey,
            content: 'Second message',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000010 * 1000),
          ),
        );

        final queue = StreamQueue<List<LiveChatMessage>>(
          repository.watchChatMessages(
            sessionAddress: sessionAddress,
            limit: 30,
          ),
        );

        final firstEmission = await queue.next;
        expect(firstEmission.single.content, 'First message');

        liveEvents.add(secondMessageEvent);
        final secondEmission = await queue.next;
        expect(
          secondEmission.map((message) => message.content),
          containsAll(<String>['First message', 'Second message']),
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
        expect(filters.single.kinds, <int>[1311]);
        expect(filters.single.a, <String>[sessionAddress]);
        expect(filters.single.limit, 30);

        await queue.cancel();
        await liveEvents.close();
      },
    );

    test(
      'publishMessage signs with the client signer and publishes the chat event',
      () async {
        final signedMessageEvent = Event.fromJson(
          _eventJson(
            idChar: '3',
            tags: const <List<String>>[
              <String>['a', sessionAddress],
            ],
            content: 'Hello room',
          ),
        );
        final parsedMessage = LiveChatMessage(
          id: '3' * 64,
          sessionAddress: sessionAddress,
          pubkey: hostPubkey,
          content: 'Hello room',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        );

        when(
          () => mockCodec.buildChatMessageEvent(
            sessionAddress: sessionAddress,
            content: 'Hello room',
            signer: mockSigner,
          ),
        ).thenAnswer((_) async => signedMessageEvent);
        when(
          () => mockCodec.parseChatMessage(signedMessageEvent),
        ).thenReturn(parsedMessage);

        final published = await repository.publishMessage(
          sessionAddress: sessionAddress,
          content: 'Hello room',
        );

        expect(published, parsedMessage);
        verify(
          () => mockCodec.buildChatMessageEvent(
            sessionAddress: sessionAddress,
            content: 'Hello room',
            signer: mockSigner,
          ),
        ).called(1);
        verify(
          () => mockNostrClient.publishEvent(
            signedMessageEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
        verify(() => mockCodec.parseChatMessage(signedMessageEvent)).called(1);
      },
    );

    test(
      'publishMessage returns null when the Nostr client does not publish the event',
      () async {
        final signedMessageEvent = Event.fromJson(
          _eventJson(
            idChar: '5',
            tags: const <List<String>>[
              <String>['a', sessionAddress],
            ],
            content: 'Hello room',
          ),
        );

        when(
          () => mockCodec.buildChatMessageEvent(
            sessionAddress: sessionAddress,
            content: 'Hello room',
            signer: mockSigner,
          ),
        ).thenAnswer((_) async => signedMessageEvent);
        when(
          () => mockNostrClient.publishEvent(
            signedMessageEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => const PublishFailed());

        final published = await repository.publishMessage(
          sessionAddress: sessionAddress,
          content: 'Hello room',
        );

        expect(published, isNull);
        verify(
          () => mockCodec.buildChatMessageEvent(
            sessionAddress: sessionAddress,
            content: 'Hello room',
            signer: mockSigner,
          ),
        ).called(1);
        verify(
          () => mockNostrClient.publishEvent(
            signedMessageEvent,
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
        verifyNever(() => mockCodec.parseChatMessage(any()));
      },
    );
  });
}

Map<String, dynamic> _eventJson({
  String idChar = 'a',
  String pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int kind = 1311,
  List<List<String>> tags = const <List<String>>[],
  String content = '',
}) {
  return <String, dynamic>{
    'id': idChar * 64,
    'pubkey': pubkey,
    'kind': kind,
    'tags': tags,
    'content': content,
    'created_at': 1700000000,
    'sig': 'f' * 128,
  };
}
