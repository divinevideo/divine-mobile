// ABOUTME: A kind-30078 app-data gift wrap from another account is recorded as
// ABOUTME: handled, so a later launch does not open it again (#10023).

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:nostr_sdk/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/live_dm_reads.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    stubQuietLiveDeletions(this);
  }
}

/// A signer that remembers the ciphertext of every NIP-44 layer it was asked
/// to open, so a test can tell whether a particular gift wrap was decrypted.
class _CountingSigner implements NostrSigner {
  _CountingSigner(this._inner);

  final LocalNostrSigner _inner;

  final List<String> _opened = [];

  /// How many times [wrap] was opened: its outer layer is the `content` the
  /// signer is asked to decrypt first.
  int timesOpened(Event wrap) => _opened.where((c) => c == wrap.content).length;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) {
    _opened.add(ciphertext);
    return _inner.nip44Decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> getPublicKey() => _inner.getPublicKey();

  @override
  Future<Event?> signEvent(Event event) => _inner.signEvent(event);

  @override
  Future<Map<dynamic, dynamic>?> getRelays() => _inner.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _inner.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _inner.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _inner.nip44Encrypt(pubkey, plaintext);

  @override
  void close() => _inner.close();
}

/// A relay that still holds [stored] and hands every event over again each
/// time the app subscribes, as a relay does for any launch whose `since:`
/// window reaches back to them.
class _Relay {
  _Relay(this.stored);

  final List<Event> stored;
  final StreamController<Event> controller =
      StreamController<Event>.broadcast();
  void Function(StoredEventsEnd)? onEnd;

  void deliverStored() {
    stored.forEach(controller.add);
    onEnd?.call(StoredEventsEnd(deliveredEventCount: stored.length));
  }
}

// Throwaway test-only keys; they sign nothing outside this file.
final String _ownerSecret = '1' * 64;
final String _peerSecret = '3' * 64;
final String _carolSecret = '4' * 64;
final String _owner = getPublicKey(_ownerSecret);

const _otherAppDTag = 'some/other/app';
const _settleTimeout = Duration(seconds: 20);

/// Whether a gift wrap left a message row or a processed-wrap ledger entry.
const _storedSql = '''
SELECT EXISTS (SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1)
  OR EXISTS (SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1)
  AS stored
''';

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// A real, fully signed NIP-59 gift wrap to the owner of a rumor written by
/// [authorSecret], with the outer stamp [wire].
Future<Event> _wrap({
  required String authorSecret,
  required int kind,
  required List<List<String>> tags,
  required String content,
  required int wire,
}) async {
  final author = getPublicKey(authorSecret);
  final rumor = Event(author, kind, tags, content, createdAt: wire + 300);
  final seal = Event(
    author,
    EventKind.sealEventKind,
    [],
    await NIP44V2.encrypt(
      jsonEncode(rumor.toJson()..remove('sig')),
      NIP44V2.shareSecret(authorSecret, _owner),
    ),
    createdAt: wire,
  )..sign(authorSecret);
  final ephemeral = generatePrivateKey();
  return Event(
    getPublicKey(ephemeral),
    EventKind.giftWrap,
    [
      ['p', _owner],
    ],
    await NIP44V2.encrypt(
      jsonEncode(seal.toJson()),
      NIP44V2.shareSecret(ephemeral, _owner),
    ),
    createdAt: wire,
  )..sign(ephemeral);
}

Future<Event> _appData(String authorSecret, {required int wire}) => _wrap(
  authorSecret: authorSecret,
  kind: EventKind.appSpecificData,
  tags: [
    ['d', _otherAppDTag],
  ],
  content: '{"theme":"dark"}',
  wire: wire,
);

/// A text message from Carol. Its row marks the end of a launch's handling,
/// because gift wraps are handled one at a time in the order they arrive.
Future<Event> _carolMessage(String text, {required int wire}) => _wrap(
  authorSecret: _carolSecret,
  kind: EventKind.privateDirectMessage,
  tags: [
    ['p', _owner],
  ],
  content: text,
  wire: wire,
);

