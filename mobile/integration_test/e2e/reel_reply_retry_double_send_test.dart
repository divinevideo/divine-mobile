// ABOUTME: E2E regression for #7316 — tapping Retry on a failed reel DM reply
// ABOUTME: must re-drive the parked outgoing_dms row, never mint a second
// ABOUTME: rumor the recipient would render as a second message.
// ABOUTME: Drives the real ReelDmReplyBar + InlineReelReplyCubit + DmRepository
// ABOUTME: over a real socket to an in-process relay.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
library;

import 'package:analytics/analytics.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_feed_item/reel_dm_reply_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';
import '../helpers/test_setup.dart';

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockScreenAnalyticsService extends Mock
    implements ScreenAnalyticsService {}

/// Points every dialed address at the in-process relay.
class _RedirectFactory implements WebSocketChannelFactory {
  _RedirectFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientKey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  final senderPubkey = getPublicKey(senderKey);
  final recipientPubkey = getPublicKey(recipientKey);
  const reelMessageId =
      'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

  final replyContext = DmReplyContext(
    conversationId: DmRepository.computeConversationId(
      [senderPubkey, recipientPubkey]..sort(),
    ),
    participantPubkeys: [recipientPubkey],
    isGroup: false,
    sharedReelMessageId: reelMessageId,
    messageAuthorPubkey: recipientPubkey,
    hintName: 'Alice',
    isOwnMessage: false,
  );

  /// Real Nostr → NostrClient → NIP17MessageService → DmRepository, with a
  /// real Drift database, every socket landing on [relay].
  Future<({DmRepository repository, AppDatabase db, Nostr nostr})> buildStack(
    FakeRelay relay,
  ) async {
    final factory = _RedirectFactory(relay.port);
    final signer = LocalNostrSigner(senderKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
        autoReconnect: false,
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );

    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);

    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: senderPubkey,
      signer: signer,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: senderPubkey,
        nostrService: client,
      ),
    );
    addTearDown(repository.stopListening);
    addTearDown(nostr.relayPool.removeAll);

    await client.initialize();

    return (repository: repository, db: db, nostr: nostr);
  }

  Widget wrap(DmRepository repository, SharedPreferences preferences) {
    final reactionsRepo = _MockDmReactionsRepository();
    final auth = _MockAuthService();
    final analytics = _MockScreenAnalyticsService();

    when(
      () => reactionsRepo.watchForConversation(any()),
    ).thenAnswer((_) => const Stream<List<DmReaction>>.empty());
    when(() => auth.currentPublicKeyHex).thenReturn(senderPubkey);
    when(
      () => analytics.trackInteraction(
        any(),
        any(),
        params: any(named: 'params'),
      ),
    ).thenReturn(null);

    return ProviderScope(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repository),
        dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
        authServiceProvider.overrideWithValue(auth),
        screenAnalyticsServiceProvider.overrideWithValue(analytics),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ReelDmReplyBarHost(dmReplyContext: replyContext),
          ),
        ),
      ),
    );
  }

  group('#7316 reel reply soft-unconfirmed delivery', () {
    testWidgets(
      'stays optimistic and parks exactly one outgoing_dms row',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));

        // A relay that accepts the frame but never sends `OK` — the exact
        // soft/unconfirmed shape the issue calls the worse case.
        final relay = await FakeRelay.start(okConfirms: false);
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final preferences = await SharedPreferences.getInstance();

        await tester.pumpWidget(wrap(stack.repository, preferences));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));

        // ── First send ──
        logPhase('── Phase 1: first send (will go unconfirmed) ──');
        await tester.enterText(find.byType(TextField), 'reel reply probe');
        await tester.pump();
        await tester.tap(find.byType(IconButton));
        await tester.pump();

        // Let the send run its full OK-confirm budget. A soft-unconfirmed
        // result is durable and retryable in the background, so it must stay
        // optimistic instead of presenting the manual hard-failure action.
        await pumpUntilSettled(tester, maxSeconds: 20);
        expect(find.text(l10n.dmSendFailedRetry), findsNothing);

        final afterFirst = await stack.db.outgoingDmsDao.getForConversation(
          conversationId: replyContext.conversationId,
          ownerPubkey: senderPubkey,
        );
        logPhase('rows after first send: ${afterFirst.length}');
        for (final row in afterFirst) {
          logPhase('  row id=${row.id} content="${row.content}"');
        }
        expect(
          afterFirst,
          hasLength(1),
          reason: 'the first send must park exactly one durable row',
        );
        expect(
          afterFirst.single.content,
          'reel reply probe',
          reason: 'the parked row still carries the reply text',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
