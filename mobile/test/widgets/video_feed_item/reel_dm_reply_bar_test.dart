// ABOUTME: Widget tests for the in-player DM reel reply/reaction bar.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_feed_item/reel_dm_reply_bar.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _reelId =
    'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

DmReplyContext context({bool isOwn = false, String hintName = 'Alice'}) =>
    DmReplyContext(
      conversationId: 'convo-id',
      participantPubkeys: const [_peer],
      isGroup: false,
      sharedReelMessageId: _reelId,
      messageAuthorPubkey: _peer,
      hintName: hintName,
      isOwnMessage: isOwn,
    );

List<String> captureAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map) announcements.add('${data['message']}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}

void main() {
  late _MockDmRepository dmRepo;
  late _MockDmReactionsRepository reactionsRepo;
  late _MockAuthService auth;
  late _MockContentBlocklistRepository blocklist;
  late StreamController<List<DmReaction>> reactionStream;

  setUp(() {
    dmRepo = _MockDmRepository();
    reactionsRepo = _MockDmReactionsRepository();
    auth = _MockAuthService();
    blocklist = _MockContentBlocklistRepository();
    reactionStream = StreamController<List<DmReaction>>.broadcast();

    when(() => auth.currentPublicKeyHex).thenReturn(_owner);
    when(() => blocklist.isBlocked(any())).thenReturn(false);
    when(
      () => reactionsRepo.watchForConversation(any()),
    ).thenAnswer((_) => reactionStream.stream);
    when(
      () => reactionsRepo.hasOutstandingOwnDeletion(
        targetMessageId: any(named: 'targetMessageId'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => reactionsRepo.publish(
        conversationId: any(named: 'conversationId'),
        targetMessageId: any(named: 'targetMessageId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer(
      (_) async => const DmReactionPublishResult(success: true, rumorId: 'r'),
    );
  });

  tearDown(() => reactionStream.close());

  Widget wrap(DmReplyContext ctx) => ProviderScope(
    overrides: [
      dmRepositoryProvider.overrideWithValue(dmRepo),
      dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
      authServiceProvider.overrideWithValue(auth),
      contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          // Disable animations to exercise the reduced-motion path (the
          // player reaction overlay is suppressed) — these tests have no
          // ReelReplyBridge, so a reaction never triggers an overlay anyway.
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: ReelDmReplyBarHost(dmReplyContext: ctx),
            ),
          ),
        ),
      ),
    ),
  );

  /// The bar under a switch, so a test can take it out of the tree the way
  /// scrolling to the next reel does.
  Widget toggleableBarApp(ValueNotifier<bool> barVisible, DmReplyContext ctx) =>
      ProviderScope(
        overrides: [
          dmRepositoryProvider.overrideWithValue(dmRepo),
          dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
          authServiceProvider.overrideWithValue(auth),
          contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (inner) => MediaQuery(
                data: MediaQuery.of(inner).copyWith(disableAnimations: true),
                child: ValueListenableBuilder<bool>(
                  valueListenable: barVisible,
                  builder: (_, visible, _) => visible
                      ? ReelDmReplyBarHost(dmReplyContext: ctx)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );

  group('renders', () {
    testWidgets('does not render for a retired moderation thread', (
      tester,
    ) async {
      final retiredContext = DmReplyContext(
        conversationId: 'retired-convo',
        participantPubkeys: [kLegacyModerationPubkeys.first],
        isGroup: false,
        sharedReelMessageId: _reelId,
        messageAuthorPubkey: kLegacyModerationPubkeys.first,
        hintName: 'Divine Moderation',
        isOwnMessage: false,
      );

      await tester.pumpWidget(wrap(retiredContext));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('❤️'), findsNothing);
    });

    testWidgets('does not render for a blocked thread', (tester) async {
      when(() => blocklist.isBlocked(_peer)).thenReturn(true);

      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('❤️'), findsNothing);
    });

    testWidgets('returns when the peer is unblocked while the player is open', (
      tester,
    ) async {
      when(() => blocklist.isBlocked(_peer)).thenReturn(true);
      await tester.pumpWidget(wrap(context()));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);

      when(() => blocklist.isBlocked(_peer)).thenReturn(false);
      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      providerContainer.read(blocklistVersionProvider.notifier).increment();
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('renders composer + the 6 quick emojis + picker button', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      for (final emoji in ReelReplyConstants.quickEmojis) {
        expect(find.text(emoji), findsOneWidget);
      }
      expect(find.byType(TextField), findsOneWidget);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.dmReactionAddCustomA11yLabel),
        findsOne,
      );
    });

    testWidgets('shows the contextual name hint for a peer reel', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(context()));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.dmReelReplyComposerHint('Alice')), findsOneWidget);
    });

    testWidgets('shows a generic hint while the peer name resolves', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(context(hintName: '')));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.dmReelReplyComposerSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows "reply to yourself" hint on own reel', (tester) async {
      await tester.pumpWidget(wrap(context(isOwn: true)));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.dmReelReplyComposerHintSelf), findsOneWidget);
    });
  });

  group('interactions', () {
    testWidgets('announces a reaction only after it persists', (tester) async {
      final announcements = captureAnnouncements(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.tap(find.text('❤️'));
      await tester.pump();

      expect(
        announcements,
        isNot(contains(l10n.dmReelReactionSentAnnouncement('❤️'))),
      );

      reactionStream.add([
        const DmReaction(
          id: 'pending-reaction',
          conversationId: 'convo-id',
          targetMessageId: _reelId,
          targetMessageAuthor: _peer,
          reactorPubkey: _owner,
          emoji: '❤️',
          createdAt: 1700000000,
          ownerPubkey: _owner,
          publishStatus: DmReactionPublishStatus.pending,
        ),
      ]);
      await tester.pump();

      expect(
        announcements,
        isNot(contains(l10n.dmReelReactionSentAnnouncement('❤️'))),
      );

      reactionStream.add([
        const DmReaction(
          id: 'persisted-reaction',
          conversationId: 'convo-id',
          targetMessageId: _reelId,
          targetMessageAuthor: _peer,
          reactorPubkey: _owner,
          emoji: '❤️',
          createdAt: 1700000000,
          ownerPubkey: _owner,
          publishStatus: DmReactionPublishStatus.sent,
        ),
      ]);
      await tester.pump();

      expect(
        announcements,
        contains(l10n.dmReelReactionSentAnnouncement('❤️')),
      );
    });

    testWidgets('announces a failed reaction without claiming success', (
      tester,
    ) async {
      when(
        () => reactionsRepo.publish(
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          emoji: any(named: 'emoji'),
        ),
      ).thenAnswer(
        (_) async => const DmReactionPublishResult(
          success: false,
          rumorId: 'failed-rumor',
        ),
      );
      final announcements = captureAnnouncements(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.tap(find.text('❤️'));
      await tester.pump();
      await tester.pump();

      expect(announcements, contains(l10n.dmReelReplyFailed));
      expect(
        announcements,
        isNot(contains(l10n.dmReelReactionSentAnnouncement('❤️'))),
      );
    });

    testWidgets('tapping a quick emoji publishes a reaction on the reel', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.tap(find.text('❤️'));
      await tester.pump();

      verify(
        () => reactionsRepo.publish(
          conversationId: 'convo-id',
          targetMessageId: _reelId,
          targetMessageAuthor: _peer,
          emoji: '❤️',
        ),
      ).called(1);
    });

    testWidgets('tapped emoji bounces softly, then settles back to rest', (
      tester,
    ) async {
      // Same host as [wrap], but without the disableAnimations override so the
      // pulse actually runs. No ReelReplyBridge is wired, so the tap still
      // never triggers a player overlay.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(dmRepo),
            dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
            authServiceProvider.overrideWithValue(auth),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ReelDmReplyBarHost(dmReplyContext: context()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final scaleFinder = find.ancestor(
        of: find.text('❤️'),
        matching: find.byType(ScaleTransition),
      );
      expect(
        tester.widget<ScaleTransition>(scaleFinder).scale.value,
        moreOrLessEquals(1),
      );

      await tester.tap(find.text('❤️'));
      await tester.pump(); // start the bounce ticker
      await tester.pump(const Duration(milliseconds: 190));
      expect(
        tester.widget<ScaleTransition>(scaleFinder).scale.value,
        greaterThan(1.1),
      );

      await tester.pump(const Duration(milliseconds: 650));
      expect(
        tester.widget<ScaleTransition>(scaleFinder).scale.value,
        moreOrLessEquals(1),
      );
    });

    testWidgets('reduced motion suppresses the tap pulse', (tester) async {
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      final scaleFinder = find.ancestor(
        of: find.text('❤️'),
        matching: find.byType(ScaleTransition),
      );

      await tester.tap(find.text('❤️'));
      await tester.pump(); // would start the ticker if one were scheduled
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester.widget<ScaleTransition>(scaleFinder).scale.value,
        moreOrLessEquals(1),
      );
    });

    testWidgets('re-tapping the active emoji is a no-op', (tester) async {
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.tap(find.text('❤️'));
      await tester.pump();
      // Second tap of the same (now-active) emoji must not publish again.
      await tester.tap(find.text('❤️'));
      await tester.pump();

      verify(
        () => reactionsRepo.publish(
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          emoji: '❤️',
        ),
      ).called(1);
    });

    testWidgets(
      'failed optimistic reaction can be retried with the same emoji',
      (
        tester,
      ) async {
        when(
          () => reactionsRepo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async => const DmReactionPublishResult(
            success: false,
            rumorId: 'failed-rumor',
          ),
        );

        await tester.pumpWidget(wrap(context()));
        await tester.pump();

        await tester.tap(find.text('❤️'));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('❤️'));
        await tester.pump(ReelReplyConstants.reactionThrottle);
        await tester.pump();

        verify(
          () => reactionsRepo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: '❤️',
          ),
        ).called(2);
      },
    );

    testWidgets('submit while send is in flight preserves the draft', (
      tester,
    ) async {
      final pendingSend = Completer<NIP17SendResult>();
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer((_) => pendingSend.future);

      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'first reply');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'second reply');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(find.text('second reply'), findsOneWidget);
      verify(
        () => dmRepo.sendMessage(
          recipientPubkey: _peer,
          content: 'first reply',
          replyToId: _reelId,
        ),
      ).called(1);
      verifyNever(
        () => dmRepo.sendMessage(
          recipientPubkey: _peer,
          content: 'second reply',
          replyToId: _reelId,
        ),
      );

      pendingSend.complete(
        NIP17SendResult.success(
          rumorEventId: 'r',
          messageEventId: 'g',
          recipientPubkey: _peer,
        ),
      );
    });

    testWidgets('rapid different-emoji taps throttle to one immediate + one '
        'coalesced publish', (tester) async {
      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.tap(find.text('❤️')); // leading edge: publishes immediately
      await tester.pump();
      await tester.tap(find.text('😂')); // within window: coalesced
      await tester.pump();

      // Only the leading ❤️ has published so far.
      verify(
        () => reactionsRepo.publish(
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          emoji: '❤️',
        ),
      ).called(1);

      // Advance past the throttle window; the coalesced 😂 publishes.
      await tester.pump(ReelReplyConstants.reactionThrottle);
      await tester.pump();
      verify(
        () => reactionsRepo.publish(
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          emoji: '😂',
        ),
      ).called(1);
    });

    testWidgets('tapping an emoji triggers the player reaction overlay', (
      tester,
    ) async {
      String? reacted;
      // Animations enabled (no disableAnimations MediaQuery) + a ReelReplyBridge
      // so the bar forwards the reaction to the player overlay.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(dmRepo),
            dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
            authServiceProvider.overrideWithValue(auth),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ReelReplyBridge(
                  setComposerFocused: (_) {},
                  playReaction: (emoji) => reacted = emoji,
                  child: ReelDmReplyBarHost(dmReplyContext: context()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('❤️'));
      await tester.pump();

      expect(reacted, '❤️');
    });

    testWidgets('reduced motion suppresses the player reaction overlay', (
      tester,
    ) async {
      String? reacted;
      final dmContext = context();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(dmRepo),
            dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
            authServiceProvider.overrideWithValue(auth),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ReelReplyBridge(
                      setComposerFocused: (_) {},
                      playReaction: (emoji) => reacted = emoji,
                      child: ReelDmReplyBarHost(dmReplyContext: dmContext),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('❤️'));
      await tester.pump();

      verify(
        () => reactionsRepo.publish(
          conversationId: 'convo-id',
          targetMessageId: _reelId,
          targetMessageAuthor: _peer,
          emoji: '❤️',
        ),
      ).called(1);
      expect(reacted, isNull);
    });

    testWidgets('retry action closes when the bar leaves the tree', (
      tester,
    ) async {
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenThrow(Exception('send failed'));

      final barVisible = ValueNotifier(true);
      addTearDown(barVisible.dispose);

      await tester.pumpWidget(toggleableBarApp(barVisible, context()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.dmSendFailedRetry), findsOneWidget);

      barVisible.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text(l10n.dmSendFailedRetry), findsNothing);

      expect(tester.takeException(), isNull);
      verify(
        () => dmRepo.sendMessage(
          recipientPubkey: _peer,
          content: 'hello',
          replyToId: _reelId,
        ),
      ).called(1);
    });

    testWidgets('oversized reply restores the draft without a retry action', (
      tester,
    ) async {
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.tooLong('reply is too large'),
      );

      await tester.pumpWidget(wrap(context()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'keep this draft');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.dmSendTooLongMessage), findsOneWidget);
      expect(find.text(l10n.dmSendFailedRetry), findsNothing);
      expect(find.text('keep this draft'), findsOneWidget);
    });

    // #7316. The retry action must re-drive the row the failed send parked. A
    // second `sendMessage` would mint a fresh rumor for the same text, and since
    // the receiver's only stable dedup key is the rumor id — gift-wrap ids are
    // randomised per wrap — it would render as a second message alongside the
    // sweep's replay of the original.
    testWidgets('tapping Retry re-drives the parked row, never re-sends', (
      tester,
    ) async {
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure(
          'no relay responded',
          queuedRumorId: 'parked-row',
        ),
      );
      when(
        () => dmRepo.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'parked-row',
          messageEventId: 'g',
          recipientPubkey: _peer,
        ),
      );

      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      // Target the action, not its label: the label's own offset is inside the
      // snackbar's slide transform and a tap there can miss the button.
      await tester.tap(
        find.widgetWithText(SnackBarAction, l10n.dmSendFailedRetry),
      );
      await tester.pumpAndSettle();

      verify(
        () => dmRepo.recoverFullSend(
          rumorId: 'parked-row',
          resetRetryBudget: true,
        ),
      ).called(1);
      // The original send, and only it.
      verify(
        () => dmRepo.sendMessage(
          recipientPubkey: _peer,
          content: 'hello',
          replyToId: _reelId,
        ),
      ).called(1);
    });

    testWidgets('a retry whose row is gone reports unverified, not sent', (
      tester,
    ) async {
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure(
          'no relay responded',
          queuedRumorId: 'parked-row',
        ),
      );
      // The row is gone: possibly delivered by the sweep, possibly cancelled,
      // possibly another account's. Delivery cannot be proven either way.
      when(
        () => dmRepo.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenThrow(
        ArgumentError.value('parked-row', 'rumorId', 'no queued row'),
      );

      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.widgetWithText(SnackBarAction, l10n.dmSendFailedRetry),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.dmReelReplyUnverified), findsOneWidget);
      // Claiming "Sent" would assert a delivery nothing confirmed.
      expect(find.text(l10n.shareSent), findsNothing);
      // And no second Retry: there is no row left to re-drive, so tapping one
      // would fall through to a fresh send — the duplicate #7316 closed. The
      // send count pins that nothing re-sent behind the snackbar's back.
      expect(
        find.widgetWithText(SnackBarAction, l10n.dmSendFailedRetry),
        findsNothing,
      );
      // (The "View chat" affordance this outcome offers instead needs a router
      // in the tree; `wrap` has none, so the shared snackbar builder drops the
      // action here. The success path covers that branch.)
      verify(
        () => dmRepo.sendMessage(
          recipientPubkey: _peer,
          content: 'hello',
          replyToId: _reelId,
        ),
      ).called(1);
    });

    testWidgets('a retry snackbar outliving its send still re-drives its row', (
      tester,
    ) async {
      // The retry snackbar queues behind another, so the later success cannot
      // dismiss it (`close()` only works on the visible one). When it finally
      // surfaces and is tapped, the cubit's live `queuedRumorIds` has been
      // cleared by that success — so a retry reading state instead of its own
      // captured ids would fall through to a fresh send and duplicate a row the
      // sweep is still re-driving.
      var sends = 0;
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer((_) async {
        sends++;
        if (sends == 1) {
          return const NIP17SendResult.failure(
            'no relay responded',
            queuedRumorId: 'parked-row',
          );
        }
        return NIP17SendResult.success(
          rumorEventId: 'r$sends',
          messageEventId: 'm$sends',
          recipientPubkey: _peer,
        );
      });
      when(
        () => dmRepo.recoverFullSend(
          rumorId: any(named: 'rumorId'),
          resetRetryBudget: any(named: 'resetRetryBudget'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'parked-row',
          messageEventId: 'g',
          recipientPubkey: _peer,
        ),
      );

      await tester.pumpWidget(wrap(context()));
      await tester.pump();

      final messenger = tester.state<ScaffoldMessengerState>(
        find.byType(ScaffoldMessenger).first,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('unrelated'),
          duration: Duration(seconds: 30),
        ),
      );
      await tester.pumpAndSettle();

      // First send fails; its retry snackbar queues behind 'unrelated'.
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Second send succeeds, clearing the live handle for the first one's row.
      await tester.enterText(find.byType(TextField), 'world');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.widgetWithText(SnackBarAction, l10n.dmSendFailedRetry),
      );
      await tester.pumpAndSettle();

      verify(
        () => dmRepo.recoverFullSend(
          rumorId: 'parked-row',
          resetRetryBudget: true,
        ),
      ).called(1);
      // Two deliberate sends, no third: the stale tap re-drove, never re-sent.
      expect(sends, 2);
    });

    testWidgets('leaves a queued retry snackbar for whatever is on screen', (
      tester,
    ) async {
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenThrow(Exception('send failed'));

      final barVisible = ValueNotifier(true);
      addTearDown(barVisible.dispose);

      await tester.pumpWidget(toggleableBarApp(barVisible, context()));
      await tester.pump();

      // Something else on the reel route got to the messenger first, so the
      // retry snackbar queues behind it instead of showing.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .showSnackBar(
            const SnackBar(
              content: Text('unrelated'),
              duration: Duration(seconds: 30),
            ),
          );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      barVisible.value = false;
      await tester.pumpAndSettle();

      // Closing a queued snackbar would have dismissed this one instead.
      expect(tester.takeException(), isNull);
      expect(find.text('unrelated'), findsOneWidget);
    });

    testWidgets('closes the retry snackbar when navigation is accessible', (
      tester,
    ) async {
      // The messenger skips the exit animation in this mode and rebuilds
      // synchronously, which the framework rejects while it is unmounting the
      // bar unless the close is deferred past the state lock.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenThrow(Exception('send failed'));

      final barVisible = ValueNotifier(true);
      addTearDown(barVisible.dispose);

      await tester.pumpWidget(toggleableBarApp(barVisible, context()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.dmSendFailedRetry), findsOneWidget);

      barVisible.value = false;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.dmSendFailedRetry), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('view chat action navigates after the bar leaves the tree', (
      tester,
    ) async {
      when(
        () => dmRepo.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-id',
          messageEventId: 'message-id',
          recipientPubkey: _peer,
        ),
      );

      final barVisible = ValueNotifier(true);
      addTearDown(barVisible.dispose);
      final dmContext = context();

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Builder(
                builder: (inner) => MediaQuery(
                  data: MediaQuery.of(inner).copyWith(disableAnimations: true),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: barVisible,
                    builder: (_, visible, _) => visible
                        ? ReelDmReplyBarHost(dmReplyContext: dmContext)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: ConversationPage.pathPattern,
            builder: (_, state) => Scaffold(
              body: Text('conversation ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(dmRepo),
            dmReactionsRepositoryProvider.overrideWithValue(reactionsRepo),
            authServiceProvider.overrideWithValue(auth),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.dmReelReplyViewChat), findsOneWidget);

      barVisible.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text(l10n.dmReelReplyViewChat), findsOneWidget);

      await tester.tap(find.text(l10n.dmReelReplyViewChat));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('conversation convo-id'), findsOneWidget);
    });
  });
}