void main() {
  group(DmRepository, () {
    group('gift wraps carrying kind-30078 app data', () {
      late AppDatabase db;
      late SharedPreferences prefs;

      setUpAll(() {
        registerFallbackValue(Duration.zero);
      });

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
        db = AppDatabase.test(NativeDatabase.memory());
      });

      tearDown(() async {
        await db.close();
      });

      _MockNostrClient clientFor(_Relay relay) {
        final client = _MockNostrClient();
        when(() => client.connectedRelayCount).thenReturn(1);
        when(() => client.configuredRelayCount).thenReturn(1);
        when(() => client.configuredRelays).thenReturn(const ['wss://r']);
        when(
          () => client.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => const <Event>[]);
        when(
          () => client.queryEventsDetailed(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
            tempRelays: any(named: 'tempRelays'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            acceptRelayClosedWhenOthersAnswered: any(
              named: 'acceptRelayClosedWhenOthersAnswered',
            ),
            timeout: any(named: 'timeout'),
            silentRelayTimeout: any(named: 'silentRelayTimeout'),
          ),
        ).thenAnswer(
          (_) async => (
            events: const <Event>[],
            timedOut: false,
            noRelays: false,
          ),
        );
        when(() => client.unsubscribe(any())).thenAnswer((_) async {});
        when(
          () => client.subscribe(
            any(that: isLiveDmRead),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            onStoredEventsStart: any(named: 'onStoredEventsStart'),
            onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
          ),
        ).thenAnswer((invocation) {
          relay.onEnd =
              invocation.namedArguments[#onStoredEventsEnd]
                  as void Function(StoredEventsEnd)?;
          return relay.controller.stream;
        });
        return client;
      }

      Future<void> messageRowOf(Event wrap) => db
          .customSelect(
            _storedSql,
            variables: [Variable.withString(wrap.id)],
            readsFrom: {db.directMessages, db.processedGiftWraps},
          )
          .watchSingle()
          .firstWhere((row) => row.read<bool>('stored'))
          .timeout(
            _settleTimeout,
            onTimeout: () => fail('gift wrap ${wrap.id} was never handled'),
          );

      /// One launch of the app over the same database: a fresh repository
      /// subscribes, the relay hands its stored wraps over, and the launch is
      /// over once [lastWrap] has been handled.
      Future<_CountingSigner> launch(_Relay relay, Event lastWrap) async {
        final signer = _CountingSigner(LocalNostrSigner(_ownerSecret));
        final messagesDao = DirectMessagesDao(db);
        final conversationsDao = ConversationsDao(db);
        final repository = DmRepository(
          nostrClient: clientFor(relay),
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
          removedConversationsDao: RemovedConversationsDao(db),
          outgoingDmsDao: OutgoingDmsDao(db),
          reactionsRepository: DmReactionsRepository(
            reactionsDao: DmReactionsDao(db),
            conversationsDao: conversationsDao,
            directMessagesDao: messagesDao,
            userPubkey: _owner,
          ),
          syncState: DmSyncState(prefs),
          userPubkey: _owner,
          signer: signer,
        );
        addTearDown(repository.stopListening);
        await repository.startListening();
        relay.deliverStored();
        await messageRowOf(lastWrap);
        await repository.stopListening();
        return signer;
      }

      test(
        "another account's app data is opened once and not on a later launch",
        () async {
          final at = _now();
          final appData = await _appData(_peerSecret, wire: at - 7200);
          final firstMessage = await _carolMessage('one', wire: at - 3600);
          final secondMessage = await _carolMessage('two', wire: at - 1800);
          final relay = _Relay([appData, firstMessage]);

          final firstLaunch = await launch(relay, firstMessage);
          relay.stored.add(secondMessage);
          final secondLaunch = await launch(relay, secondMessage);

          // The first launch must really open it, or the second proves nothing.
          expect(firstLaunch.timesOpened(appData), greaterThan(0));
          expect(secondLaunch.timesOpened(appData), equals(0));
        },
      );

      test(
        "the account's own app data is still opened on a later launch",
        () async {
          final at = _now();
          final ownAppData = await _appData(_ownerSecret, wire: at - 7200);
          final firstMessage = await _carolMessage('one', wire: at - 3600);
          final secondMessage = await _carolMessage('two', wire: at - 1800);
          final relay = _Relay([ownAppData, firstMessage]);

          final firstLaunch = await launch(relay, firstMessage);
          relay.stored.add(secondMessage);
          final secondLaunch = await launch(relay, secondMessage);

          expect(firstLaunch.timesOpened(ownAppData), greaterThan(0));
          expect(secondLaunch.timesOpened(ownAppData), greaterThan(0));
        },
      );
    });
  });
}
