// ABOUTME: Guards the pre-enqueue size refusal on DmRepository's send paths
// ABOUTME: (#7331): NIP-44's u16 length prefix caps what the NIP-17 double
// ABOUTME: encryption can carry, and the throw is deterministic, so an
// ABOUTME: oversized rumor must be refused BEFORE a retry-swept row exists.

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

class _FakeOutgoingDm extends Fake implements OutgoingDm {}

const _ownerPubkey =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _recipientPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
const _otherRecipientPubkey =
    'c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1b2';
const _privateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

void main() {
  group('$DmRepository oversized message refusal', () {
    late _MockNostrClient nostrClient;
    late _MockNIP17MessageService messageService;
    late _MockOutgoingDmsDao outgoingDao;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeOutgoingDm());
      registerFallbackValue(Duration.zero);
    });

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

      when(() => nostrClient.connectedRelayCount).thenReturn(2);
      when(() => nostrClient.configuredRelayCount).thenReturn(2);
      when(() => outgoingDao.enqueue(any())).thenAnswer((_) async {});
      // Setting credentials starts post-auth maintenance, which reads the
      // queue to drop self-addressed rows (#8363). Left unstubbed, that read
      // throws inside the pass and is swallowed there.
      when(
        () => outgoingDao.getAllForOwner(any()),
      ).thenAnswer((_) async => const <OutgoingDm>[]);
      // The size guard runs after the send-policy gate and after the rumor is
      // built, but still before the enqueue — so the policy gate must permit
      // the send for the size check to be reached at all.
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
      // Admitted sends run on to the publish; stubbed to a plain failure so
      // the test asserts on the guard's decision, not on delivery.
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('stubbed'));
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final content = invocation.namedArguments[#content] as String;
        final tags =
            (invocation.namedArguments[#additionalTags]
                        as List<List<String>>? ??
                    const <List<String>>[])
                .toList();
        return Event(_ownerPubkey, EventKind.privateDirectMessage, [
          ['p', _recipientPubkey],
          ...tags,
        ], content);
      });
      when(
        () => messageService.buildGroupRumor(
          recipientPubkeys: any(named: 'recipientPubkeys'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final content = invocation.namedArguments[#content] as String;
        final recipients =
            invocation.namedArguments[#recipientPubkeys] as List<String>;
        return Event(_ownerPubkey, EventKind.privateDirectMessage, [
          for (final r in recipients) ['p', r],
        ], content);
      });
    });

    test('refuses a rumor over the byte limit with a tooLong result', () async {
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * (maxDmRumorBytes + 1),
      );

      expect(result.success, isFalse);
      expect(result.tooLong, isTrue);
      expect(result.blocked, isFalse);
      expect(result.retryablePending, isFalse);
    });

    test('leaves no queue row for the retry sweep to re-drive', () async {
      // The whole point of refusing before the enqueue: a hard-failed row is
      // re-driven by OutgoingDmRetryService.sweep() on every foreground and
      // reconnect, and an oversized send fails identically every time, so a
      // row here would burn the retry budget on work that cannot succeed.
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * (maxDmRumorBytes + 1),
      );

      expect(result.queuedRumorId, isNull);
      verifyNever(() => outgoingDao.enqueue(any()));
    });

    test('never reaches the signer or the wrap build', () async {
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * (maxDmRumorBytes + 1),
      );
      expect(result.tooLong, isTrue);

      verifyNever(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
        ),
      );
    });

    test('measures UTF-8 bytes, not characters', () async {
      // A character count cannot bound this: '€' is one character and three
      // UTF-8 bytes, so a body well under any sane character limit can still
      // exceed the byte ceiling the NIP-44 chain actually imposes.
      final repository = buildRepository();
      final content = '€' * (maxDmRumorBytes ~/ 3 + 1);

      expect(content.length, lessThan(maxDmRumorBytes));

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: content,
      );

      expect(result.tooLong, isTrue);
    });

    test('refuses an oversized GROUP send, one result per recipient', () async {
      // A group send fans one rumor out to N recipients, so an unguarded
      // oversized body parks N retry-swept rows instead of one — and the extra
      // `p` tags lower the real NIP-44 ceiling rather than raising it.
      final repository = buildRepository();
      final recipients = [_recipientPubkey, _otherRecipientPubkey];

      final results = await repository.sendGroupMessage(
        recipientPubkeys: recipients,
        content: 'a' * (maxDmRumorBytes + 1),
      );

      expect(results, hasLength(recipients.length));
      expect(results.every((r) => r.tooLong), isTrue);
      verifyNever(() => outgoingDao.enqueue(any()));
    });

    test('an oversized self-send reports the self-send refusal', () async {
      // Ordering matters: a note-to-self can never be delivered whatever its
      // size, so the more fundamental reason is the useful one to surface.
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _ownerPubkey,
        content: 'a' * (maxDmRumorBytes + 1),
      );

      expect(result.success, isFalse);
      expect(result.tooLong, isFalse);
      expect(result.error, contains('its own sender'));
    });

    test('admits an ordinary body', () async {
      // Boundary in the other direction: the guard must not refuse a normal
      // message. The exact ceiling is pinned against the real crypto in
      // dm_message_size_crypto_invariant_test.dart.
      final repository = buildRepository();

      final result = await repository.sendMessage(
        recipientPubkey: _recipientPubkey,
        content: 'a' * 1000,
      );

      expect(
        result.tooLong,
        isFalse,
        reason: 'an ordinary body must pass the size guard',
      );
      // Reaching the wrap build is the proof the guard admitted it.
      verify(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
        ),
      ).called(1);
    });
  });
}
