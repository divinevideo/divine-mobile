// ABOUTME: #8441 — a recipient wrap the relay accepted after the OK window is
// ABOUTME: re-sent as the same signed event on retry, not minted again.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendFailure;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

/// A queue whose write of an unconfirmed attempt's wrap fails.
class _UnkeepableOutgoingDmsDao extends OutgoingDmsDao {
  _UnkeepableOutgoingDmsDao(super.attachedDatabase);

  @override
  Future<bool> recordUnconfirmedRecipientWrap({
    required String id,
    required String wrapJson,
  }) => Future.error(StateError('database is locked'));
}

const _ownerKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _peerKey =
    '6a1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3';

const _secondPeerKey =
    '1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3c4';

const _poolRelay = 'wss://relay.divine.video';
const _otherRelay = 'wss://relay.example.com';

/// How the pool relay answers a recipient wrap.
enum _Relay {
  accepts,
  staysSilent,
  refuses,
  rateLimits,
  rateLimitsBesideSilent,
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  group('#8441 a recipient wrap whose OK came late', () {
    final owner = getPublicKey(_ownerKey);
    final peer = getPublicKey(_peerKey);

    late AppDatabase db;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late List<Event> published;
    late _Relay relay;
    late DmRepository repository;

    List<Event> wrapsTo(String pubkey) => [
      for (final event in published)
        if (event.kind == EventKind.giftWrap &&
            event.tags.any(
              (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey,
            ))
          event,
    ];

    DmRepository buildRepository({DmRepositoryErrorReporter? errorReporter}) {
      final signer = LocalNostrSigner(_ownerKey);
      return DmRepository(
        nostrClient: nostrClient,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: owner,
          nostrService: nostrClient,
          sendPolicy: (_) async => DmSendPolicyDecision.allowed,
          isOffline: () async => false,
        ),
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: outgoingDao,
        userPubkey: owner,
        signer: signer,
        errorReporter: errorReporter,
      );
    }

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      outgoingDao = OutgoingDmsDao(db);
      nostrClient = _MockNostrClient();
      published = [];
      relay = _Relay.accepts;

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [_poolRelay]);
      when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
      // The recipient advertises no kind 10050: the wrap goes to the pool,
      // the path the issue measured.
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
          useQueryPool: any(named: 'useQueryPool'),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
        ),
      ).thenAnswer(
        (_) async =>
            (events: const <Event>[], timedOut: false, noRelays: false),
      );
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: relay == _Relay.accepts ? const [_poolRelay] : const [],
          rejectedBy: switch (relay) {
            _Relay.refuses => const {_poolRelay: 'invalid: created_at too old'},
            _Relay.rateLimits => const {_poolRelay: 'rate-limited: slow down'},
            _Relay.rateLimitsBesideSilent => const {
              _otherRelay: 'rate-limited: slow down',
            },
            _ => const <String, String>{},
          },
          noResponseFrom: switch (relay) {
            _Relay.staysSilent ||
            _Relay.rateLimitsBesideSilent => const [_poolRelay],
            _ => const <String>[],
          },
        );
      });
      when(
        () => nostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        return PublishSuccess(event: event);
      });

      repository = buildRepository();
    });

    tearDown(() async {
      await db.close();
    });

    /// A send whose OK never arrived: its queue row id and the wrap it wrote.
    Future<({String rowId, Event wrap})> unconfirmedSend() async {
      relay = _Relay.staysSilent;
      final sent = await repository.sendMessage(
        recipientPubkey: peer,
        content: 'accepted after the window',
      );
      expect(sent.retryablePending, isTrue, reason: 'precondition: soft');
      return (rowId: sent.queuedRumorId!, wrap: wrapsTo(peer).single);
    }

    group('sendMessage', () {
      test('keeps the wrap of a send whose OK never arrived', () async {
        final (:rowId, :wrap) = await unconfirmedSend();

        final row = await outgoingDao.getById(rowId);

        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.unconfirmedRecipientWrapJson, isNotNull);
        final kept = Event.fromJson(
          jsonDecode(row.unconfirmedRecipientWrapJson!) as Map<String, dynamic>,
        );
        expect(kept.id, equals(wrap.id));
        expect(kept.sig, equals(wrap.sig));
      });

      test('hands back the wrap it kept on the soft result', () async {
        relay = _Relay.staysSilent;

        final sent = await repository.sendMessage(
          recipientPubkey: peer,
          content: 'accepted after the window',
        );

        expect(sent, isA<NIP17SendFailure>());
        expect(
          (sent as NIP17SendFailure).unconfirmedRecipientWrap?.id,
          equals(wrapsTo(peer).single.id),
        );
      });

      test('keeps the wrap when one relay stays silent and another asks it '
          'to slow down, and the retry sends that same wrap', () async {
        relay = _Relay.rateLimitsBesideSilent;
        final sent = await repository.sendMessage(
          recipientPubkey: peer,
          content: 'held by the silent relay',
        );
        expect(sent.success, isFalse);
        expect(sent.retryablePending, isFalse, reason: 'a relay refused it');
        final wrap = wrapsTo(peer).single;
        final rowId = sent.queuedRumorId!;
        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.failed);
        expect(row.unconfirmedRecipientWrapJson, isNotNull);

        relay = _Relay.accepts;
        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isTrue);
        expect(
          wrapsTo(peer).map((sent) => sent.id).toSet(),
          equals({wrap.id}),
        );
      });

      test('publishes one recipient wrap when the OK arrives in the window '
          '(control)', () async {
        final sent = await repository.sendMessage(
          recipientPubkey: peer,
          content: 'confirmed in the window',
        );
        expect(sent.success, isTrue);
        expect(wrapsTo(peer), hasLength(1));
      });
    });

    group('sendGroupMessage', () {
      test('reuses the wrap a recovery sent before the group loop reaches '
          'that sibling', () async {
        final secondPeer = getPublicKey(_secondPeerKey);
        final firstStarted = Completer<void>();
        final releaseFirst = Completer<void>();
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
            diagnosticTag: any(named: 'diagnosticTag'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          published.add(event);
          final toFirst = event.tags.any(
            (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == peer,
          );
          if (toFirst && !firstStarted.isCompleted) {
            firstStarted.complete();
            await releaseFirst.future;
          }
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [_poolRelay],
          );
        });

        final batch = repository.sendGroupMessage(
          recipientPubkeys: [peer, secondPeer],
          content: 'recovery reached the sibling first',
        );
        await firstStarted.future;
        final secondRow = (await outgoingDao.getAllForOwner(
          owner,
        )).singleWhere((row) => row.recipientPubkey == secondPeer);
        try {
          final recovered = await repository.recoverFullSend(
            rumorId: secondRow.id,
          );
          expect(recovered.retryablePending, isTrue);
          expect(wrapsTo(secondPeer), hasLength(1));
        } finally {
          releaseFirst.complete();
          await batch;
        }

        final wraps = wrapsTo(secondPeer);
        expect(wraps, hasLength(2));
        expect(wraps.last.id, wraps.first.id);
      });

      test('keeps a sibling wrap before the next sibling publishes, so a '
          'retry in between sends that same wrap again', () async {
        final secondPeer = getPublicKey(_secondPeerKey);
        final secondStarted = Completer<void>();
        final releaseSecond = Completer<void>();
        relay = _Relay.staysSilent;
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
            diagnosticTag: any(named: 'diagnosticTag'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          published.add(event);
          final toSecond = event.tags.any(
            (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == secondPeer,
          );
          if (toSecond && !secondStarted.isCompleted) {
            secondStarted.complete();
            await releaseSecond.future;
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: const [_poolRelay],
            );
          }
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: relay == _Relay.accepts ? const [_poolRelay] : const [],
            rejectedBy: const {},
            noResponseFrom: relay == _Relay.staysSilent
                ? const [_poolRelay]
                : const [],
          );
        });

        final batch = repository.sendGroupMessage(
          recipientPubkeys: [peer, secondPeer],
          content: 'accepted after the window',
        );
        await secondStarted.future;
        final firstWrap = wrapsTo(peer).single;
        final firstRow = (await outgoingDao.getAllForOwner(
          owner,
        )).singleWhere((row) => row.recipientPubkey == peer);

        relay = _Relay.accepts;
        final retried = await repository.recoverFullSend(rumorId: firstRow.id);
        releaseSecond.complete();
        await batch;

        expect(retried.success, isTrue);
        expect(
          wrapsTo(peer).map((wrap) => wrap.id).toSet(),
          equals({firstWrap.id}),
        );
      });

      test(
        'leaves each sibling retryable when keeping its wrap fails',
        () async {
          final reported = <String>[];
          outgoingDao = _UnkeepableOutgoingDmsDao(db);
          repository = buildRepository(
            errorReporter: (error, stackTrace, {required site}) =>
                reported.add(site),
          );
          relay = _Relay.staysSilent;

          final results = await repository.sendGroupMessage(
            recipientPubkeys: [peer, getPublicKey(_secondPeerKey)],
            content: 'accepted after the window',
          );

          expect(results, hasLength(2));
          expect(
            results.map((result) => result.retryablePending),
            everyElement(isTrue),
          );
          expect(reported, [
            DmRepositoryReportableSites.keepUnconfirmedRecipientWrap,
            DmRepositoryReportableSites.keepUnconfirmedRecipientWrap,
          ]);
        },
      );
    });

    group('recoverFullSend', () {
      test(
        're-sends the same signed wrap the relay may already hold',
        () async {
          final (:rowId, wrap: firstWrap) = await unconfirmedSend();

          // The relay stored the first wrap and its OK arrived after the
          // window; it now answers OK true for anything it is sent.
          relay = _Relay.accepts;
          final retried = await repository.recoverFullSend(rumorId: rowId);

          expect(retried.success, isTrue);
          expect(
            wrapsTo(peer).map((wrap) => wrap.id).toSet(),
            equals({firstWrap.id}),
            reason:
                'the retry re-sends the wrap the relay accepted, so the '
                'recipient gets no second kind 1059 for one rumor',
          );
        },
      );

      test('re-sends the wrap a previous session kept', () async {
        final (:rowId, :wrap) = await unconfirmedSend();
        relay = _Relay.accepts;

        final retried = await buildRepository().recoverFullSend(
          rumorId: rowId,
        );

        expect(retried.success, isTrue);
        expect(wrapsTo(peer).map((sent) => sent.id), [wrap.id, wrap.id]);
      });

      test('keeps the wrap through a refusal a retry can outlast', () async {
        final (:rowId, :wrap) = await unconfirmedSend();
        relay = _Relay.rateLimits;
        final limited = await repository.recoverFullSend(rumorId: rowId);
        expect(limited.success, isFalse);

        relay = _Relay.accepts;
        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isTrue);
        expect(
          wrapsTo(peer).map((sent) => sent.id).toSet(),
          equals({wrap.id}),
        );
      });

      test('builds a new wrap once a relay has refused the kept one', () async {
        final (:rowId, :wrap) = await unconfirmedSend();
        relay = _Relay.refuses;
        final refused = await repository.recoverFullSend(rumorId: rowId);
        expect(refused.success, isFalse);
        expect(refused.retryablePending, isFalse, reason: 'a hard refusal');
        expect(
          (await outgoingDao.getById(rowId))!.unconfirmedRecipientWrapJson,
          isNull,
        );

        relay = _Relay.accepts;
        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isTrue);
        final ids = wrapsTo(peer).map((sent) => sent.id).toList();
        expect(ids, hasLength(3));
        expect(ids.take(2), [wrap.id, wrap.id]);
        expect(ids.last, isNot(equals(wrap.id)));
      });
    });
  });
}
