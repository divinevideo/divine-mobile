// ABOUTME: Cold-start regression guard for DmRepository. Asserts that
// ABOUTME: constructing + initializing the repository does zero
// ABOUTME: network or DB work — the line in the sand against
// ABOUTME: regressing the lazy-inbox behavior added in
// ABOUTME: docs/plans/2026-04-05-dm-scaling-fix-design.md.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _FakeEvent extends Fake implements Event {}

const _validPubkeyA =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _validPrivateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

void main() {
  group('$DmRepository cold start', () {
    late _MockNostrClient mockNostrClient;
    late _MockNIP17MessageService mockMessageService;
    late _MockDirectMessagesDao mockDirectMessagesDao;
    late _MockConversationsDao mockConversationsDao;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      // queryEventsDetailed takes a `Duration timeout` (#8212).
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockMessageService = _MockNIP17MessageService();
      mockDirectMessagesDao = _MockDirectMessagesDao();
      mockConversationsDao = _MockConversationsDao();

      // Stub relay properties in case any log statement touches them.
      when(() => mockNostrClient.connectedRelayCount).thenReturn(3);
      when(() => mockNostrClient.configuredRelayCount).thenReturn(3);
    });

    test(
      'construct + initialize triggers zero network or DB work',
      () async {
        // Regression guard for lazy-inbox behavior. Any reintroduction of
        // eager subscribe / queryEvents / DAO writes from initialize() will
        // break this test. See
        // docs/plans/2026-04-05-dm-scaling-fix-design.md.
        final repository =
            DmRepository(
              nostrClient: mockNostrClient,
              messageService: mockMessageService,
              directMessagesDao: mockDirectMessagesDao,
              conversationsDao: mockConversationsDao,
              // Intentionally no userPubkey/signer — initialize() provides them.
            )..setCredentials(
              userPubkey: _validPubkeyA,
              signer: LocalNostrSigner(_validPrivateKey),
              messageService: mockMessageService,
            );

        // Give any misbehaving async side-effects a chance to run.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // No relay subscription should have been opened.
        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );

        // No one-shot relay query either, through either read API — the own
        // kind-10050 resolve moved to queryEventsDetailed (#8212), so
        // asserting only on queryEvents would pass vacuously.
        verifyNever(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
          ),
        );
        verifyNever(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            acceptRelayClosedWhenOthersAnswered: any(
              named: 'acceptRelayClosedWhenOthersAnswered',
            ),
            timeout: any(named: 'timeout'),
          ),
        );

        // No DB reads checking for existing gift wraps.
        verifyNever(() => mockDirectMessagesDao.hasGiftWrap(any()));

        // No DB writes persisting messages.
        verifyNever(
          () => mockDirectMessagesDao.insertMessage(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            senderPubkey: any(named: 'senderPubkey'),
            content: any(named: 'content'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            messageKind: any(named: 'messageKind'),
            replyToId: any(named: 'replyToId'),
            subject: any(named: 'subject'),
            fileType: any(named: 'fileType'),
            encryptionAlgorithm: any(named: 'encryptionAlgorithm'),
            decryptionKey: any(named: 'decryptionKey'),
            decryptionNonce: any(named: 'decryptionNonce'),
            fileHash: any(named: 'fileHash'),
            originalFileHash: any(named: 'originalFileHash'),
            fileSize: any(named: 'fileSize'),
            dimensions: any(named: 'dimensions'),
            blurhash: any(named: 'blurhash'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );

        // Sanity check: the repository is usable post-initialize.
        expect(repository.isInitialized, isTrue);
      },
    );
  });
}
