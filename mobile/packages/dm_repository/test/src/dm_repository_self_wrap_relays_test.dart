// ABOUTME: Regression guard for where DmRepository sends the sender's own
// ABOUTME: gift-wrap copy of an outgoing DM (#7328). The self-copy must reach
// ABOUTME: the configured pool UNION the user's advertised kind-10050 DM
// ABOUTME: inbox, because targetRelays FILTERS the pool rather than adding.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

class _FakeEvent extends Fake implements Event {}

const _ownerPubkey =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _recipientPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
const _privateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';
const _rumorId = 'rumor-id-for-self-wrap-recovery';

/// The pool the app is actually connected to.
const _poolRelays = ['wss://relay.divine.video', 'wss://relay.nos.social'];

/// What divine advertises in every account's kind-10050 — its own relay plus
/// the two tagged inbox relays. Two of these are NOT in [_poolRelays], which
/// is the entire failure this file guards.
const _advertisedInbox = [
  'wss://relay.divine.video',
  'wss://nos.lol',
  'wss://relay.primal.net',
];

void main() {
  group('$DmRepository self-wrap destination', () {
    late _MockNostrClient nostrClient;
    late _MockNIP17MessageService messageService;
    late _MockOutgoingDmsDao outgoingDao;
    late List<String?> capturedTargets;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(Duration.zero);
    });

    /// A stored queue row whose self-wrap never landed — the shape
    /// `recoverSelfWrap` exists to finish.
    OutgoingDm pendingSelfWrapRow() {
      final rumor = Event(
        _ownerPubkey,
        EventKind.privateDirectMessage,
        [
          ['p', _recipientPubkey],
        ],
        'recovered message',
      );
      return OutgoingDm(
        id: _rumorId,
        conversationId: 'conversation-id',
        recipientPubkey: _recipientPubkey,
        content: 'recovered message',
        createdAt: 1788000000,
        rumorEventJson: jsonEncode(rumor.toJson()),
        recipientWrapStatus: OutgoingWrapStatus.sent,
        selfWrapStatus: OutgoingWrapStatus.pending,
        queuedAt: DateTime.fromMillisecondsSinceEpoch(1788000000000),
        ownerPubkey: _ownerPubkey,
      );
    }

    /// Answers the own-kind-10050 lookup with [relayTags], or with nothing at
    /// all when it is null (the `absent` outcome).
    void stubOwnDmInbox(List<String>? relayTags) {
      final events = relayTags == null
          ? <Event>[]
          : <Event>[
              Event(
                _ownerPubkey,
                EventKind.dmRelaysList,
                [
                  for (final relay in relayTags) ['relay', relay],
                ],
                '',
              ),
            ];
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: events,
          timedOut: false,
          noRelays: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );
    }

    DmRepository buildRepository() {
      return DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: _MockDirectMessagesDao(),
        conversationsDao: _MockConversationsDao(),
        outgoingDmsDao: outgoingDao,
      )..setCredentials(
        userPubkey: _ownerPubkey,
        signer: LocalNostrSigner(_privateKey),
        messageService: messageService,
      );
    }

    setUp(() {
      nostrClient = _MockNostrClient();
      messageService = _MockNIP17MessageService();
      outgoingDao = _MockOutgoingDmsDao();
      capturedTargets = <String?>[];

      when(() => nostrClient.connectedRelayCount).thenReturn(2);
      when(() => nostrClient.configuredRelayCount).thenReturn(2);
      when(() => nostrClient.configuredRelays).thenReturn(_poolRelays);

      when(() => outgoingDao.getById(any())).thenAnswer(
        (_) async => pendingSelfWrapRow(),
      );
      when(() => outgoingDao.deleteById(any())).thenAnswer((_) async => 1);

      when(
        () => messageService.publishSelfWrap(
          rumorEvent: any(named: 'rumorEvent'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        final targets =
            invocation.namedArguments[#targetRelays] as List<String>?;
        capturedTargets.add(targets?.join(','));
        return NIP17SendResult.success(
          rumorEventId: _rumorId,
          messageEventId: _rumorId,
          recipientPubkey: _ownerPubkey,
        );
      });
    });

    test(
      'unions the connected pool with the advertised kind-10050 inbox',
      () async {
        stubOwnDmInbox(_advertisedInbox);

        final result = await buildRepository().recoverSelfWrap(
          rumorId: _rumorId,
        );

        expect(result.success, isTrue);
        expect(capturedTargets, hasLength(1));
        final targets = capturedTargets.single!.split(',');
        // Both halves, and no duplicate for the relay that is in both:
        // `targetRelays` filters the pool, so dropping a pool relay here
        // would silently narrow the self-copy instead of widening it.
        expect(
          targets,
          containsAll(_poolRelays),
          reason:
              'omitting the pool would trade the write redundancy #8378 '
              'deliberately preserved for inbox reach, rather than gaining '
              'both',
        );
        expect(
          targets,
          containsAll(['wss://nos.lol', 'wss://relay.primal.net']),
          reason:
              'these are advertised in the account own kind-10050 but are not '
              'in the pool — reaching them is the whole point of #7328',
        );
        expect(
          targets.toSet(),
          hasLength(targets.length),
          reason: 'relay.divine.video is in both sets and must appear once',
        );
      },
    );

    test(
      'falls back to the plain pool publish when no inbox is advertised',
      () async {
        // The `absent` outcome. An account with no kind-10050 keeps exactly
        // its pre-#7328 behaviour rather than being pinned to the pool list
        // as an explicit filter.
        stubOwnDmInbox(null);

        final result = await buildRepository().recoverSelfWrap(
          rumorId: _rumorId,
        );

        expect(result.success, isTrue);
        expect(capturedTargets, equals([null]));
      },
    );
  });
}
