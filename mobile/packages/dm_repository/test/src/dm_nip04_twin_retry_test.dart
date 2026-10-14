// ABOUTME: #8506 — the legacy kind-4 copy sent beside a NIP-17 message to a
// ABOUTME: nip04-latched peer survives a publish no relay accepts.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

/// A local signer whose NIP-04 encryption each test scripts.
class _ScriptedEncryptSigner extends LocalNostrSigner {
  _ScriptedEncryptSigner(super._privateKey, this._encrypt);

  final Future<String?> Function() _encrypt;

  /// How many times the kind-4 copy was encrypted. Preparation runs once.
  int encryptCalls = 0;

  @override
  Future<String?> encrypt(dynamic pubkey, dynamic plaintext) {
    encryptCalls++;
    return _encrypt();
  }
}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _otherOwner =
    'c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5061728394a5b6c7d8e9f0a1b2';
const _otherPrivateKey =
    '6537f6c9c5c1f3b2a6f9e4d8bac3a5f7e9d1b3c5a7f9e1d3b5c7a9f1e3d5b7c9';
const _wrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _relay = 'wss://relay.divine.video';
const _baseCreatedAt = 1700000000;

PublishOutcome _accepted(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const [_relay],
  rejectedBy: const <String, String>{},
  noResponseFrom: const <String>[],
);

PublishOutcome _unanswered(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const <String>[],
  rejectedBy: const <String, String>{},
  noResponseFrom: const [_relay],
);

