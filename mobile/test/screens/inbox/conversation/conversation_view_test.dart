// ABOUTME: Widget tests for ConversationView.
// ABOUTME: Verifies loading, error, empty, and loaded message states,
// ABOUTME: plus the app bar and input bar rendering.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
// `ProfileStats` here is the domain model from `models`, not the Drift
// table class of the same name — the repository hides it the same way.
import 'package:db_client/db_client.dart' hide ProfileStats;
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart' show DmRepository;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/blocs/dm/restore_status/dm_restore_status_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/watermark_download_provider.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:videos_repository/videos_repository.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../builders/video_event_builder.dart';
import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockConversationBloc
    extends MockBloc<ConversationEvent, ConversationState>
    implements ConversationBloc {}

class _MockCollaboratorInviteActionsCubit
    extends MockCubit<CollaboratorInviteActionsState>
    implements CollaboratorInviteActionsCubit {}

class _MockConversationReactionsCubit
    extends MockBloc<ConversationReactionsEvent, ConversationReactionsState>
    implements ConversationReactionsCubit {}

class _MockDmRestoreStatusCubit extends MockCubit<DmRestoreStatusState>
    implements DmRestoreStatusCubit {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockWatermarkDownloadService extends Mock
    implements WatermarkDownloadService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey);
  final String _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;
}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const fallbackInvite = CollaboratorInvite(
    messageId:
        '9999999999999999999999999999999999999999999999999999999999999999',
    videoAddress:
        '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
    videoKind: 34236,
    creatorPubkey: otherPubkey,
    videoDTag: 'skate-loop',
    role: 'Collaborator',
  );

  final now = DateTime.now();
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ConversationView, () {
    late _MockConversationBloc mockBloc;
    late _MockCollaboratorInviteActionsCubit mockInviteActionsCubit;
    late _MockConversationReactionsCubit mockReactionsCubit;
    late _MockDmRestoreStatusCubit mockRestoreStatusCubit;
    late _MockVideosRepository mockVideosRepository;
    late _MockWatermarkDownloadService mockWatermarkDownloadService;
    late MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late _MockContentBlocklistRepository mockBlocklist;

    setUpAll(() {
      registerFallbackValue(fallbackInvite);
      registerFallbackValue(<CollaboratorInvite>[]);
      registerFallbackValue(<String>[]);
      registerFallbackValue(
        const ConversationMessageSent(
          recipientPubkeys: [otherPubkey],
          content: '',
        ),
      );
      registerFallbackValue(
        const ConversationSelfWrapRecoveryRequested(rumorIds: <String>[]),
      );
      registerFallbackValue(
        const ConversationReactionSet(
          conversationId: '',
          messageId: '',
          messageAuthorPubkey: '',
          emoji: '',
        ),
      );
      registerFallbackValue(VideoEventBuilder().build());
    });

    setUp(() {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      mockBloc = _MockConversationBloc();
      // The snackbar action callbacks guard on `bloc.isClosed` (the snackbar
      // can outlive the route); MockBloc leaves the getter unstubbed.
      when(() => mockBloc.isClosed).thenReturn(false);
      mockInviteActionsCubit = _MockCollaboratorInviteActionsCubit();
      mockReactionsCubit = _MockConversationReactionsCubit();
      mockRestoreStatusCubit = _MockDmRestoreStatusCubit();
      // Default: recovery finished, so the empty state stays unqualified.
      whenListen(
        mockRestoreStatusCubit,
        const Stream<DmRestoreStatusState>.empty(),
        initialState: const DmRestoreStatusState(),
      );
      mockVideosRepository = _MockVideosRepository();
      mockWatermarkDownloadService = _MockWatermarkDownloadService();
      mockNostrClient = createMockNostrService();
      mockAuthService = _MockAuthService(currentPubkey);
      mockBlocklist = _MockContentBlocklistRepository();
      // Default: nobody blocked. Reaction-filtering tests re-stub this.
      when(
        () => mockBlocklist.dmHiddenPubkeys,
      ).thenReturn(const <String>{});
      when(() => mockBlocklist.isBlocked(any())).thenReturn(false);

      whenListen(
        mockReactionsCubit,
        Stream<ConversationReactionsState>.value(
          const ConversationReactionsState(),
        ),
        initialState: const ConversationReactionsState(),
      );

      when(() => mockInviteActionsCubit.state).thenReturn(
        const CollaboratorInviteActionsState(),
      );
      when(
        () => mockInviteActionsCubit.acceptInvite(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockInviteActionsCubit.ignoreInvite(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockVideosRepository.fetchVideoWithStatsForRouteId(
          any(),
          fallbackRouteIds: any(named: 'fallbackRouteIds'),
        ),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject({
      ConversationState? state,
      UserProfile? otherProfile,
      ProfileStats? otherStats,
      bool otherProfileVanished = false,
      MockGoRouter? goRouter,
      DmRestoreStatusState? restoreStatus,
      String counterparty = otherPubkey,
      List<String>? counterparties,
      ConversationState? previousState,
      Future<UserProfile?>? otherProfileFuture,
      Future<bool>? otherProfileVanishedFuture,
      bool isIdentityResolving = false,
      Stream<ConversationState>? stateStream,
    }) {
      final effectiveState = state ?? const ConversationState();
      if (restoreStatus != null) {
        whenListen(
          mockRestoreStatusCubit,
          Stream<DmRestoreStatusState>.value(restoreStatus),
          initialState: restoreStatus,
        );
      }
      // `previousState` seeds a different initial state so the emission below
      // is a real transition. The view's send-outcome listener is gated on
      // `previous.sendStatus != current.sendStatus`, so a state emitted as both
      // initial and stream value never reaches it.
      whenListen(
        mockBloc,
        stateStream ?? Stream<ConversationState>.value(effectiveState),
        initialState: previousState ?? effectiveState,
      );

      final app = testMaterialApp(
        mockAuthService: mockAuthService,
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          watermarkDownloadServiceProvider.overrideWithValue(
            mockWatermarkDownloadService,
          ),
          profileRepositoryProvider.overrideWithValue(null),
          profileReadRepositoryProvider.overrideWithValue(null),
          fetchUserProfileProvider(
            counterparty,
          ).overrideWith(
            (ref) => otherProfileFuture ?? Future.value(otherProfile),
          ),
          userProfileStatsReactiveProvider(
            counterparty,
          ).overrideWith((ref) => Stream.value(otherStats)),
          profileVanishedProvider(
            counterparty,
          ).overrideWith((ref) => otherProfileVanished),
          profileVanishedSnapshotProvider(
            counterparty,
          ).overrideWith(
            (ref) =>
                otherProfileVanishedFuture ??
                Future.value(otherProfileVanished),
          ),
          profileIdentityResolvingProvider(
            counterparty,
          ).overrideWithValue(isIdentityResolving),
          // The view now reads the blocklist eagerly in build() to filter
          // reaction reactors, so every pump needs a stubbed repository.
          contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
          nip05VerificationProvider.overrideWith(
            (ref, pubkey) async => Nip05VerificationStatus.none,
          ),
          followRelationshipProvider.overrideWith(
            (ref, pubkey) => Stream.value(FollowRelationship.mutual),
          ),
        ],
        home: BlocProvider<ConversationBloc>.value(
          value: mockBloc,
          child: BlocProvider<CollaboratorInviteActionsCubit>.value(
            value: mockInviteActionsCubit,
            child: BlocProvider<ConversationReactionsCubit>.value(
              value: mockReactionsCubit,
              child: BlocProvider<DmRestoreStatusCubit>.value(
                value: mockRestoreStatusCubit,
                child: ConversationView(
                  participantPubkeys: counterparties ?? [counterparty],
                ),
              ),
            ),
          ),
        ),
      );
      return goRouter == null
          ? app
          : MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    // Same rule as the inbox action sheet, one screen in: Report and Block
    // take one account, and on a group `otherPubkey` is whichever counterparty
    // sorted first — so the sheet would name the thread and act on a stranger.
    group('options sheet on a group thread', () {
      const secondPeer =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

      Future<void> openOptions(
        WidgetTester tester, {
        required List<String> counterparties,
      }) async {
        await tester.pumpWidget(
          buildSubject(
            counterparties: counterparties,
            state: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          ),
        );
        await tester.pump();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.inboxConversationOptionsLabel),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('offers no Report or Block', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await openOptions(
          tester,
          counterparties: const [otherPubkey, secondPeer],
        );

        expect(find.text(l10n.profileCopyPublicKey), findsNothing);
        expect(
          find.textContaining(l10n.profileBlockDisplayName('')),
          findsNothing,
        );
        expect(
          find.textContaining(l10n.profileReportDisplayName('')),
          findsNothing,
        );
      });

      testWidgets('a 1:1 thread still offers both', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await openOptions(tester, counterparties: const [otherPubkey]);

        expect(
          find.textContaining(l10n.profileBlockDisplayName('')),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.profileReportDisplayName('')),
          findsOneWidget,
        );
      });
    });

    group('double-tap to like', () {
      DmMessage reactableMessage({required bool sent}) => DmMessage(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        conversationId:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        senderPubkey: sent ? currentPubkey : otherPubkey,
        content: 'React to me',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        giftWrapId:
            'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
      );

      // WidgetTester has no built-in double tap: synthesize two taps at the
      // same point with a gap inside the double-tap window (> 40 ms min,
      // < 300 ms timeout). pumpAndSettle only AFTER the second tap so the
      // gap doesn't overrun the window and register as two single taps.
      Future<void> doubleTapBubble(WidgetTester tester) async {
        final center = tester.getCenter(find.text('React to me'));
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
      }

      List<ConversationReactionSet> capturedReactionSets() => verify(
        () => mockReactionsCubit.add(captureAny()),
      ).captured.whereType<ConversationReactionSet>().toList();

      testWidgets('received bubble adds a ❤️ reaction to the message', (
        tester,
      ) async {
        final message = reactableMessage(sent: false);
        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        await doubleTapBubble(tester);

        final sets = capturedReactionSets();
        expect(sets, hasLength(1));
        expect(sets.single.emoji, kDefaultDmReactionEmojis.first);
        expect(sets.single.messageId, message.id);
        expect(sets.single.messageAuthorPubkey, otherPubkey);
      });

      testWidgets('own delivered bubble also adds a ❤️ reaction', (
        tester,
      ) async {
        final message = reactableMessage(sent: true);
        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        await doubleTapBubble(tester);

        final sets = capturedReactionSets();
        expect(sets, hasLength(1));
        expect(sets.single.emoji, kDefaultDmReactionEmojis.first);
      });

      testWidgets('failed own send does not dispatch a reaction', (
        tester,
      ) async {
        final failedRow = OutgoingDm(
          id: 'rumor-failed-id',
          conversationId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          recipientPubkey: otherPubkey,
          content: 'React to me',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          rumorEventJson: '{}',
          recipientWrapStatus: OutgoingWrapStatus.failed,
          selfWrapStatus: OutgoingWrapStatus.failed,
          queuedAt: now,
          ownerPubkey: currentPubkey,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              pendingOutgoing: [failedRow],
            ),
          ),
        );
        await tester.pump();

        await doubleTapBubble(tester);

        verifyNever(() => mockReactionsCubit.add(any()));
      });

      testWidgets('retired moderation thread disables double-tap reactions', (
        tester,
      ) async {
        final retired = kLegacyModerationPubkeys.first;
        final message = DmMessage(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          conversationId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          senderPubkey: retired,
          content: 'React to me',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );

        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        await doubleTapBubble(tester);

        verifyNever(() => mockReactionsCubit.add(any()));
      });

      testWidgets('retired moderation long-press keeps actions but hides '
          'reaction choices', (tester) async {
        final retired = kLegacyModerationPubkeys.first;
        final message = DmMessage(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          conversationId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          senderPubkey: retired,
          content: 'React to me',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );

        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.text('React to me'));
        await tester.pumpAndSettle();

        expect(find.text(kDefaultDmReactionEmojis.first), findsNothing);
        expect(find.text(l10n.dmMessageActionCopyText), findsOneWidget);
      });
    });

    // #6416. The header resolved the peer from kind-0 only, and neither
    // moderation key has one the app can read — the current account's is not on
    // the single relay production queries, and a retired key has no events at
    // all — so an enforcement thread was titled "Adjective Animal N".
    group('moderation identity', () {
      testWidgets('titles a retired moderation thread as Divine', (
        tester,
      ) async {
        final retired = kLegacyModerationPubkeys.first;

        await tester.pumpWidget(buildSubject(counterparty: retired));
        await tester.pump();

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(retired)),
          findsNothing,
        );
      });

      testWidgets('leaves an ordinary thread on its generated name', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsOneWidget,
        );
        expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
      });
    });

    // #7025. Reachable from the inbox's Blocked chip so a user asked for
    // screenshots of abusive DMs can produce them without unblocking — which
    // would re-expose them to the person they blocked. Readable, not writable.
    group('blocked thread', () {
      testWidgets('replaces the composer with the blocked notice', (
        tester,
      ) async {
        when(() => mockBlocklist.isBlocked(otherPubkey)).thenReturn(true);

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(MessageInputBar), findsNothing);
        expect(find.text(l10n.dmBlockedThreadTitle), findsOneWidget);
        expect(find.text(l10n.dmBlockedThreadBody), findsOneWidget);
      });

      testWidgets('keeps the history on screen', (tester) async {
        when(() => mockBlocklist.isBlocked(otherPubkey)).thenReturn(true);

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [
                DmMessage(
                  id:
                      'dddddddddddddddddddddddddddddddd'
                      'ddddddddddddddddddddddddddddddddd',
                  conversationId:
                      'cccccccccccccccccccccccccccccccc'
                      'cccccccccccccccccccccccccccccccc',
                  senderPubkey: otherPubkey,
                  content: 'the abusive message',
                  createdAt: now.millisecondsSinceEpoch ~/ 1000,
                  giftWrapId:
                      'aaaaaaaabbbbbbbbccccccccdddddddd'
                      'aaaaaaaabbbbbbbbccccccccdddddddd',
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        // The whole point: removing the composer must not remove the evidence.
        expect(find.text('the abusive message'), findsOneWidget);
      });

      testWidgets('an unblocked counterparty keeps its composer', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(MessageInputBar), findsOneWidget);
        expect(find.text(l10n.dmBlockedThreadTitle), findsNothing);
      });

      // Removing the composer is not the whole of "read-only": a send that
      // hard-failed before the block is still on screen as a red bubble, and
      // its tap opens the recovery sheet whose primary action republishes the
      // rumor — a DM delivered to the account the viewer blocked, from the one
      // screen built to make that impossible.
      testWidgets('a failed own bubble cannot be resent', (tester) async {
        when(() => mockBlocklist.isBlocked(otherPubkey)).thenReturn(true);

        const content = 'a message that never got through';
        final failedRow = OutgoingDm(
          id: 'rumor-failed-id',
          conversationId:
              'cccccccccccccccccccccccccccccccc'
              'cccccccccccccccccccccccccccccccc',
          recipientPubkey: otherPubkey,
          content: content,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          rumorEventJson: '{}',
          recipientWrapStatus: OutgoingWrapStatus.failed,
          selfWrapStatus: OutgoingWrapStatus.failed,
          queuedAt: DateTime(2026),
          ownerPubkey: currentPubkey,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              pendingOutgoing: [failedRow],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The bubble stays: it is the viewer's own record of the exchange.
        expect(find.text(content), findsOneWidget);

        await tester.tap(find.text(content));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.dmMessageActionRetrySend),
          findsNothing,
          reason: 'the recovery sheet must not open in a blocked thread',
        );
        verifyNever(
          () => mockBloc.add(
            any(that: isA<ConversationFullSendRecoveryRequested>()),
          ),
        );
      });

      testWidgets(
        'a retained blocked bubble is visible, non-retryable, and locally '
        'deletable',
        (tester) async {
          final retired = kLegacyModerationPubkeys.first;
          const ownConversationId =
              '3434343434343434343434343434343434343434343434343434343434343434';
          const content = 'my retained appeal';
          final blockedRow = OutgoingDm(
            id: 'rumor-blocked-retired',
            conversationId: ownConversationId,
            recipientPubkey: retired,
            content: content,
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
            rumorEventJson: '{}',
            recipientWrapStatus: OutgoingWrapStatus.blocked,
            selfWrapStatus: OutgoingWrapStatus.blocked,
            queuedAt: DateTime(2026),
            ownerPubkey: currentPubkey,
          );

          await tester.pumpWidget(
            buildSubject(
              counterparty: retired,
              state: ConversationState(
                status: ConversationStatus.loaded,
                pendingOutgoing: [blockedRow],
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(content), findsOneWidget);
          expect(find.text(l10n.dmSendBlockedRetiredMessage), findsOneWidget);

          await tester.tap(find.text(content));
          await tester.pumpAndSettle();
          expect(find.text(l10n.dmMessageActionRetrySend), findsNothing);

          await tester.longPress(find.text(content));
          await tester.pumpAndSettle();
          expect(find.text(l10n.dmMessageActionCancelSend), findsOneWidget);
          expect(
            find.text(l10n.dmMessageActionDeleteForEveryone),
            findsNothing,
          );

          await tester.tap(find.text(l10n.dmMessageActionCancelSend));
          await tester.pumpAndSettle();
          verify(
            () => mockBloc.add(
              const ConversationMessageDeleted(
                rumorId: 'rumor-blocked-retired',
              ),
            ),
          ).called(1);
          verifyNever(
            () => mockBloc.add(
              any(that: isA<ConversationFullSendRecoveryRequested>()),
            ),
          );
        },
      );
    });

    // #6416. Nothing has read a retired moderation key since the rotation, so
    // an appeal typed here published, turned the bubble green, and reached
    // nobody. Replace the composer rather than disable it: `MessageInputBar`
    // has no disabled state, and a greyed-out field still reads as usable.
    group('retired moderation thread', () {
      final retired = kLegacyModerationPubkeys.first;

      testWidgets('replaces the composer with the closed-thread notice', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(counterparty: retired));
        await tester.pump();

        expect(find.byType(MessageInputBar), findsNothing);
        expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
        expect(find.text(l10n.dmRetiredThreadClosedBody), findsOneWidget);
        expect(find.text(l10n.dmRetiredThreadOpenSupport), findsOneWidget);
      });

      testWidgets('keeps the thread history readable', (tester) async {
        await tester.pumpWidget(buildSubject(counterparty: retired));
        await tester.pump();

        // Closing the composer must not hide the enforcement notice itself —
        // for an affected user this is their only record of the action.
        expect(find.byType(ConversationAppBar), findsOneWidget);
      });

      testWidgets('routes to the current moderation thread, replacing this '
          'route so back does not return to the dead one', (tester) async {
        final goRouter = MockGoRouter();
        when(
          () => goRouter.pushReplacement<Object?>(
            any(),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          buildSubject(counterparty: retired, goRouter: goRouter),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.dmRetiredThreadOpenSupport));
        await tester.pump();

        verify(
          () => goRouter.pushReplacement<Object?>(
            ConversationPage.pathForId(
              DmRepository.computeConversationId([
                currentPubkey,
                kModerationPubkeyHex,
              ]),
            ),
            extra: const [kModerationPubkeyHex],
          ),
        ).called(1);
      });

      // The composer is gone here, so this button is the ONLY control on the
      // screen and the only route back to a moderation account that reads.
      // `DivineButton` wires `Semantics(button: true)` only when it is given a
      // `semanticLabel`; without one it inherits the InkWell's tap action but
      // no button flag, so VoiceOver reads it as a third line of prose after
      // the title and body and never announces that it can be activated.
      testWidgets('announces the escape route as a button', (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(buildSubject(counterparty: retired));
        await tester.pump();

        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.dmRetiredThreadOpenSupport),
        );

        expect(
          node.getSemanticsData().flagsCollection.isButton,
          isTrue,
          reason:
              "the closed thread's only escape route must announce itself "
              'as a button, not as static text',
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );

        handle.dispose();
      });

      testWidgets('a live thread keeps its composer', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(MessageInputBar), findsOneWidget);
        expect(find.text(l10n.dmRetiredThreadClosedTitle), findsNothing);
      });

      testWidgets('the current moderation key keeps its composer', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(counterparty: kModerationPubkeyHex),
        );
        await tester.pump();

        expect(find.byType(MessageInputBar), findsOneWidget);
      });

      testWidgets('a blocked send explains the retired recipient', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            previousState: const ConversationState(),
            state: const ConversationState(sendStatus: SendStatus.blocked),
          ),
        );
        await tester.pump();

        // The protected-minor copy would be wrong here: a retired moderation
        // key IS an official Divine account, just one nobody reads.
        expect(find.text(l10n.dmSendBlockedRetiredMessage), findsOneWidget);
        expect(find.text(l10n.dmSendBlockedMessage), findsNothing);
      });

      // Closing the composer is not the whole of "closed". Every retraction
      // below publishes a kind-5 through the same send path, so `DmSendPolicy`
      // refuses it for a retired recipient — but each one drops the local row
      // first. The viewer sees the thing disappear; the copy the recipient
      // received before the rotation stays exactly where it was.
      const ownMessageId =
          '1212121212121212121212121212121212121212121212121212121212121212';
      const ownConversationId =
          '3434343434343434343434343434343434343434343434343434343434343434';

      DmMessage ownMessage() => DmMessage(
        id: ownMessageId,
        conversationId: ownConversationId,
        senderPubkey: currentPubkey,
        content: 'something I sent before the rotation',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        giftWrapId:
            'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
      );

      const ownReactionEmoji = '\u{2764}\u{FE0F}';

      /// Stubs the reactions cubit with one own reaction on [ownMessageId].
      /// Every case below differs only in the publish status under test, so
      /// the fixture is shared and the status is the argument.
      void primeOwnReaction({
        required String id,
        required DmReactionPublishStatus publishStatus,
      }) {
        final reaction = DmReaction(
          id: id,
          conversationId: ownConversationId,
          targetMessageId: ownMessageId,
          targetMessageAuthor: currentPubkey,
          reactorPubkey: currentPubkey,
          emoji: ownReactionEmoji,
          createdAt: 1700000000,
          ownerPubkey: currentPubkey,
          publishStatus: publishStatus,
        );
        final reactionsState = ConversationReactionsState(
          status: ConversationReactionsStatus.loaded,
          reactionsByMessageId: {
            ownMessageId: [reaction],
          },
        );
        whenListen(
          mockReactionsCubit,
          Stream<ConversationReactionsState>.value(reactionsState),
          initialState: reactionsState,
        );
      }

      testWidgets('an own bubble offers no delete-for-everyone', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.text(ownMessage().content));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.dmMessageActionDeleteForEveryone),
          findsNothing,
          reason:
              'the kind-5 is refused by the send policy, so the tile would '
              'only drop the local copy of a message the recipient still has',
        );
        // The read affordances stay: a closed thread is an archive.
        expect(find.text(l10n.dmMessageActionCopyText), findsOneWidget);
      });

      testWidgets('a live thread still offers delete-for-everyone', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.text(ownMessage().content));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.dmMessageActionDeleteForEveryone),
          findsOneWidget,
        );
      });

      testWidgets('an own reaction cannot be retracted from the '
          'who-reacted sheet', (tester) async {
        primeOwnReaction(
          id: 'r-own-retired',
          publishStatus: DmReactionPublishStatus.received,
        );

        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text(ownReactionEmoji));
        // Avoid pumpAndSettle: the view's async profile providers can schedule
        // continuous micro-tasks. Pump the bottom-sheet enter animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The sheet still opens — reading who reacted is not a write.
        expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
        expect(
          find.text(l10n.dmReactionRemoveAction),
          findsNothing,
          reason: 'the retraction is refused by the send policy',
        );

        // The sheet header is not the row. Tap the reactor ListTile so
        // this fails if onTap is still wired.
        expect(find.byType(ListTile), findsOneWidget);
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        verifyNever(() => mockReactionsCubit.add(any()));
      });

      testWidgets('a failed own reaction announces no retry action on a '
          'closed thread', (tester) async {
        primeOwnReaction(
          id: 'r-own-retired-failed',
          publishStatus: DmReactionPublishStatus.failed,
        );

        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text(ownReactionEmoji));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The sheet rendered the own reaction row (so the retry-label check
        // below is not trivially satisfied by an absent row)...
        expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
        // ...but the trailing collapses to a bare emoji, so the row must not
        // tell a screen reader to "double tap to retry" a retraction it cannot
        // make. The label falls back to the plain descriptive own-reaction one.
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(l10n.dmReactionChipFailedA11yLabel)),
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape('Your reaction'))),
          findsWidgets,
        );
        handle.dispose();
      });

      // #8622 introduced `removalRefused` after the `failed` case above was
      // written. Both statuses reach the trailing through the same
      // `canRetract` gate, and the action this one offers publishes a kind-5
      // the send policy refuses for a retired recipient — so it needs its own
      // case rather than inheriting the `failed` one's coverage.
      testWidgets('a refused removal offers no retry on a closed thread', (
        tester,
      ) async {
        primeOwnReaction(
          id: 'r-own-retired-removal-refused',
          publishStatus: DmReactionPublishStatus.removalRefused,
        );

        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text(ownReactionEmoji));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The sheet rendered the own reaction row, so the absences below are
        // not trivially satisfied by a missing row.
        expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
        expect(find.text(l10n.dmReactionRetryAction), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(
                l10n.dmReactionRemovalRefusedA11yLabel(ownReactionEmoji),
              ),
            ),
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(l10n.dmReactionChipOwnA11yLabel(ownReactionEmoji)),
            ),
          ),
          findsWidgets,
        );

        // `showAction` and `onTap` are separate expressions sharing only
        // `canRetract`, so the trailing's absence does not prove the row is
        // inert. Tap it. The refused-removal arm opens a confirm prompt and
        // only publishes the kind-5 once it is accepted, so the prompt — not
        // the dispatch — is what a still-wired onTap surfaces here.
        expect(find.byType(ListTile), findsOneWidget);
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(l10n.dmReactionRemovalRefusedTitle), findsNothing);
        verifyNever(() => mockReactionsCubit.add(any()));
        handle.dispose();
      });

      testWidgets('a live thread still offers to retry a refused removal', (
        tester,
      ) async {
        primeOwnReaction(
          id: 'r-own-live-removal-refused',
          publishStatus: DmReactionPublishStatus.removalRefused,
        );

        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text(ownReactionEmoji));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.dmReactionRetryAction), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(
                l10n.dmReactionRemovalRefusedA11yLabel(ownReactionEmoji),
              ),
            ),
          ),
          findsWidgets,
        );
        handle.dispose();
      });

      testWidgets('a refused reaction removal retry shows failure feedback', (
        tester,
      ) async {
        final controller =
            StreamController<ConversationReactionsState>.broadcast();
        addTearDown(controller.close);
        const initial = ConversationReactionsState();
        whenListen(
          mockReactionsCubit,
          controller.stream,
          initialState: initial,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        controller.add(
          initial.copyWith(
            removalRetries: const {
              'reaction-id': ReactionRemovalRetryLocalStatus.retrying,
            },
          ),
        );
        await tester.pump();
        controller.add(
          initial.copyWith(
            removalRetries: const {
              'reaction-id': ReactionRemovalRetryLocalStatus.refused,
            },
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmReactionRemovalRefusedTitle), findsOneWidget);
      });

      testWidgets('a blocked reaction attempt shows refusal feedback', (
        tester,
      ) async {
        final controller =
            StreamController<ConversationReactionsState>.broadcast();
        addTearDown(controller.close);
        const initial = ConversationReactionsState();
        whenListen(
          mockReactionsCubit,
          controller.stream,
          initialState: initial,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        controller.add(initial.copyWith(blockedReactionAttempts: 1));
        await tester.pump();
        await tester.pump();

        expect(
          find.text(l10n.dmReactionAddBlockedByRemoval),
          findsOneWidget,
        );
      });

      for (final status in [
        ReactionRemovalRetryLocalStatus.retrying,
        ReactionRemovalRetryLocalStatus.sent,
      ]) {
        testWidgets('$status removal retry does not show failure feedback', (
          tester,
        ) async {
          final controller =
              StreamController<ConversationReactionsState>.broadcast();
          addTearDown(controller.close);
          const initial = ConversationReactionsState();
          whenListen(
            mockReactionsCubit,
            controller.stream,
            initialState: initial,
          );
          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [ownMessage()],
              ),
            ),
          );
          await tester.pump();

          controller.add(
            initial.copyWith(removalRetries: {'reaction-id': status}),
          );
          await tester.pump();
          // A SnackBar needs an animation frame to reach the tree, so a single
          // pump asserts before it would have appeared and passes either way.
          await tester.pump(const Duration(milliseconds: 500));

          expect(
            find.text(l10n.dmReactionRemovalRefusedTitle),
            findsNothing,
          );
        });
      }

      testWidgets('a live thread still offers to remove an own reaction', (
        tester,
      ) async {
        primeOwnReaction(
          id: 'r-own-live',
          publishStatus: DmReactionPublishStatus.received,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [ownMessage()],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text(ownReactionEmoji));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
        expect(find.text(l10n.dmReactionRemoveAction), findsOneWidget);
      });

      testWidgets('a failed own bubble cannot be resent', (tester) async {
        const content = 'a message that never got through';
        final failedRow = OutgoingDm(
          id: 'rumor-failed-retired',
          conversationId: ownConversationId,
          recipientPubkey: retired,
          content: content,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          rumorEventJson: '{}',
          recipientWrapStatus: OutgoingWrapStatus.failed,
          selfWrapStatus: OutgoingWrapStatus.failed,
          queuedAt: DateTime(2026),
          ownerPubkey: currentPubkey,
        );

        await tester.pumpWidget(
          buildSubject(
            counterparty: retired,
            state: ConversationState(
              status: ConversationStatus.loaded,
              pendingOutgoing: [failedRow],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The bubble stays: it is the viewer's own record of the exchange.
        expect(find.text(content), findsOneWidget);

        await tester.tap(find.text(content));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.dmMessageActionRetrySend),
          findsNothing,
          reason: 'the recovery sheet must not open in a closed thread',
        );
        verifyNever(
          () => mockBloc.add(
            any(that: isA<ConversationFullSendRecoveryRequested>()),
          ),
        );
      });
    });

    group('refused retraction', () {
      // #8201. The warning icon is the durable status; the toast is only the
      // immediate announcement and must not remain on screen indefinitely.
      testWidgets('a refused retraction shows a transient explanation', (
        tester,
      ) async {
        final refusedMessage = DmMessage(
          id: 'message',
          conversationId: 'conversation',
          senderPubkey: currentPubkey,
          content: 'Refused',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId: 'wrap',
          retractionStatus: DmRetractionStatus.failed,
        );
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(
              awaitingRetraction: {'message'},
            ),
            state: ConversationState(messages: <DmMessage>[refusedMessage]),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmDeleteRefusedMessage), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(l10n.dmDeleteRefusedMessage), findsNothing);
      });

      testWidgets('an ordinary tick raises no retraction toast', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(),
            state: const ConversationState(),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmDeleteRefusedMessage), findsNothing);
      });

      testWidgets('a confirmed retraction raises no refusal toast', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(
              awaitingRetraction: {'message'},
            ),
            state: const ConversationState(),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmDeleteRefusedMessage), findsNothing);
      });

      testWidgets('consecutive refusals each raise a retraction toast', (
        tester,
      ) async {
        final refusedMessage = DmMessage(
          id: 'first',
          conversationId: 'conversation',
          senderPubkey: currentPubkey,
          content: 'First refusal',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId: 'wrap',
          retractionStatus: DmRetractionStatus.failed,
        );
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(
              awaitingRetraction: {'first', 'second'},
            ),
            state: ConversationState(
              awaitingRetraction: const {'second'},
              messages: <DmMessage>[refusedMessage],
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmDeleteRefusedMessage), findsOneWidget);
      });

      testWidgets('a send outcome does not replay a prior retraction refusal', (
        tester,
      ) async {
        final previousAwaiting = Set<String>.of(const {'message'});
        final currentAwaiting = Set<String>.of(const {'message'});

        await tester.pumpWidget(
          buildSubject(
            previousState: ConversationState(
              awaitingRetraction: previousAwaiting,
            ),
            state: ConversationState(
              sendStatus: SendStatus.blocked,
              awaitingRetraction: currentAwaiting,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmSendBlockedMessage), findsOneWidget);
        expect(find.text(l10n.dmDeleteRefusedMessage), findsNothing);
      });
    });

    group('renders', () {
      testWidgets('renders $ConversationAppBar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(ConversationAppBar), findsOneWidget);
      });

      testWidgets(
        'waits for the peer identity before opening profile options',
        (
          tester,
        ) async {
          final profileCompleter = Completer<UserProfile?>();
          await tester.pumpWidget(
            buildSubject(
              otherProfileFuture: profileCompleter.future,
              isIdentityResolving: true,
            ),
          );
          await tester.pump();

          await tester.tap(
            find.bySemanticsLabel(l10n.inboxConversationOptionsLabel),
          );
          await tester.tap(
            find.bySemanticsLabel(l10n.inboxConversationOptionsLabel),
          );
          await tester.pump();

          expect(find.byType(MoreSheetContent), findsNothing);

          profileCompleter.complete(null);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(MoreSheetContent), findsOneWidget);
        },
      );

      testWidgets('opens profile options when identity lookups fail', (
        tester,
      ) async {
        final profileCompleter = Completer<UserProfile?>();
        final vanishedCompleter = Completer<bool>();
        await tester.pumpWidget(
          buildSubject(
            otherProfileFuture: profileCompleter.future,
            otherProfileVanishedFuture: vanishedCompleter.future,
          ),
        );
        await tester.pump();

        await tester.tap(
          find.bySemanticsLabel(l10n.inboxConversationOptionsLabel),
        );
        await tester.pump();
        vanishedCompleter.completeError(StateError('vanish read failed'));
        await tester.pump();
        profileCompleter.completeError(StateError('profile read failed'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(MoreSheetContent), findsOneWidget);
      });

      testWidgets('opens known moderation options without awaiting a profile', (
        tester,
      ) async {
        final profileCompleter = Completer<UserProfile?>();
        await tester.pumpWidget(
          buildSubject(
            counterparty: kModerationPubkeyHex,
            otherProfileFuture: profileCompleter.future,
            isIdentityResolving: true,
          ),
        );
        await tester.pump();

        await tester.tap(
          find.bySemanticsLabel(l10n.inboxConversationOptionsLabel),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(MoreSheetContent), findsOneWidget);
      });

      testWidgets('renders $MessageInputBar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(MessageInputBar), findsOneWidget);
      });

      testWidgets('renders $CircularProgressIndicator when status is loading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationState(status: ConversationStatus.loading),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders error text when status is error', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationState(status: ConversationStatus.error),
          ),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(ConversationView)),
        );
        expect(find.text(l10n.dmConversationLoadError), findsOneWidget);
        // Cross-check that the widget actually reads from l10n: the German
        // copy must NOT appear in an en-locale render. Catches a regression
        // where the migration accidentally hardcodes the English string
        // alongside the l10n key.
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('de'),
            ).dmConversationLoadError,
          ),
          findsNothing,
        );
      });

      testWidgets('renders $EmptyConversation when loaded with no messages', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationState(status: ConversationStatus.loaded),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyConversation), findsOneWidget);
      });

      testWidgets(
        'empty conversation hides stale avatar and nip05 for deleted account',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationState(status: ConversationStatus.loaded),
              otherProfile: UserProfile(
                pubkey: otherPubkey,
                name: 'Stale Name',
                displayName: 'Stale Display',
                picture: 'https://example.com/stale.jpg',
                nip05: 'stale@example.com',
                rawData: const {},
                createdAt: now,
                eventId: 'stale-profile',
              ),
              otherProfileVanished: true,
            ),
          );
          await tester.pumpAndSettle();

          final empty = tester.widget<EmptyConversation>(
            find.byType(EmptyConversation),
          );
          expect(empty.displayName, l10n.profileDeletedAccountName);
          expect(empty.imageUrl, isNull);
          expect(empty.nip05, isNull);
        },
      );

      testWidgets(
        'empty conversation stays unqualified when recovery is complete',
        (tester) async {
          // The genuinely-new thread (FAB, following bar, profile Message) must
          // keep reading as a clean profile card, not as a degraded state.
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationState(status: ConversationStatus.loaded),
              restoreStatus: const DmRestoreStatusState(),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.byType(EmptyConversation), findsOneWidget);
          expect(
            find.text(l10n.conversationRestorePausedTitle),
            findsNothing,
          );
        },
      );

      testWidgets(
        'empty conversation is qualified while history recovery is unfinished',
        (tester) async {
          // watchMessages is a local DB projection, so an unsynced thread hits
          // `loaded` with zero rows and looks identical to a brand-new one.
          // Recovery status is the only signal that distinguishes them.
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationState(status: ConversationStatus.loaded),
              restoreStatus: const DmRestoreStatusState(
                hasAttempted: true,
                isComplete: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.text(l10n.conversationRestorePausedTitle),
            findsOneWidget,
          );
          // The profile card survives intact alongside the qualifier.
          expect(find.byType(EmptyConversation), findsOneWidget);
          expect(
            find.text(l10n.inboxConversationViewProfileButton),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'empty conversation stays unqualified before recovery has been attempted',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationState(status: ConversationStatus.loaded),
              restoreStatus: const DmRestoreStatusState(isComplete: false),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.byType(EmptyConversation), findsOneWidget);
          expect(
            find.text(l10n.conversationRestorePausedTitle),
            findsNothing,
          );
        },
      );

      testWidgets('renders $MessageBubble when loaded with messages', (
        tester,
      ) async {
        final message = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: otherPubkey,
          content: 'Hello there!',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.text('Hello there!'), findsOneWidget);
      });

      testWidgets('maps message keys to their new indices', (tester) async {
        DmMessage message(String id, String content) => DmMessage(
          id: id,
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: otherPubkey,
          content: content,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );
        final older = message(
          '1111111111111111111111111111111111111111111111111111111111111111',
          'Older',
        );
        final newer = message(
          '2222222222222222222222222222222222222222222222222222222222222222',
          'Newer',
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [newer, older],
            ),
          ),
        );
        await tester.pump();

        final list = tester.widget<ListView>(find.byType(ListView));
        final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
        expect(delegate.findChildIndexCallback, isNotNull);
        expect(
          delegate.findChildIndexCallback!(ValueKey(older.id)),
          equals(1),
        );
        expect(
          delegate.findChildIndexCallback!(ValueKey(newer.id)),
          equals(0),
        );
      });

      testWidgets('keeps an expanded message open when a newer message arrives', (
        tester,
      ) async {
        final states = StreamController<ConversationState>();
        addTearDown(states.close);
        final olderMessage = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: otherPubkey,
          content: 'a' * (dmInitialDisplayCodeUnits + 1),
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );
        final initialState = ConversationState(
          status: ConversationStatus.loaded,
          messages: [olderMessage],
        );

        await tester.pumpWidget(
          buildSubject(state: initialState, stateStream: states.stream),
        );
        await tester.tap(find.text(l10n.profileShowMore));
        await tester.pump();
        expect(find.text(l10n.profileShowLess), findsOneWidget);

        final newerMessage = DmMessage(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          conversationId: olderMessage.conversationId,
          senderPubkey: currentPubkey,
          content: 'new reply',
          createdAt: olderMessage.createdAt + 1,
          giftWrapId:
              'bbbbbbbbccccccccddddddddeeeeeeeebbbbbbbbccccccccddddddddeeeeeeee',
        );
        states.add(
          ConversationState(
            status: ConversationStatus.loaded,
            messages: [newerMessage, olderMessage],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileShowLess), findsOneWidget);
        expect(find.byKey(ValueKey(newerMessage.id)), findsOneWidget);
      });

      // The whole retry affordance lived only in the view: the bloc test
      // covers the event's effects and the bubble test covers the icon, but
      // nothing proved a tap ever produces the event. That gap is how a
      // retry that could never run shipped green.
      testWidgets('tapping a failed retraction dispatches the retry', (
        tester,
      ) async {
        final message = DmMessage(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: currentPubkey,
          content: 'Still recognizable',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
          retractionStatus: DmRetractionStatus.failed,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Still recognizable'));
        await tester.pumpAndSettle();

        // The sheet explains the partial-delivery caveat before offering
        // the retry — that wording is the whole point of the affordance.
        expect(find.text(l10n.dmDeleteRefusedDetails), findsOneWidget);

        await tester.tap(find.text(l10n.authTryAgain));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            ConversationMessageDeletionRetryRequested(rumorId: message.id),
          ),
        ).called(1);
      });

      testWidgets('tapping a pending retraction dispatches the retry', (
        tester,
      ) async {
        final message = DmMessage(
          id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: currentPubkey,
          content: 'Still deleting',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
          retractionStatus: DmRetractionStatus.pending,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Still deleting'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.dmDeletePendingLabel), findsOneWidget);
        expect(find.text(l10n.dmDeleteRefusedDetails), findsOneWidget);

        await tester.tap(find.text(l10n.authTryAgain));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockBloc.add(
            ConversationMessageDeletionRetryRequested(rumorId: message.id),
          ),
        ).called(1);
      });

      // Regression for #4193 — the user-visible bubble list reads from
      // `state.displayedMessages`, which projects in-flight queue rows
      // (`state.pendingOutgoing`, sourced from `DmRepository.watchOutgoing`)
      // on top of the persisted ones. When the watchMessages stream
      // hasn't yet delivered the persisted row (the freshly-searched
      // conversation case, or the microsecond gap between the persistence
      // transaction commit and the watch tick), the queue row in
      // `pendingOutgoing` is the only thing the user has — and it must
      // be visible.
      testWidgets(
        'renders $MessageBubble when only pendingOutgoing is populated '
        '(regression for #4193)',
        (tester) async {
          final pendingRow = OutgoingDm(
            id: 'rumor-test-id',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            recipientPubkey: otherPubkey,
            content: 'Optimistic in flight',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            rumorEventJson: '{}',
            recipientWrapStatus: OutgoingWrapStatus.pending,
            selfWrapStatus: OutgoingWrapStatus.pending,
            queuedAt: now,
            ownerPubkey: currentPubkey,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                pendingOutgoing: [pendingRow],
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(MessageBubble), findsOneWidget);
          expect(find.text('Optimistic in flight'), findsOneWidget);
          // EmptyConversation must NOT render — `messages.isEmpty` alone
          // is not enough to declare the conversation empty when an
          // optimistic is in flight.
          expect(find.byType(EmptyConversation), findsNothing);
        },
      );

      testWidgets('renders display name from profile in app bar', (
        tester,
      ) async {
        final profile = UserProfile(
          pubkey: otherPubkey,
          displayName: 'Alice',
          name: 'alice',
          rawData: const {},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        await tester.pumpWidget(buildSubject(otherProfile: profile));
        // Use pump() instead of pumpAndSettle() because the async
        // Riverpod provider may schedule continuous micro-tasks.
        await tester.pump();
        await tester.pump();

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('uses social proof instead of kind-0 name as handle', (
        tester,
      ) async {
        final profile = UserProfile(
          pubkey: otherPubkey,
          name: 'Jack',
          rawData: const {},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        await tester.pumpWidget(
          buildSubject(
            otherProfile: profile,
            otherStats: const ProfileStats(
              pubkey: otherPubkey,
              followers: 2100,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Jack'), findsOneWidget);
        expect(find.text('@Jack'), findsNothing);
        expect(
          find.text(
            '${l10n.socialProofMutual} · '
            '${l10n.socialProofFollowerCount(2100, '2.1K')}',
          ),
          findsOneWidget,
        );
      });

      // The line's count comes from the `profile_statistics` store, never from
      // the profile object. Both keys below are shapes this screen's cache can
      // never produce anyway — `follower_count` is written only by the
      // people-search path, and `vine_followers` is a Kind 0 *tag* the getter
      // reads out of *content* — so neither may reach the line (#8403).
      testWidgets('ignores follower counts carried on the profile', (
        tester,
      ) async {
        final profile = UserProfile(
          pubkey: otherPubkey,
          name: 'Jack',
          rawData: const {'follower_count': 2100, 'vine_followers': 430},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        await tester.pumpWidget(buildSubject(otherProfile: profile));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.socialProofMutual), findsOneWidget);
        expect(find.textContaining('2.1K'), findsNothing);
        expect(find.textContaining('430'), findsNothing);
      });

      // A zero is indistinguishable from a stats outage: funnelcake answers
      // 200 with `{0, 0}` when the summary table is down.
      testWidgets('omits a zero follower count', (tester) async {
        final profile = UserProfile(
          pubkey: otherPubkey,
          name: 'Jack',
          rawData: const {},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        await tester.pumpWidget(
          buildSubject(
            otherProfile: profile,
            otherStats: const ProfileStats(pubkey: otherPubkey, followers: 0),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.socialProofMutual), findsOneWidget);
        expect(
          find.textContaining(l10n.socialProofFollowerCount(0, '0')),
          findsNothing,
        );
      });

      testWidgets(
        'renders collaborator invite as an inline video preview with co-post actions',
        (tester) async {
          const thumbnailUrl = 'https://cdn.divine.video/thumbs/skate-loop.jpg';
          final message = DmMessage(
            id: '9999999999999999999999999999999999999999999999999999999999999999',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            senderPubkey: otherPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', otherPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
              ['thumb', thumbnailUrl],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          final previewTitle = l10n.inboxCollabInvitePreviewTitle;
          expect(find.textContaining(previewTitle), findsOneWidget);
          expect(find.textContaining('Skate loop'), findsOneWidget);
          expect(
            find.text(l10n.inboxCollabInviteTimelineConsequence),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);
          expect(
            find.text(l10n.inboxCollabInviteNotMineButton),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('collaborator_invite_thumbnail')),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(
              l10n.notificationsVideoThumbnailFor('Skate loop'),
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIcon &&
                  widget.icon == DivineIconName.playFill,
            ),
            findsOneWidget,
          );

          await tester.tap(find.text(l10n.inboxCollabInviteCoPostButton));
          await tester.pump();

          verify(
            () => mockInviteActionsCubit.acceptInvite(any()),
          ).called(1);
        },
      );

      testWidgets(
        'renders collaborator invite card instead of plaintext invite copy',
        (tester) async {
          final message = DmMessage(
            id: '9999999999999999999999999999999999999999999999999999999999999999',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            senderPubkey: otherPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', otherPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(
            find.textContaining(l10n.inboxCollabInvitePreviewTitle),
            findsOneWidget,
          );
          expect(find.textContaining('Skate loop'), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);
          expect(
            find.text(l10n.inboxCollabInviteNotMineButton),
            findsOneWidget,
          );
          expect(find.text('You were invited to collaborate.'), findsNothing);

          await tester.tap(find.text(l10n.inboxCollabInviteCoPostButton));
          await tester.pump();

          verify(
            () => mockInviteActionsCubit.acceptInvite(any()),
          ).called(1);
        },
      );

      testWidgets(
        'renders untitled fallback instead of raw d-tag when no title tag',
        (tester) async {
          final message = DmMessage(
            id: '9999999999999999999999999999999999999999999999999999999999999999',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            senderPubkey: otherPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:1122334411223344112233441122334411223344112233441122334411223344:b25ba0952f63120d35dadcfd704f9017db09c32d10b4074ba51cd6593efbc916',
                'wss://relay.divine.video',
              ],
              ['p', otherPubkey],
              ['role', 'Collaborator'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(
            find.text(l10n.inboxCollabInviteCardUntitledVideo),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'b25ba0952f63120d35dadcfd704f9017db09c32d10b4074ba51cd6593efbc916',
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'renders collaborator invite video inline without navigating away',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final mockGoRouter = MockGoRouter();
          when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'skate-loop',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer(
            (_) async => VideoEventBuilder(
              id: '7777777777777777777777777777777777777777777777777777777777777777',
              pubkey: otherPubkey,
              title: 'Skate loop',
              videoUrl: 'https://cdn.divine.video/videos/skate-loop.mp4',
              thumbnailUrl: 'https://cdn.divine.video/thumbs/skate-loop.jpg',
            ).build(),
          );

          final message = DmMessage(
            id: '9999999999999999999999999999999999999999999999999999999999999999',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            senderPubkey: otherPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', otherPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
              goRouter: mockGoRouter,
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const ValueKey('collaborator_invite_inline_player')),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);
          expect(
            find.text(l10n.inboxCollabInviteNotMineButton),
            findsOneWidget,
          );
          final playerSize = tester.getSize(
            find.byKey(const ValueKey('collaborator_invite_inline_player')),
          );
          expect(playerSize.width, lessThanOrEqualTo(420));
          expect(playerSize.height, lessThanOrEqualTo(748));

          verifyNever(() => mockGoRouter.push(any()));
        },
      );

      // #3559 — NIP-17 echoes a sender's gift wrap back to themselves,
      // so the inviter's own outgoing collab invite shows up in their
      // conversation feed. The renderer must surface it as a static
      // "Invitation sent" status, not Accept/Ignore (the inviter
      // accepting their own invite is nonsensical and would publish a
      // malformed kind-34238 with creator==responder).
      testWidgets(
        'renders sender-direction invite as Sent status, no Accept/Ignore',
        (tester) async {
          final message = DmMessage(
            id: '8888888888888888888888888888888888888888888888888888888888888888',
            conversationId:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            senderPubkey: currentPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'bbbbbbbbccccccccddddddddeeeeeeeebbbbbbbbccccccccddddddddeeeeeeee',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:$currentPubkey:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', currentPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.text(l10n.inboxCollabInviteCardTitle), findsOneWidget);
          expect(find.textContaining('Skate loop'), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteSentStatus), findsOneWidget);
          expect(find.text('Co-post'), findsNothing);
          expect(find.text('Not mine'), findsNothing);
          expect(find.text('You were invited to collaborate.'), findsNothing);

          // Stronger assertion than "no acceptInvite call": sender-side
          // cards do not subscribe to the cubit at all, so loadInvites
          // is never invoked. Prevents state-store pollution.
          verifyNever(() => mockInviteActionsCubit.loadInvites(any()));
        },
      );

      // #3559 Phase 2 — sender-side suppression handles the inviter's
      // own outgoing card. This test covers the recipient-side legacy
      // NIP-04 plaintext duplicate: when an older sender (or another
      // Nostr client) emits an invite as a plain DM with no Divine
      // structured tags, the bubble must not render — it would tell the
      // user to "open diVine" inside diVine itself, with no actionable
      // affordance.
      testWidgets(
        'suppresses legacy NIP-04 invite plaintext duplicates with no '
        'structured tags',
        (tester) async {
          final message = DmMessage(
            id: '7777777777777777777777777777777777777777777777777777777777777777',
            conversationId:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            senderPubkey: otherPubkey,
            content:
                'You were invited to collaborate on Skate loop. '
                'Open diVine to review and accept.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'ccccccccddddddddeeeeeeeeffffffff00000000111111112222222233333333',
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CollaboratorInviteCard), findsNothing);
          expect(find.byType(MessageBubble), findsNothing);
          expect(
            find.textContaining('Open diVine to review and accept'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'still renders plain text DMs that do not match the invite suffix',
        (tester) async {
          final message = DmMessage(
            id: '6666666666666666666666666666666666666666666666666666666666666666',
            conversationId:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            senderPubkey: otherPubkey,
            content: 'Hey, want to ride together this weekend?',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'ddddddddeeeeeeeeffffffff0000000011111111222222223333333344444444',
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(MessageBubble), findsOneWidget);
          expect(
            find.text('Hey, want to ride together this weekend?'),
            findsOneWidget,
          );
        },
      );
    });

    // Send-failure UX (companion to ConversationBloc's clear-optimistic-on-
    // failure behavior). On `SendStatus.failed`, the bloc strips the
    // optimistic message; the UI's job is to surface a retry bottom sheet
    // so the user knows the send actually failed and has a one-tap recovery.
    // Without this listener, the only visible change would be a brief
    // spinner flicker, and the user would discover the loss only after
    // navigating away and back — the "looks sent, then disappeared" bug.
    group('send-outcome toasts + failed-bubble tap', () {
      const failedSendContent = 'Hi there';

      testWidgets(
        'shows NO toast on a hard failure — the failure is surfaced on the '
        'bubble (tap → resend/delete bottom sheet), not a snackbar',
        (tester) async {
          // Emit loaded → failed. listenWhen no longer fires for `failed`.
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.failed,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text(l10n.dmSendFailedMessage), findsNothing);
          expect(find.text(l10n.dmMessageActionRetrySend), findsNothing);
        },
      );

      // #7335. The one send outcome with nothing to attach to: a send with no
      // recipient is refused before a queue row exists, so the red bubble that
      // carries `failed` is never built. Without a toast the composer just
      // cleared the text field and said nothing.
      testWidgets('shows a toast when the send had no recipient', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(),
            state: const ConversationState(
              sendStatus: SendStatus.noRecipient,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmSendNoRecipientMessage), findsOneWidget);
      });

      // #7331. Same shape as the no-recipient case above: an oversized rumor
      // is refused before the enqueue, so no queue row and no red bubble ever
      // exist. Verified on device — without this the message vanished with no
      // feedback at all.
      testWidgets('shows a toast when the message was too long', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(),
            state: const ConversationState(sendStatus: SendStatus.tooLong),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmSendTooLongMessage), findsOneWidget);
        // Not the generic failure copy: retrying an oversized message cannot
        // succeed, so the user needs the reason, not a retry prompt.
        expect(find.text(l10n.dmSendFailedMessage), findsNothing);
      });

      // #8461. A resend that fails again is the one failure the red bubble
      // cannot express: the bubble was ALREADY red when the user tapped it,
      // so re-raising `failed` leaves the before and after states identical
      // and the resend is indistinguishable from a tap that did nothing.
      testWidgets('shows a toast when a resend fails again', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            previousState: const ConversationState(
              status: ConversationStatus.loaded,
              sendStatus: SendStatus.sending,
            ),
            state: const ConversationState(
              status: ConversationStatus.loaded,
              sendStatus: SendStatus.resendFailed,
            ),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.dmResendFailedMessage), findsOneWidget);
      });

      // Guards the split itself: the resend toast must not be the first-send
      // copy, or collapsing the two statuses back together would still pass.
      testWidgets(
        'the resend toast is distinct from the first-send failure copy',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              previousState: const ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sending,
              ),
              state: const ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.resendFailed,
              ),
            ),
          );
          await tester.pump();

          expect(find.text(l10n.dmSendFailedMessage), findsNothing);
        },
      );

      testWidgets(
        'does not show a SnackBar when sendStatus stays non-failed '
        '(e.g. sending → sent)',
        (tester) async {
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sending,
              ),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sent,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text(l10n.dmSendFailedMessage), findsNothing);
        },
      );

      testWidgets(
        'tapping a failed bubble opens the recovery bottom sheet; Resend '
        'replays the row and Delete drops it (never a fresh '
        'ConversationMessageSent)',
        (tester) async {
          final failedRow = OutgoingDm(
            id: 'rumor-failed-id',
            conversationId:
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            recipientPubkey: otherPubkey,
            content: failedSendContent,
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
            rumorEventJson: '{}',
            recipientWrapStatus: OutgoingWrapStatus.failed,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime(2026),
            ownerPubkey: currentPubkey,
          );
          final failedState = ConversationState(
            status: ConversationStatus.loaded,
            sendStatus: SendStatus.failed,
            pendingOutgoing: [failedRow],
          );
          whenListen(
            mockBloc,
            Stream<ConversationState>.value(failedState),
            initialState: failedState,
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklist,
                ),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap the failed bubble to open the resend/delete bottom sheet.
          await tester.tap(find.text(failedSendContent));
          await tester.pumpAndSettle();

          expect(find.text(l10n.dmMessageActionRetrySend), findsOneWidget);
          expect(find.text(l10n.dmMessageActionCancelSend), findsOneWidget);
          // Rename guard: this action must never read "Delete message"
          // again — for a partially delivered group it stops retrying but
          // keeps the delivered copies, so a delete-y label would lie.
          expect(find.text('Delete message'), findsNothing);

          // Resend replays the existing row via recoverFullSend — never a
          // fresh ConversationMessageSent (no duplicate delivery).
          await tester.tap(find.text(l10n.dmMessageActionRetrySend));
          await tester.pumpAndSettle();
          final afterResend = verify(() => mockBloc.add(captureAny())).captured;
          expect(
            afterResend.last,
            isA<ConversationFullSendRecoveryRequested>().having(
              (e) => e.rumorIds,
              'rumorIds',
              equals(const ['rumor-failed-id']),
            ),
          );
          expect(
            afterResend.whereType<ConversationMessageSent>(),
            isEmpty,
            reason: 'resend must replay the row, never redispatch a send',
          );

          // Re-open and tap Stop trying → drops the queued row.
          await tester.tap(find.text(failedSendContent));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.dmMessageActionCancelSend));
          await tester.pumpAndSettle();
          final afterDelete = verify(() => mockBloc.add(captureAny())).captured;
          expect(
            afterDelete.last,
            isA<ConversationOutgoingSendCancelled>().having(
              (e) => e.rumorId,
              'rumorId',
              equals('rumor-failed-id'),
            ),
          );
        },
      );

      testWidgets(
        'on a partially delivered group bubble: Resend targets only the '
        'FAILED sibling; Stop trying cancels pending AND failed siblings but '
        'never one whose recipient already got the message',
        (tester) async {
          const groupConversationId =
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
          final batchCreatedAt = DateTime(2026).millisecondsSinceEpoch ~/ 1000;
          OutgoingDm sibling({
            required String id,
            required String recipientPubkey,
            required OutgoingWrapStatus recipientWrap,
            OutgoingWrapStatus selfWrap = OutgoingWrapStatus.pending,
          }) => OutgoingDm(
            id: id,
            conversationId: groupConversationId,
            recipientPubkey: recipientPubkey,
            content: failedSendContent,
            createdAt: batchCreatedAt,
            rumorEventJson: '{}',
            recipientWrapStatus: recipientWrap,
            selfWrapStatus: selfWrap,
            queuedAt: DateTime(2026),
            ownerPubkey: currentPubkey,
          );
          // The batch winner is persisted; three siblings survive in mixed
          // states.
          final persistedWinner = DmMessage(
            id: 'rumor-winner',
            conversationId: groupConversationId,
            senderPubkey: currentPubkey,
            content: failedSendContent,
            createdAt: batchCreatedAt,
            giftWrapId: 'wrap-winner',
          );
          final state = ConversationState(
            status: ConversationStatus.loaded,
            messages: [persistedWinner],
            pendingOutgoing: [
              sibling(
                id: 'rumor-pending',
                recipientPubkey: otherPubkey,
                recipientWrap: OutgoingWrapStatus.pending,
              ),
              sibling(
                id: 'rumor-failed',
                recipientPubkey:
                    '4444444444444444444444444444444444444444444444444444444444444444',
                recipientWrap: OutgoingWrapStatus.failed,
                selfWrap: OutgoingWrapStatus.failed,
              ),
              sibling(
                id: 'rumor-delivered-selffailed',
                recipientPubkey:
                    '5555555555555555555555555555555555555555555555555555555555555555',
                recipientWrap: OutgoingWrapStatus.sent,
                selfWrap: OutgoingWrapStatus.failed,
              ),
            ],
          );
          whenListen(
            mockBloc,
            Stream<ConversationState>.value(state),
            initialState: state,
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklist,
                ),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Exactly one bubble: the persisted winner, carrying the batch's
          // aggregated failed status (the surviving siblings are folded in).
          expect(find.text(failedSendContent), findsOneWidget);

          await tester.tap(find.text(failedSendContent));
          await tester.pumpAndSettle();

          await tester.tap(find.text(l10n.dmMessageActionRetrySend));
          await tester.pumpAndSettle();
          final afterResend = verify(() => mockBloc.add(captureAny())).captured;
          expect(
            afterResend.whereType<ConversationFullSendRecoveryRequested>(),
            hasLength(1),
          );
          expect(
            afterResend
                .whereType<ConversationFullSendRecoveryRequested>()
                .single
                .rumorIds,
            equals(const ['rumor-failed']),
            reason:
                'resend must never re-deliver to recipients that '
                'already confirmed or are still pending',
          );

          // Re-open and Stop trying → cancels the undelivered siblings only.
          await tester.tap(find.text(failedSendContent));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.dmMessageActionCancelSend));
          await tester.pumpAndSettle();
          final cancelled = verify(() => mockBloc.add(captureAny())).captured
              .whereType<ConversationOutgoingSendCancelled>()
              .map((e) => e.rumorId)
              .toList();
          expect(
            cancelled,
            unorderedEquals(const ['rumor-pending', 'rumor-failed']),
            reason:
                'cancel-send drops every undelivered sibling, but a '
                'recipient that already has the message keeps its row '
                '(only its self-wrap sync is outstanding)',
          );
        },
      );

      // accessibility.md requires explicit SemanticsService announcements
      // on async visible state changes. A hard failure shows NO snackbar
      // (the red in-bubble row is the visual affordance), so the
      // announcement is the ONLY signal assistive tech gets. The test
      // intercepts the platform accessibility channel, where
      // sendAnnouncement ultimately delivers, and pins the localized
      // failure string.
      testWidgets(
        'announces the localized failure message via SemanticsService '
        'when sendStatus transitions to failed',
        (tester) async {
          final announcements = <Map<Object?, Object?>>[];
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                (Object? message) async {
                  if (message is Map) announcements.add(message);
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

          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.failed,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklist,
                ),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final announceCalls = announcements.where(
            (m) => m['type'] == 'announce',
          );
          expect(
            announceCalls,
            isNotEmpty,
            reason:
                'expected SemanticsService.sendAnnouncement to deliver an '
                "'announce' event on SystemChannels.accessibility",
          );
          final announcedMessages = announceCalls.map(
            (m) => (m['data'] as Map?)?['message'],
          );
          expect(
            announcedMessages,
            contains(l10n.dmSendFailedMessage),
            reason: 'announce payload must carry the localized failure copy',
          );
        },
      );

      // The recipient-only partial-delivery path: NIP17MessageService
      // returned `success: true, selfWrapPublished: false`, so the bloc
      // emits SendStatus.sentPartial. The UI must show distinct copy
      // (the message *was* delivered) while still offering retry, and
      // the retry MUST go through the self-wrap-only recovery path so
      // recipients are not re-delivered to (#4102).
      const partialRumorId =
          '7777777777777777777777777777777777777777777777777777777777777777';
      const partialSend = PartialSend(rumorIds: [partialRumorId]);

      testWidgets(
        'shows the partial-delivery SnackBar copy when sendStatus '
        'transitions to sentPartial',
        (tester) async {
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sentPartial,
                lastPartialSend: partialSend,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            find.text(l10n.dmSendPartialMessage),
            findsOneWidget,
            reason:
                'partial-delivery copy must come from context.l10n and be '
                'distinct from the full-failure copy',
          );
          expect(find.text(l10n.dmSendFailedMessage), findsNothing);
          expect(find.text(l10n.dmSendFailedRetry), findsOneWidget);
        },
      );

      testWidgets(
        'tapping Retry on the partial-delivery SnackBar dispatches '
        'ConversationSelfWrapRecoveryRequested with the rumor ids — '
        'never ConversationMessageSent (#4102: no duplicate recipient '
        'publish)',
        (tester) async {
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sentPartial,
                lastPartialSend: partialSend,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: BlocProvider<ConversationReactionsCubit>.value(
                    value: mockReactionsCubit,
                    child: BlocProvider<DmRestoreStatusCubit>.value(
                      value: mockRestoreStatusCubit,
                      child: const ConversationView(
                        participantPubkeys: [otherPubkey],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          // Settle the floating divine snackbar's entrance animation so its
          // action is at its final, tappable position.
          await tester.pumpAndSettle();

          await tester.tap(find.text(l10n.dmSendFailedRetry));
          await tester.pump();

          final captured = verify(() => mockBloc.add(captureAny())).captured;
          expect(captured, isNotEmpty);
          final retryEvent = captured.last;
          expect(
            retryEvent,
            isA<ConversationSelfWrapRecoveryRequested>().having(
              (e) => e.rumorIds,
              'rumorIds',
              equals(const [partialRumorId]),
            ),
          );
          // The pinning contract from #4102: no recipient republish on
          // partial recovery.
          expect(
            captured.whereType<ConversationMessageSent>(),
            isEmpty,
            reason:
                'partial recovery must NOT redispatch ConversationMessageSent '
                '— that would re-deliver to the recipient',
          );
        },
      );
    });

    // Keyboard-dismissal contract: any pointer-down in the messages
    // area or a real finger-drag on the message list dismisses the
    // soft keyboard so the user can read history unobstructed. The
    // Listener-on-pointer-down handles the tap/long-press case;
    // ScrollViewKeyboardDismissBehavior.onDrag handles the scroll
    // case (gated internally on ScrollUpdateNotification.dragDetails
    // != null, so programmatic scrolls do NOT dismiss — which is the
    // intentional contract for any future auto-scroll-on-new-message
    // behavior).
    group('keyboard dismissal', () {
      Future<void> pumpWithMessage(WidgetTester tester) async {
        final message = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: otherPubkey,
          content: 'Hello there!',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();
      }

      testWidgets(
        'dismisses keyboard when the message list is dragged',
        (tester) async {
          await pumpWithMessage(tester);
          await tester.showKeyboard(find.byType(TextField));
          expect(tester.testTextInput.isVisible, isTrue);

          // `tester.drag` synthesizes a real pointer drag, producing
          // a ScrollUpdateNotification with non-null dragDetails —
          // the same code path as a real finger. controller.jumpTo
          // would NOT trigger dismissal (no drag details).
          await tester.drag(find.byType(ListView), const Offset(0, 200));
          await tester.pump();

          expect(tester.testTextInput.isVisible, isFalse);
        },
      );

      testWidgets(
        'dismisses keyboard on pointer-down inside the messages area '
        '(regression guard for the Listener swap)',
        (tester) async {
          await pumpWithMessage(tester);
          await tester.showKeyboard(find.byType(TextField));
          expect(tester.testTextInput.isVisible, isTrue);

          await tester.tapAt(tester.getCenter(find.byType(MessageBubble)));
          await tester.pump();

          expect(tester.testTextInput.isVisible, isFalse);
        },
      );

      // Pins the second half of the GestureDetector → Listener swap
      // contract: dismissal on pointer-down must NOT eat the
      // descendant long-press recognizer on `MessageBubble`. A bare
      // `GestureDetector(onTap:)` competes in the gesture arena and
      // can swallow tap/long-press on descendants; `Listener` does
      // not. The earlier "renders MessageBubble" test only proves the
      // bubble renders — this test proves the full chain
      // Listener (conversation_view) → MessageBubble → onLongPress
      // → ReactionPickerOverlay.show is intact after the swap.
      testWidgets(
        'long-pressing a $MessageBubble still surfaces '
        'message actions',
        (tester) async {
          await pumpWithMessage(tester);

          // Mirror `message_bubble_test.dart`: long-press the bubble
          // by its rendered text. `find.byType(MessageBubble)` aims
          // at the widget's geometric center, which sits over the
          // padding/Semantics node above the bubble's inner
          // GestureDetector and misses the hit-test (Flutter warns
          // "warnIfMissed" in that case).
          await tester.longPress(find.text('Hello there!'));
          await tester.pumpAndSettle();

          // The sheet's localized action labels are the cheapest
          // proof the modal actually mounted — asserting on the
          // sheet widget class would also work but couples to its
          // current implementation (VineBottomSheetActionMenu).
          expect(find.text(l10n.dmMessageActionCopyText), findsOneWidget);
          // `pumpWithMessage` constructs a received message
          // (senderPubkey = otherPubkey), so the sheet must offer
          // Report (received-only) and not Delete (sent-only).
          expect(find.text(l10n.dmMessageActionReport), findsOneWidget);
          expect(
            find.text(l10n.dmMessageActionDeleteForEveryone),
            findsNothing,
          );
          expect(find.text(l10n.dmMessageActionCopyVideoUrl), findsNothing);
          expect(find.text(l10n.shareSheetSaveVideo), findsNothing);
        },
      );

      // Closes #4710: the "+" affordance was a no-op stub. Proves the
      // long-press → "+" path now dismisses the reaction overlay and
      // opens the full emoji picker.
      testWidgets(
        'tapping "+" in the reaction row opens the full emoji picker',
        (tester) async {
          await pumpWithMessage(tester);

          await tester.longPress(find.text('Hello there!'));
          await tester.pumpAndSettle();

          await tester.tap(
            find.bySemanticsLabel(l10n.dmReactionAddCustomA11yLabel),
          );
          await tester.pumpAndSettle();

          expect(find.byType(EmojiEditor), findsOneWidget);
        },
      );
    });

    group('shared video saving', () {
      const stableId = 'skate-loop';

      DmMessage sharedVideoMessage({
        required String senderPubkey,
        String content = 'watch this',
        String? replyToId,
        DmSharedVideoRef? sharedVideoRef,
        bool includeSharedVideoRef = true,
      }) => DmMessage(
        id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        conversationId:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        senderPubkey: senderPubkey,
        content: content,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        giftWrapId:
            'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        replyToId: replyToId,
        sharedVideoRef: includeSharedVideoRef
            ? sharedVideoRef ??
                  DmSharedVideoRef(
                    coordinateOrId: '34236:$senderPubkey:$stableId',
                    videoKind: DmSharedVideoKind.addressableShortVideo,
                  )
            : null,
      );

      Future<void> openSaveAction(
        WidgetTester tester, {
        required DmMessage message,
      }) async {
        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('watch this'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.dmMessageActionCopyVideoUrl), findsOneWidget);
        expect(find.text(l10n.shareSheetSaveVideo), findsOneWidget);
      }

      testWidgets('saves a legacy Divine URL share', (tester) async {
        final message = sharedVideoMessage(
          senderPubkey: currentPubkey,
          content: 'watch this\nhttps://divine.video/video/$stableId',
          includeSharedVideoRef: false,
        );
        final video = VideoEventBuilder(
          id: stableId,
          pubkey: currentPubkey,
        ).build();
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            stableId,
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) async => video);
        when(
          () => mockWatermarkDownloadService.downloadOriginal(
            video: video,
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(OriginalSaveStage);
          onProgress(OriginalSaveStage.downloading);
          onProgress(OriginalSaveStage.saving);
          return const WatermarkDownloadSuccess('/tmp/original.mp4');
        });

        await openSaveAction(tester, message: message);
        clearInteractions(mockVideosRepository);
        await tester.tap(find.text(l10n.shareSheetSaveVideo));
        await tester.pumpAndSettle();

        verify(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            stableId,
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).called(1);
        verify(
          () => mockWatermarkDownloadService.downloadOriginal(
            video: video,
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
      });

      testWidgets('does not offer video actions for a reply citation', (
        tester,
      ) async {
        final message = sharedVideoMessage(
          senderPubkey: otherPubkey,
          replyToId:
              '1111111111111111111111111111111111111111111111111111111111111111',
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('watch this'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.dmMessageActionCopyText), findsOneWidget);
        expect(find.text(l10n.dmMessageActionCopyVideoUrl), findsNothing);
        expect(find.text(l10n.shareSheetSaveVideo), findsNothing);
      });

      testWidgets(
        'saves the original for the current user structured share',
        (tester) async {
          final message = sharedVideoMessage(senderPubkey: currentPubkey);
          final video = VideoEventBuilder(
            id: stableId,
            pubkey: currentPubkey,
          ).build();
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              stableId,
              fallbackRouteIds: ['34236:$currentPubkey:$stableId'],
            ),
          ).thenAnswer((_) async => video);
          when(
            () => mockWatermarkDownloadService.downloadOriginal(
              video: video,
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((invocation) async {
            final onProgress =
                invocation.namedArguments[#onProgress]
                    as void Function(OriginalSaveStage);
            onProgress(OriginalSaveStage.downloading);
            onProgress(OriginalSaveStage.saving);
            return const WatermarkDownloadSuccess('/tmp/original.mp4');
          });

          await openSaveAction(tester, message: message);
          await tester.tap(find.text(l10n.shareSheetSaveVideo));
          await tester.pumpAndSettle();

          verify(
            () => mockWatermarkDownloadService.downloadOriginal(
              video: video,
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          verifyNever(
            () => mockWatermarkDownloadService.downloadWithWatermark(
              video: any(named: 'video'),
              watermarkText: any(named: 'watermarkText'),
              onProgress: any(named: 'onProgress'),
            ),
          );
        },
      );

      testWidgets(
        'saves a watermarked copy for another creator structured share',
        (tester) async {
          final message = sharedVideoMessage(senderPubkey: otherPubkey);
          final video = VideoEventBuilder(
            id: stableId,
            pubkey: otherPubkey,
          ).build();
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              stableId,
              fallbackRouteIds: ['34236:$otherPubkey:$stableId'],
            ),
          ).thenAnswer((_) async => video);
          when(
            () => mockWatermarkDownloadService.downloadWithWatermark(
              video: video,
              watermarkText: any(named: 'watermarkText'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((invocation) async {
            final onProgress =
                invocation.namedArguments[#onProgress]
                    as void Function(WatermarkDownloadStage);
            onProgress(WatermarkDownloadStage.downloading);
            onProgress(WatermarkDownloadStage.watermarking);
            onProgress(WatermarkDownloadStage.saving);
            return const WatermarkDownloadSuccess('/tmp/watermarked.mp4');
          });

          await openSaveAction(tester, message: message);
          await tester.tap(find.text(l10n.shareSheetSaveVideo));
          await tester.pumpAndSettle();

          verify(
            () => mockWatermarkDownloadService.downloadWithWatermark(
              video: video,
              watermarkText: any(named: 'watermarkText'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
          verifyNever(
            () => mockWatermarkDownloadService.downloadOriginal(
              video: any(named: 'video'),
              onProgress: any(named: 'onProgress'),
            ),
          );
        },
      );

      testWidgets('shows unavailable feedback when the video cannot resolve', (
        tester,
      ) async {
        final announcements = <Map<Object?, Object?>>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (Object? message) async {
                if (message is Map) announcements.add(message);
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
        final message = sharedVideoMessage(senderPubkey: otherPubkey);

        await openSaveAction(tester, message: message);
        await tester.tap(find.text(l10n.shareSheetSaveVideo));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(l10n.notificationsVideoUnavailable),
          ),
          findsOneWidget,
        );
        final announcedMessages = announcements
            .where((m) => m['type'] == 'announce')
            .map((m) => (m['data'] as Map?)?['message']);
        expect(announcedMessages, contains(l10n.notificationsVideoUnavailable));
        verifyNever(
          () => mockWatermarkDownloadService.downloadOriginal(
            video: any(named: 'video'),
            onProgress: any(named: 'onProgress'),
          ),
        );
        verifyNever(
          () => mockWatermarkDownloadService.downloadWithWatermark(
            video: any(named: 'video'),
            watermarkText: any(named: 'watermarkText'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      });

      testWidgets('drops a second save request while the first is resolving', (
        tester,
      ) async {
        final message = sharedVideoMessage(senderPubkey: currentPubkey);
        final video = VideoEventBuilder(
          id: stableId,
          pubkey: currentPubkey,
        ).build();
        final resolveCompleter = Completer<VideoEvent?>();
        var resolveCalls = 0;
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            stableId,
            fallbackRouteIds: ['34236:$currentPubkey:$stableId'],
          ),
        ).thenAnswer((_) {
          resolveCalls += 1;
          if (resolveCalls == 1) return Future<VideoEvent?>.value();
          return resolveCompleter.future;
        });
        when(
          () => mockWatermarkDownloadService.downloadOriginal(
            video: video,
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(OriginalSaveStage);
          onProgress(OriginalSaveStage.downloading);
          onProgress(OriginalSaveStage.saving);
          return const WatermarkDownloadSuccess('/tmp/original.mp4');
        });

        await openSaveAction(tester, message: message);
        clearInteractions(mockVideosRepository);
        await tester.tap(find.text(l10n.shareSheetSaveVideo));
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(l10n.libraryPreparingVideo),
          ),
          findsOneWidget,
        );

        await tester.longPress(find.text('watch this'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.shareSheetSaveVideo));
        await tester.pump();

        verify(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            stableId,
            fallbackRouteIds: ['34236:$currentPubkey:$stableId'],
          ),
        ).called(1);

        resolveCompleter.complete(video);
        await tester.pumpAndSettle();

        verify(
          () => mockWatermarkDownloadService.downloadOriginal(
            video: video,
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
      });
    });

    // #5418 — the reaction pill + who-reacted sheet must hide reactions from
    // blocked/muted accounts. ConversationView builds the effective set
    // (shouldFilterFromFeeds semantics) from the blocklist and threads it into
    // every ReactionsRow, reactively via blocklistVersionProvider.
    group('blocked reaction filtering (#5418)', () {
      const blockedReactor =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const mutedReactor =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const visibleReactor =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const reactionMessageId =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      const reactionConversationId =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

      DmMessage reactedMessage() => DmMessage(
        id: reactionMessageId,
        conversationId: reactionConversationId,
        senderPubkey: otherPubkey,
        content: 'Hello there!',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        giftWrapId:
            'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
      );

      DmReaction reaction({
        required String id,
        required String reactor,
        required String emoji,
        int createdAt = 1_700_000_000,
      }) => DmReaction(
        id: id,
        conversationId: reactionConversationId,
        targetMessageId: reactionMessageId,
        targetMessageAuthor: otherPubkey,
        reactorPubkey: reactor,
        emoji: emoji,
        createdAt: createdAt,
        ownerPubkey: currentPubkey,
        publishStatus: DmReactionPublishStatus.received,
      );

      void primeReactions(List<DmReaction> reactions) {
        final state = ConversationReactionsState(
          status: ConversationReactionsStatus.loaded,
          reactionsByMessageId: {reactionMessageId: reactions},
        );
        whenListen(
          mockReactionsCubit,
          Stream<ConversationReactionsState>.value(state),
          initialState: state,
        );
      }

      // The flat DM-hide set the view reads from the repository
      // (`dmHiddenPubkeys`) — the viewer's own blocks and mutes only. A
      // third party's list must not reach a DM surface (#7345).
      Set<String> hiddenReactors({
        Set<String> blocked = const {},
        Set<String> muted = const {},
      }) => {...blocked, ...muted};

      Widget loadedWithReactedMessage() => buildSubject(
        state: ConversationState(
          status: ConversationStatus.loaded,
          messages: [reactedMessage()],
        ),
      );

      testWidgets('hides reactions from blocked and muted reactors in the '
          'pill', (tester) async {
        primeReactions([
          reaction(id: 'r-own', reactor: currentPubkey, emoji: '🔥'),
          reaction(
            id: 'r-vis',
            reactor: visibleReactor,
            emoji: '🎉',
            createdAt: 1_700_000_001,
          ),
          reaction(
            id: 'r-blk',
            reactor: blockedReactor,
            emoji: '😂',
            createdAt: 1_700_000_002,
          ),
          reaction(
            id: 'r-mut',
            reactor: mutedReactor,
            emoji: '👍',
            createdAt: 1_700_000_003,
          ),
        ]);
        when(() => mockBlocklist.dmHiddenPubkeys).thenReturn(
          hiddenReactors(blocked: {blockedReactor}, muted: {mutedReactor}),
        );

        await tester.pumpWidget(loadedWithReactedMessage());
        await tester.pump();

        // Owner + unblocked reactor remain; blocked and muted are gone.
        expect(find.text('🔥'), findsOneWidget);
        expect(find.text('🎉'), findsOneWidget);
        expect(find.text('😂'), findsNothing);
        expect(find.text('👍'), findsNothing);
      });

      testWidgets('renders no pill when every reactor is blocked', (
        tester,
      ) async {
        primeReactions([
          reaction(id: 'r-blk', reactor: blockedReactor, emoji: '😂'),
        ]);
        when(
          () => mockBlocklist.dmHiddenPubkeys,
        ).thenReturn(hiddenReactors(blocked: {blockedReactor}));

        await tester.pumpWidget(loadedWithReactedMessage());
        await tester.pump();

        // The bubble still renders; only its fully-blocked pill collapses.
        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.text('😂'), findsNothing);
      });

      testWidgets('excludes a blocked reactor from the who-reacted sheet', (
        tester,
      ) async {
        primeReactions([
          reaction(id: 'r-own', reactor: currentPubkey, emoji: '🔥'),
          reaction(
            id: 'r-blk',
            reactor: blockedReactor,
            emoji: '😂',
            createdAt: 1_700_000_002,
          ),
        ]);
        when(
          () => mockBlocklist.dmHiddenPubkeys,
        ).thenReturn(hiddenReactors(blocked: {blockedReactor}));

        await tester.pumpWidget(loadedWithReactedMessage());
        await tester.pump();

        await tester.tap(find.text('🔥'));
        // Avoid pumpAndSettle: the view's async profile providers can schedule
        // continuous micro-tasks. Pump the bottom-sheet enter animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
        // The owner's reaction now renders twice — the pill glyph plus the
        // sheet's reactor row — proving the sheet lists reactions; the blocked
        // reactor's emoji appears in neither, proving the sheet itself filters
        // it out rather than the absence just reflecting the collapsed pill.
        expect(find.text('🔥'), findsNWidgets(2));
        expect(find.text('😂'), findsNothing);
      });

      testWidgets('refilters live when the blocklist changes mid-thread', (
        tester,
      ) async {
        var hidden = <String>{};
        when(() => mockBlocklist.dmHiddenPubkeys).thenAnswer((_) => hidden);
        primeReactions([
          reaction(id: 'r-own', reactor: currentPubkey, emoji: '🔥'),
          reaction(
            id: 'r-blk',
            reactor: blockedReactor,
            emoji: '😂',
            createdAt: 1_700_000_002,
          ),
        ]);

        await tester.pumpWidget(loadedWithReactedMessage());
        await tester.pump();

        // Nobody blocked yet: both reactions show.
        expect(find.text('🔥'), findsOneWidget);
        expect(find.text('😂'), findsOneWidget);

        // Block the reactor elsewhere → the version bump rebuilds the view.
        hidden = hiddenReactors(blocked: {blockedReactor});
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ConversationView)),
        );
        container.read(blocklistVersionProvider.notifier).increment();
        await tester.pump();

        expect(find.text('🔥'), findsOneWidget);
        expect(find.text('😂'), findsNothing);
      });
    });
  });
}