/// Runs [future] to completion under [async] and returns its value.
T _resolve<T>(FakeAsync async, Future<T> future) {
  late T value;
  var done = false;
  unawaited(
    future.then((v) {
      value = v;
      done = true;
    }),
  );
  async
    ..flushMicrotasks()
    ..elapse(Duration.zero);
  expect(done, isTrue, reason: 'the future did not complete');
  return value;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  // Real DAOs and the outgoing queue wired, as production wires them: the
  // queue's presence changes which inbox states reach the kind-4 gate (#7317),
  // and `absent` is the state that still dual-sends.
  group('the legacy kind-4 copy (#8506)', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;

    /// Answers kind-4 publishes in order; once it runs out, every further
    /// attempt is accepted.
    late List<Future<PublishOutcome> Function(Event)> kind4Answers;

    /// Every kind 4 handed to the relays, in order.
    late List<Event> kind4Attempts;

    final participants = [_owner, _peer]..sort();
    final conversationId = DmRepository.computeConversationId(participants);

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      kind4Answers = [];
      kind4Attempts = [];
      await LogCaptureService().clearAllLogs();

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      // No kind 10050 anywhere: the peer's inbox resolves `absent`.
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
          timeout: any(named: 'timeout'),
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
        if (event.kind != EventKind.directMessage) return _accepted(event);
        kind4Attempts.add(event);
        if (kind4Answers.isEmpty) return _accepted(event);
        return kind4Answers.removeAt(0)(event);
      });
      when(
        () => messageService.canSendTo(any()),
      ).thenAnswer((_) async => true);
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (invocation) => Event(
          _owner,
          invocation.namedArguments[#eventKind] as int? ??
              EventKind.privateDirectMessage,
          [
            ['p', _peer],
            ...invocation.namedArguments[#additionalTags] as List<List<String>>,
          ],
          invocation.namedArguments[#content] as String,
        ),
      );
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer(
        (invocation) async => NIP17SendResult.success(
          rumorEventId: (invocation.namedArguments[#rumorEvent] as Event).id,
          messageEventId: _wrapId,
          recipientPubkey: _peer,
        ),
      );
    });

    tearDown(() => db.close());

    DmRepository buildRepository({NostrSigner? signer}) => DmRepository(
      nostrClient: nostrClient,
      messageService: messageService,
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      outgoingDmsDao: OutgoingDmsDao(db),
      processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
      userPubkey: _owner,
      signer: signer ?? LocalNostrSigner(_privateKey),
    );

    /// A thread the peer opened over NIP-04, so the kind-4 gate is open.
    Future<void> seedLatchedThread() => conversationsDao.upsertConversation(
      id: conversationId,
      participantPubkeys: jsonEncode(participants),
      isGroup: false,
      createdAt: _baseCreatedAt,
      lastMessageTimestamp: _baseCreatedAt,
      ownerPubkey: _owner,
      dmProtocol: 'nip04',
    );

    /// Seeds the latched thread and sends one message over it, leaving the
    /// first kind-4 attempt answered by [first].
    NIP17SendResult sendOverLatchedThread(
      FakeAsync async,
      DmRepository repository, {
      Future<PublishOutcome> Function(Event)? first,
    }) {
      if (first != null) kind4Answers.add(first);
      _resolve(async, seedLatchedThread());
      final result = _resolve(
        async,
        repository.sendMessage(recipientPubkey: _peer, content: 'hi'),
      );
      expect(result.success, isTrue);
      return result;
    }

    Iterable<LogEntry> logsNaming(String eventId) => LogCaptureService()
        .getRecentLogs()
        .where((entry) => entry.message.contains(eventId));

    group('sendMessage', () {
      test(
        'republishes the same signed kind 4 once the backoff has passed',
        () {
          fakeAsync((async) {
            sendOverLatchedThread(
              async,
              buildRepository(),
              first: (e) async => _unanswered(e),
            );
            expect(kind4Attempts, hasLength(1));

            async.elapse(const Duration(seconds: 1));
            expect(kind4Attempts, hasLength(1));

            async.elapse(const Duration(seconds: 2));
            expect(kind4Attempts, hasLength(2));
            expect(kind4Attempts.last.id, equals(kind4Attempts.first.id));
            expect(kind4Attempts.last.sig, equals(kind4Attempts.first.sig));

            async.elapse(const Duration(seconds: 30));
            expect(kind4Attempts, hasLength(2));
            final stored = _resolve(
              async,
              messagesDao.getMessagesForConversation(
                conversationId,
                ownerPubkey: _owner,
              ),
            );
            expect(stored.map((m) => m.content), equals(['hi']));
          });
        },
      );

      test('publishes a single copy when the first attempt is accepted', () {
        fakeAsync((async) {
          sendOverLatchedThread(async, buildRepository());

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });

      test('stops after three attempts and logs that it gave up', () {
        fakeAsync((async) {
          kind4Answers.addAll([
            (e) async => _unanswered(e),
            (e) async => _unanswered(e),
          ]);
          sendOverLatchedThread(
            async,
            buildRepository(),
            first: (e) async => _unanswered(e),
          );

          async.elapse(const Duration(seconds: 60));
          expect(kind4Attempts, hasLength(3));
          expect(kind4Attempts.map((e) => e.id).toSet(), hasLength(1));

          final lines = logsNaming(kind4Attempts.first.id);
          expect(
            lines.where((l) => l.level == LogLevel.warning),
            hasLength(2),
            reason: 'each attempt that will be retried says so',
          );
          expect(
            lines.where((l) => l.level == LogLevel.error),
            hasLength(1),
            reason: 'exhaustion is logged once, after the last attempt',
          );
        });
      });

      test('retries an attempt whose publish threw', () {
        fakeAsync((async) {
          sendOverLatchedThread(
            async,
            buildRepository(),
            first: (_) async => throw StateError('socket closed'),
          );

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(2));
          expect(kind4Attempts.last.id, equals(kind4Attempts.first.id));
        });
      });
    });

    group('preparation failures', () {
      test('send nothing, and never retry, when encryption returns null', () {
        fakeAsync((async) {
          final signer = _ScriptedEncryptSigner(_privateKey, () async => null);
          sendOverLatchedThread(async, buildRepository(signer: signer));

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, isEmpty);
          expect(signer.encryptCalls, equals(1));
        });
      });

      test('send nothing, and never retry, when encryption throws', () {
        fakeAsync((async) {
          final signer = _ScriptedEncryptSigner(
            _privateKey,
            () async => throw TimeoutException('bunker did not answer'),
          );
          sendOverLatchedThread(async, buildRepository(signer: signer));

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, isEmpty);
          expect(signer.encryptCalls, equals(1));
        });
      });
    });

    /// Queues a send that never reached the recipient, as the retry sweep
    /// finds one, with [tags] on its rumor after the recipient's `p` tag.
    String queueUndeliveredSend(
      FakeAsync async, {
      List<List<String>> tags = const [],
      String? replyToId,
    }) {
      final rumor = Event(
        _owner,
        EventKind.privateDirectMessage,
        [
          ['p', _peer],
          ...tags,
        ],
        'queued while offline',
        createdAt: _baseCreatedAt,
      );
      _resolve(
        async,
        OutgoingDmsDao(db).enqueue(
          OutgoingDm(
            id: rumor.id,
            conversationId: conversationId,
            recipientPubkey: _peer,
            content: rumor.content,
            createdAt: _baseCreatedAt,
            rumorEventJson: jsonEncode(rumor.toJson()),
            recipientWrapStatus: OutgoingWrapStatus.failed,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime.utc(2026, 10),
            ownerPubkey: _owner,
            replyToId: replyToId,
          ),
        ),
      );
      return rumor.id;
    }

    group('recoverFullSend', () {
      const batchTag = ['batch', 'queued-send-batch'];

      test('sends the kind 4 a recovered plain-text message never got', () {
        fakeAsync((async) {
          final repository = buildRepository();
          _resolve(async, seedLatchedThread());
          final rumorId = queueUndeliveredSend(async, tags: [batchTag]);

          final result = _resolve(
            async,
            repository.recoverFullSend(rumorId: rumorId),
          );
          expect(result.success, isTrue);

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
          expect(
            kind4Attempts.single.tags,
            contains(equals(['p', _peer])),
          );
        });
      });

      test('sends the kind 4 for a recovered reply', () {
        fakeAsync((async) {
          final repository = buildRepository();
          _resolve(async, seedLatchedThread());
          final parentId = 'd' * 64;
          final rumorId = queueUndeliveredSend(
            async,
            tags: [
              ['e', parentId],
              batchTag,
            ],
            replyToId: parentId,
          );

          _resolve(async, repository.recoverFullSend(rumorId: rumorId));

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });

      test(
        'sends no kind 4 for a recovered message with structured tags, which '
        'a share or an invite opted out of',
        () {
          fakeAsync((async) {
            final repository = buildRepository();
            _resolve(async, seedLatchedThread());
            final rumorId = queueUndeliveredSend(
              async,
              tags: [
                ['q', '34236:$_peer:clip', _relay],
                batchTag,
              ],
            );

            final result = _resolve(
              async,
              repository.recoverFullSend(rumorId: rumorId),
            );
            expect(result.success, isTrue);

            async.elapse(const Duration(seconds: 30));
            expect(kind4Attempts, isEmpty);
          });
        },
      );

      test(
        'sends no kind 4 for a recovered message that names anyone beyond '
        'its recipient',
        () {
          fakeAsync((async) {
            final repository = buildRepository();
            _resolve(async, seedLatchedThread());
            final rumorId = queueUndeliveredSend(
              async,
              tags: [
                ['p', _otherOwner],
                batchTag,
              ],
            );

            final result = _resolve(
              async,
              repository.recoverFullSend(rumorId: rumorId),
            );
            expect(result.success, isTrue);

            async.elapse(const Duration(seconds: 30));
            expect(kind4Attempts, isEmpty);
          });
        },
      );

      test(
        'sends no kind 4 for a recovered message citing an event it does not '
        'reply to',
        () {
          fakeAsync((async) {
            final repository = buildRepository();
            _resolve(async, seedLatchedThread());
            final rumorId = queueUndeliveredSend(
              async,
              tags: [
                ['e', 'd' * 64],
                batchTag,
              ],
            );

            final result = _resolve(
              async,
              repository.recoverFullSend(rumorId: rumorId),
            );
            expect(result.success, isTrue);

            async.elapse(const Duration(seconds: 30));
            expect(kind4Attempts, isEmpty);
          });
        },
      );

      test('sends no kind 4 when the thread is no longer latched', () {
        fakeAsync((async) {
          final repository = buildRepository();
          _resolve(
            async,
            conversationsDao.upsertConversation(
              id: conversationId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              createdAt: _baseCreatedAt,
              lastMessageTimestamp: _baseCreatedAt,
              ownerPubkey: _owner,
              dmProtocol: 'nip17',
            ),
          );
          final rumorId = queueUndeliveredSend(async, tags: [batchTag]);

          final result = _resolve(
            async,
            repository.recoverFullSend(rumorId: rumorId),
          );
          expect(result.success, isTrue);

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, isEmpty);
        });
      });
    });

    group('preparation', () {
      test(
        'publishes nothing when another account signs in while the copy is '
        'being encrypted',
        () {
          fakeAsync((async) {
            final encrypting = Completer<String?>();
            final repository = buildRepository(
              signer: _ScriptedEncryptSigner(
                _privateKey,
                () => encrypting.future,
              ),
            );
            sendOverLatchedThread(async, repository);
            expect(kind4Attempts, isEmpty, reason: 'still encrypting');

            repository.setCredentials(
              userPubkey: _otherOwner,
              signer: LocalNostrSigner(_otherPrivateKey),
              messageService: messageService,
            );
            encrypting.complete('ciphertext?iv=aXY=');

            async.elapse(const Duration(seconds: 30));
            expect(kind4Attempts, isEmpty);
          });
        },
      );
    });

    group('a pending retry stops', () {
      test('when the message is deleted for everyone during the backoff', () {
        fakeAsync((async) {
          final repository = buildRepository();
          final sent = sendOverLatchedThread(
            async,
            repository,
            first: (e) async => _unanswered(e),
          );
          expect(kind4Attempts, hasLength(1));

          async.elapse(const Duration(seconds: 1));
          _resolve(
            async,
            repository.deleteMessageForEveryone(sent.rumorEventId!),
          );

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });

      test('when the conversation is removed during the backoff', () {
        fakeAsync((async) {
          final repository = buildRepository();
          sendOverLatchedThread(
            async,
            repository,
            first: (e) async => _unanswered(e),
          );
          expect(kind4Attempts, hasLength(1));

          async.elapse(const Duration(seconds: 1));
          _resolve(async, repository.removeConversation(conversationId));

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });

      test('when the thread stops being latched during the backoff', () {
        fakeAsync((async) {
          sendOverLatchedThread(
            async,
            buildRepository(),
            first: (e) async => _unanswered(e),
          );
          expect(kind4Attempts, hasLength(1));

          async.elapse(const Duration(seconds: 1));
          final cleared = _resolve(
            async,
            conversationsDao.clearNip04ProtocolLatch(
              conversationId,
              ownerPubkey: _owner,
            ),
          );
          expect(cleared, isTrue);

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });

      test('when the repository is stopped during the backoff', () {
        fakeAsync((async) {
          final repository = buildRepository();
          sendOverLatchedThread(
            async,
            repository,
            first: (e) async => _unanswered(e),
          );
          expect(kind4Attempts, hasLength(1));

          async.elapse(const Duration(seconds: 1));
          _resolve(async, repository.stopListening());
          expect(
            async.pendingTimers,
            isEmpty,
            reason: 'stopping cancels the armed retry instead of leaving it',
          );

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });

      test(
        'when the repository is stopped while an attempt is in flight',
        () {
          fakeAsync((async) {
            final inFlight = Completer<PublishOutcome>();
            final repository = buildRepository();
            sendOverLatchedThread(
              async,
              repository,
              first: (_) => inFlight.future,
            );
            expect(kind4Attempts, hasLength(1));

            _resolve(async, repository.stopListening());
            inFlight.complete(_unanswered(kind4Attempts.single));
            async.flushMicrotasks();
            expect(
              async.pendingTimers,
              isEmpty,
              reason: 'a failure that lands after the stop arms no retry',
            );

            async.elapse(const Duration(seconds: 30));
            expect(kind4Attempts, hasLength(1));
          });
        },
      );

      test('when another account signs in during the backoff', () {
        fakeAsync((async) {
          final repository = buildRepository();
          sendOverLatchedThread(
            async,
            repository,
            first: (e) async => _unanswered(e),
          );
          expect(kind4Attempts, hasLength(1));

          async.elapse(const Duration(seconds: 1));
          repository.setCredentials(
            userPubkey: _otherOwner,
            signer: LocalNostrSigner(_otherPrivateKey),
            messageService: messageService,
          );
          async.flushMicrotasks();
          expect(
            async.pendingTimers,
            isEmpty,
            reason: 'the switch cancels the armed retry instead of leaving it',
          );

          async.elapse(const Duration(seconds: 30));
          expect(kind4Attempts, hasLength(1));
        });
      });
    });
  });
}
