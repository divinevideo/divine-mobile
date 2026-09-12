// ABOUTME: Widget tests for RequestPreviewView.
// ABOUTME: Verifies rendering of profile info, action buttons, message count,
// ABOUTME: and navigation to profile view, conversation, and decline action.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/config/profile_metrics.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../helpers/finders.dart';
import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockMessageRequestActionsCubit
    extends MockCubit<MessageRequestActionsState>
    implements MessageRequestActionsCubit {}

class _MockRequestPreviewCubit extends MockCubit<RequestPreviewState>
    implements RequestPreviewCubit {}

class _MockCollaboratorInviteActionsCubit
    extends MockCubit<CollaboratorInviteActionsState>
    implements CollaboratorInviteActionsCubit {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey) {
    when(() => authState).thenReturn(AuthState.authenticated);
    when(
      () => authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  }
  final String _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;
}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const fallbackInvite = CollaboratorInvite(
    messageId:
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    videoAddress: '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
    videoKind: 34236,
    creatorPubkey: otherPubkey,
    videoDTag: 'skate-loop',
    role: 'Collaborator',
  );
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(RequestPreviewView, () {
    late _MockMessageRequestActionsCubit mockActionsCubit;
    late _MockRequestPreviewCubit mockPreviewCubit;
    late _MockCollaboratorInviteActionsCubit mockInviteActionsCubit;
    late _MockVideosRepository mockVideosRepository;
    late MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;
    late UserProfile testProfile;

    setUpAll(() {
      registerFallbackValue(fallbackInvite);
      registerFallbackValue(<String>[]);
    });

    setUp(() {
      mockActionsCubit = _MockMessageRequestActionsCubit();
      mockPreviewCubit = _MockRequestPreviewCubit();
      mockInviteActionsCubit = _MockCollaboratorInviteActionsCubit();
      mockVideosRepository = _MockVideosRepository();
      mockNostrClient = createMockNostrService();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      // Default to the settled success status: the action buttons read this
      // after awaiting to decide whether to confirm-and-pop or surface an
      // error. Individual tests override it for the error / in-flight paths.
      when(() => mockActionsCubit.state).thenReturn(
        const MessageRequestActionsState(
          status: MessageRequestActionsStatus.success,
        ),
      );

      when(() => mockPreviewCubit.state).thenReturn(
        const RequestPreviewState(
          status: RequestPreviewStatus.loaded,
          messageCount: 3,
          participantPubkeys: [otherPubkey],
        ),
      );

      when(() => mockPreviewCubit.conversationId).thenReturn(conversationId);
      when(
        () => mockInviteActionsCubit.state,
      ).thenReturn(const CollaboratorInviteActionsState());
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

      testProfile = UserProfile(
        pubkey: otherPubkey,
        displayName: 'TestUser',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
    });

    Widget buildSubject({RequestPreviewState? previewState}) {
      if (previewState != null) {
        when(() => mockPreviewCubit.state).thenReturn(previewState);
      }

      return testMaterialApp(
        mockAuthService: mockAuthService,
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          goRouterProvider.overrideWithValue(mockGoRouter),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          userProfileReactiveProvider(
            otherPubkey,
          ).overrideWith((ref) => Stream.value(testProfile)),
        ],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RequestPreviewCubit>.value(value: mockPreviewCubit),
              BlocProvider<MessageRequestActionsCubit>.value(
                value: mockActionsCubit,
              ),
              BlocProvider<CollaboratorInviteActionsCubit>.value(
                value: mockInviteActionsCubit,
              ),
            ],
            child: const RequestPreviewView(),
          ),
        ),
      );
    }

    // #7486. These counts had never rendered. The widget read
    // `UserProfile.followerCount` / `videoCount`, whose REST disjunct is only
    // ever populated by the people-search shape (never written to the cache
    // this screen reads) and whose Kind 0 disjunct reads `rawData` for keys
    // the archive importer writes as tags. Both were structurally null, so the
    // line was dead. Counts now come from the `profile_statistics` store.
    group('stats line', () {
      Widget buildStatsSubject(ProfileStats? stats, {bool vanished = false}) {
        return testMaterialApp(
          mockAuthService: mockAuthService,
          mockNostrService: mockNostrClient,
          additionalOverrides: [
            goRouterProvider.overrideWithValue(mockGoRouter),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            userProfileReactiveProvider(
              otherPubkey,
            ).overrideWith((ref) => Stream.value(testProfile)),
            userProfileStatsReactiveProvider(
              otherPubkey,
            ).overrideWith((ref) => Stream.value(stats)),
            profileVanishedProvider(
              otherPubkey,
            ).overrideWith((ref) => vanished),
          ],
          home: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RequestPreviewCubit>.value(
                  value: mockPreviewCubit,
                ),
                BlocProvider<MessageRequestActionsCubit>.value(
                  value: mockActionsCubit,
                ),
                BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                ),
              ],
              child: const RequestPreviewView(),
            ),
          ),
        );
      }

      // The skeleton shimmer animates forever, so `pumpAndSettle` would time
      // out. Pump explicitly instead.
      Future<void> pumpStats(WidgetTester tester, Widget subject) async {
        await tester.pumpWidget(subject);
        await tester.pump();
        await tester.pump();
      }

      ProfileStats statsWith({
        int? followers,
        int videoCount = 0,
        int totalViews = 0,
      }) => ProfileStats(
        pubkey: otherPubkey,
        followers: followers,
        videoCount: videoCount,
        totalViews: totalViews,
      );

      // The regression guard: on the pre-fix build the widget ignored
      // ProfileStats entirely and rendered no counts at all, so this fails
      // without the source change rather than merely re-asserting it.
      testWidgets('renders the follower count from ProfileStats', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpStats(
            tester,
            buildStatsSubject(statsWith(followers: 2100)),
          );

          final followerText = l10n.messageRequestFollowersCount(2100, '2.1K');
          expect(
            find.textContaining(followerText, findRichText: true),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel(followerText), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('renders the video count from ProfileStats', (tester) async {
        await pumpStats(tester, buildStatsSubject(statsWith(videoCount: 15)));

        expect(
          find.textContaining(
            l10n.messageRequestVideosCount(15, '15'),
            findRichText: true,
          ),
          findsOneWidget,
        );
      });

      // A zero is indistinguishable from "never indexed" and from a stats
      // outage — funnelcake collapses a ClickHouse failure into zeros behind
      // an HTTP 200 — so it is withheld, matching the repository's own
      // follower/following guard.
      testWidgets('omits the video count when it is zero', (tester) async {
        await pumpStats(tester, buildStatsSubject(statsWith(followers: 5)));

        expect(
          find.textContaining(
            l10n.messageRequestVideosCount(0, '0'),
            findRichText: true,
          ),
          findsNothing,
        );
      });

      // Null followers means "not known yet", never zero.
      testWidgets('omits the follower count when it is null', (tester) async {
        await pumpStats(tester, buildStatsSubject(statsWith(videoCount: 3)));

        expect(
          find.textContaining(
            l10n.messageRequestFollowersCount(0, '0'),
            findRichText: true,
          ),
          findsNothing,
        );
      });

      testWidgets('omits the follower count when it is zero', (tester) async {
        await pumpStats(
          tester,
          buildStatsSubject(statsWith(followers: 0, videoCount: 3)),
        );

        expect(
          find.textContaining(
            l10n.messageRequestFollowersCount(0, '0'),
            findRichText: true,
          ),
          findsNothing,
        );
      });

      testWidgets('omits loops below the visibility floor', (tester) async {
        await pumpStats(
          tester,
          buildStatsSubject(
            statsWith(
              videoCount: 3,
              totalViews: profileLoopsVisibilityFloor - 1,
            ),
          ),
        );

        expect(
          find.textContaining(
            l10n.videoFeedLoopCountLine(
              StringUtils.formatCompactNumber(
                profileLoopsVisibilityFloor - 1,
              ),
              profileLoopsVisibilityFloor - 1,
            ),
            findRichText: true,
          ),
          findsNothing,
        );
      });

      // The sender is never the viewer, so the profile header's owner
      // exemption does not apply — only the floor decides.
      testWidgets('renders loops at the visibility floor', (tester) async {
        await pumpStats(
          tester,
          buildStatsSubject(
            statsWith(videoCount: 3, totalViews: profileLoopsVisibilityFloor),
          ),
        );

        expect(
          find.textContaining(
            l10n.videoFeedLoopCountLine(
              StringUtils.formatCompactNumber(profileLoopsVisibilityFloor),
              profileLoopsVisibilityFloor,
            ),
            findRichText: true,
          ),
          findsOneWidget,
        );
      });

      // An ICU plural fuses its numeral and its noun, so there is no numeral
      // to swap for a dash the way the profile header's columns do. The line
      // shimmers, then gives up.
      testWidgets('hides the line once the skeleton times out', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpStats(tester, buildStatsSubject(null));

          // A placeholder line stands in while the counts are still arriving.
          final placeholderFollowers = l10n.messageRequestFollowersCount(
            99,
            '99',
          );
          final placeholderVideos = l10n.messageRequestVideosCount(99, '99');
          expect(
            find.textContaining(placeholderFollowers, findRichText: true),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(
              '$placeholderFollowers \u2022 $placeholderVideos',
            ),
            findsNothing,
          );

          await tester.pump(const Duration(seconds: 8));

          // Once the store has plainly not answered, the line goes rather than
          // shimmering forever or degrading to a dash it cannot pluralise.
          expect(
            find.textContaining(placeholderFollowers, findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining(placeholderVideos, findRichText: true),
            findsNothing,
          );
        } finally {
          semantics.dispose();
        }
      });

      // Matches the avatar/handle suppression: a vanished account shows no
      // counts, and does not shimmer waiting for counts that never arrive.
      testWidgets('renders no stats for a vanished account', (tester) async {
        await pumpStats(
          tester,
          buildStatsSubject(
            statsWith(followers: 2100, videoCount: 9),
            vanished: true,
          ),
        );

        expect(
          find.textContaining(
            l10n.messageRequestFollowersCount(2100, '2.1K'),
            findRichText: true,
          ),
          findsNothing,
        );
        expect(
          find.textContaining(
            l10n.messageRequestVideosCount(9, '9'),
            findRichText: true,
          ),
          findsNothing,
        );
      });
    });

    // #6416. This screen is where an inbound-first moderation notice is first
    // seen, and it offered "Decline and remove" against an unidentified
    // "Adjective Animal N" — moderation recognition never reached the requests
    // flow, and neither moderation key has a kind-0 the app can read.
    group('moderation identity', () {
      Widget buildModerationSubject(String counterparty) {
        when(() => mockPreviewCubit.state).thenReturn(
          RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 1,
            participantPubkeys: [counterparty],
          ),
        );

        return testMaterialApp(
          mockAuthService: mockAuthService,
          mockNostrService: mockNostrClient,
          additionalOverrides: [
            goRouterProvider.overrideWithValue(mockGoRouter),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            userProfileReactiveProvider(
              counterparty,
            ).overrideWith((ref) => Stream.value(null)),
          ],
          home: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RequestPreviewCubit>.value(
                  value: mockPreviewCubit,
                ),
                BlocProvider<MessageRequestActionsCubit>.value(
                  value: mockActionsCubit,
                ),
                BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                ),
              ],
              child: const RequestPreviewView(),
            ),
          ),
        );
      }

      testWidgets('a retired moderation request identifies itself as Divine', (
        tester,
      ) async {
        final retired = kLegacyModerationPubkeys.first;

        await tester.pumpWidget(buildModerationSubject(retired));
        await tester.pumpAndSettle();

        // Header, the name under the avatar, and the "wants to message you"
        // sentence all read from the same resolved name.
        expect(find.text(l10n.inboxSupportRowTitle), findsWidgets);
        expect(
          find.textContaining(UserProfile.defaultDisplayNameFor(retired)),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.logo,
            description: 'bundled Divine wordmark',
          ),
          findsOneWidget,
        );
      });

      testWidgets('an ordinary request is untouched', (tester) async {
        await tester.pumpWidget(buildModerationSubject(otherPubkey));
        await tester.pumpAndSettle();

        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsWidgets,
        );
        expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
      });

      // #6971. Removal here is permanent — it writes a tombstone that
      // suppresses relay replay for the account's lifetime — and the notice is
      // the user's only copy of why they were actioned.
      testWidgets('a retired moderation notice offers no removal', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildModerationSubject(kLegacyModerationPubkeys.first),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.messageRequestDeclineAndRemoveButton),
          findsNothing,
        );
        expect(
          find.text(l10n.messageRequestViewMessagesButton),
          findsOneWidget,
        );
      });

      testWidgets('the current moderation key offers no removal either', (
        tester,
      ) async {
        // The pin lifts a current-key thread out of Requests today, so this is
        // insurance for the next rotation rather than a live path.
        await tester.pumpWidget(buildModerationSubject(kModerationPubkeyHex));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.messageRequestDeclineAndRemoveButton),
          findsNothing,
        );
      });

      testWidgets('a group with a moderation participant offers no removal', (
        tester,
      ) async {
        when(() => mockPreviewCubit.state).thenReturn(
          RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 1,
            participantPubkeys: [otherPubkey, kLegacyModerationPubkeys.first],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.messageRequestDeclineAndRemoveButton),
          findsNothing,
        );
      });

      testWidgets('an ordinary request still offers removal', (tester) async {
        await tester.pumpWidget(buildModerationSubject(otherPubkey));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.messageRequestDeclineAndRemoveButton),
          findsOneWidget,
        );
      });

      // #6971. The row that opens this preview already reads "This
      // conversation is closed"; the preview dropped every closed signal and
      // replaced it with an overture. "Wants to message you" is false twice
      // over on a retired key: nobody is behind it, and an enforcement notice
      // is not a social approach.
      testWidgets('a retired moderation notice reads as closed, not as an '
          'overture', (tester) async {
        await tester.pumpWidget(
          buildModerationSubject(kLegacyModerationPubkeys.first),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
        expect(find.text(l10n.dmRetiredThreadClosedBody), findsOneWidget);
        expect(
          find.text(
            l10n.messageRequestWantsToMessageYou(
              l10n.inboxSupportRowTitle,
              l10n.messageRequestMessageCount(1),
            ),
          ),
          findsNothing,
        );
      });

      testWidgets('an ordinary request keeps the overture framing', (
        tester,
      ) async {
        await tester.pumpWidget(buildModerationSubject(otherPubkey));
        await tester.pumpAndSettle();

        expect(
          find.text(
            l10n.messageRequestWantsToMessageYou(
              UserProfile.defaultDisplayNameFor(otherPubkey),
              l10n.messageRequestMessageCount(1),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.dmRetiredThreadClosedTitle), findsNothing);
      });
    });

    // #8185. The same screen links straight through to the profile, which
    // already names a vanished account for the state — so this row rendering
    // a generated handle put both names one tap apart.
    group('deleted accounts', () {
      Widget buildVanishedSubject({required bool vanished}) {
        when(() => mockPreviewCubit.state).thenReturn(
          const RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 1,
            participantPubkeys: [otherPubkey],
          ),
        );

        return testMaterialApp(
          mockAuthService: mockAuthService,
          mockNostrService: mockNostrClient,
          additionalOverrides: [
            goRouterProvider.overrideWithValue(mockGoRouter),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            userProfileReactiveProvider(
              otherPubkey,
            ).overrideWith((ref) => Stream.value(testProfile)),
            profileVanishedProvider(
              otherPubkey,
            ).overrideWith((ref) => vanished),
          ],
          home: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RequestPreviewCubit>.value(
                  value: mockPreviewCubit,
                ),
                BlocProvider<MessageRequestActionsCubit>.value(
                  value: mockActionsCubit,
                ),
                BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                ),
              ],
              child: const RequestPreviewView(),
            ),
          ),
        );
      }

      testWidgets('names a vanished sender for the state everywhere', (
        tester,
      ) async {
        await tester.pumpWidget(buildVanishedSubject(vanished: true));
        await tester.pumpAndSettle();

        // Header, the name under the avatar, the "wants to message you"
        // sentence and the decline confirmation all read the same name.
        expect(find.text(l10n.profileDeletedAccountName), findsWidgets);
        expect(
          find.textContaining(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsNothing,
        );
        expect(find.textContaining('TestUser'), findsNothing);
      });

      testWidgets('leaves a live sender untouched', (tester) async {
        await tester.pumpWidget(buildVanishedSubject(vanished: false));
        await tester.pumpAndSettle();

        expect(find.text('TestUser'), findsWidgets);
        expect(find.text(l10n.profileDeletedAccountName), findsNothing);
      });
    });

    group('renders', () {
      testWidgets('renders app bar with display name as title', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('TestUser'), findsWidgets);
      });

      testWidgets('renders $UserAvatar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders "View profile" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('View profile'), findsOneWidget);
      });

      testWidgets('renders "View messages" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('View messages'), findsOneWidget);
      });

      testWidgets('renders "Decline and remove" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Decline and remove'), findsOneWidget);
      });

      testWidgets('renders only the approved request actions', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final actionBar = find.byWidgetPredicate(
          (widget) => widget is SafeArea && !widget.top,
        );
        final actions = find.descendant(
          of: actionBar,
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
        );

        expect(actionBar, findsOneWidget);
        expect(actions, findsNWidgets(2));
        expect(
          find.descendant(
            of: actionBar,
            matching: find.text(l10n.messageRequestViewMessagesButton),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: actionBar,
            matching: find.text(l10n.messageRequestDeclineAndRemoveButton),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders message count description', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.textContaining('3 messages'), findsOneWidget);
      });

      testWidgets('renders collaborator invite actions without plaintext', (
        tester,
      ) async {
        const inviteMessage = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId: conversationId,
          senderPubkey: otherPubkey,
          content: 'You were invited to collaborate.',
          createdAt: 1700000000,
          giftWrapId: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          tags: [
            ['divine', 'collab-invite'],
            [
              'a',
              '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
              'wss://relay.divine.video',
            ],
            ['p', otherPubkey],
            ['role', 'Collaborator'],
            ['title', 'Skate loop'],
            ['thumb', 'https://cdn.divine.video/thumbs/skate-loop.jpg'],
          ],
        );

        await tester.pumpWidget(
          buildSubject(
            previewState: const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 1,
              participantPubkeys: [otherPubkey],
              messages: [inviteMessage],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.inboxCollabInvitePreviewTitleFrom('TestUser')),
          findsOneWidget,
        );
        expect(find.text('Skate loop'), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteNotMineButton), findsOneWidget);
        expect(
          find.byKey(const ValueKey('collaborator_invite_thumbnail')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.inboxCollabInviteTimelineConsequence),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.notificationsVideoThumbnailFor('Skate loop'),
          ),
          findsOneWidget,
        );
        expect(find.text('You were invited to collaborate.'), findsNothing);

        await tester.ensureVisible(
          find.text(l10n.inboxCollabInviteNotMineButton),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.inboxCollabInviteNotMineButton));
        await tester.pump();

        verify(() => mockInviteActionsCubit.ignoreInvite(any())).called(1);
        verifyNever(() => mockActionsCubit.declineRequest(any()));
      });

      testWidgets('renders sent collaborator invite preview without actions', (
        tester,
      ) async {
        const inviteMessage = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId: conversationId,
          senderPubkey: currentPubkey,
          content: 'You were invited to collaborate.',
          createdAt: 1700000000,
          giftWrapId: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          tags: [
            ['divine', 'collab-invite'],
            [
              'a',
              '34236:aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd:skate-loop',
              'wss://relay.divine.video',
            ],
            ['p', currentPubkey],
            ['role', 'Collaborator'],
            ['title', 'Skate loop'],
          ],
        );

        await tester.pumpWidget(
          buildSubject(
            previewState: const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 1,
              participantPubkeys: [otherPubkey],
              messages: [inviteMessage],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.inboxCollabInviteCardTitle), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteSentStatus), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        expect(find.text(l10n.inboxCollabInviteNotMineButton), findsNothing);
      });
    });

    group('navigation', () {
      testWidgets('navigates to profile view when "View profile" tapped', (
        tester,
      ) async {
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('View profile'));
        await tester.pump();

        verify(
          () => mockGoRouter.push(any(that: startsWith('/profile-view/'))),
        ).called(1);
      });

      testWidgets('navigates to conversation when "View messages" tapped', (
        tester,
      ) async {
        when(
          () => mockGoRouter.pushReplacementNamed(
            any(),
            pathParameters: any(named: 'pathParameters'),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('View messages'));
        await tester.pump();

        verify(
          () => mockGoRouter.pushReplacementNamed(
            ConversationPage.routeName,
            pathParameters: {'id': conversationId},
            extra: [otherPubkey],
          ),
        ).called(1);
      });

      testWidgets(
        'calls declineRequest and pops when "Decline and remove" tapped',
        (tester) async {
          when(
            () => mockActionsCubit.declineRequest(any()),
          ).thenAnswer((_) async => DeclineRequestOutcome.removed);

          when(mockGoRouter.canPop).thenReturn(true);
          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Decline and remove'));
          await tester.pumpAndSettle();

          verify(
            () => mockActionsCubit.declineRequest(conversationId),
          ).called(1);

          verify(() => mockGoRouter.pop()).called(1);
        },
      );

      // The loaded state is deep-linkable too: `loading` is only the first
      // frame of that same cold entry, so both of its navigating affordances
      // meet the one-entry stack that plain `pop()` throws on (#6112).
      testWidgets('back from a cold loaded entry lands on the inbox', (
        tester,
      ) async {
        when(mockGoRouter.canPop).thenReturn(false);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(findByTooltip('Back'));
        await tester.pump();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });

      testWidgets('decline from a cold loaded entry lands on the inbox', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => DeclineRequestOutcome.removed);
        when(mockGoRouter.canPop).thenReturn(false);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Decline and remove'));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });
    });

    group('decline feedback', () {
      testWidgets('ignores decline while an action is in flight', (
        tester,
      ) async {
        when(() => mockActionsCubit.state).thenReturn(
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        verifyNever(() => mockActionsCubit.declineRequest(any()));
      });

      testWidgets('confirms with a snackbar after declining', (tester) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => DeclineRequestOutcome.removed);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        expect(
          find.text(l10n.messageRequestDeclinedSnackbar('TestUser')),
          findsOneWidget,
        );
      });

      testWidgets('when the decline fails, warns and does not claim success', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => DeclineRequestOutcome.failed);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
        expect(
          find.text(l10n.messageRequestDeclinedSnackbar('TestUser')),
          findsNothing,
        );
        verifyNever(() => mockGoRouter.pop());
      });
    });

    // #7335. `build` branched on `denied` only, so `loading` and `error` fell
    // through to the loaded layout with `participantPubkeys` still empty:
    // live accept/decline buttons over an unknown sender, a generated
    // "Adjective Animal N" name in the header, a count of 0, and — per the
    // August iOS release log — a profile fetch for the empty string that the
    // REST fallback rejects with "Pubkey cannot be empty" before falling back
    // to relays for `''`. `loaded` is included because `_resolveParticipants`
    // returns `[]` for a conversation the DB does not have, which reaches the
    // same layout by a different route.
    group('states without a resolved participant', () {
      late MockProfileRepository mockProfileRepository;

      setUp(() {
        mockProfileRepository = MockProfileRepository();
        when(
          () => mockProfileRepository.getCachedProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () =>
              mockProfileRepository.watchProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) => const Stream<UserProfile?>.empty());
        when(
          () => mockProfileRepository.watchProfileStats(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) => const Stream<ProfileStats?>.empty());
        when(() => mockPreviewCubit.load()).thenAnswer((_) async {});
      });

      Widget buildStatusSubject(RequestPreviewState previewState) {
        when(() => mockPreviewCubit.state).thenReturn(previewState);

        return testMaterialApp(
          mockAuthService: mockAuthService,
          mockNostrService: mockNostrClient,
          mockProfileRepository: mockProfileRepository,
          additionalOverrides: [
            goRouterProvider.overrideWithValue(mockGoRouter),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          ],
          home: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RequestPreviewCubit>.value(
                  value: mockPreviewCubit,
                ),
                BlocProvider<MessageRequestActionsCubit>.value(
                  value: mockActionsCubit,
                ),
                BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                ),
              ],
              child: const RequestPreviewView(),
            ),
          ),
        );
      }

      // A CircularProgressIndicator never settles, so these pump explicitly.
      Future<void> pumpTwice(WidgetTester tester, Widget subject) async {
        await tester.pumpWidget(subject);
        await tester.pump();
        await tester.pump();
      }

      // `loading` is the first frame of every entry to this route, deep links
      // included, so its back button is the one most likely to meet a one-entry
      // stack — where a plain `pop()` throws GoError (#6112).
      testWidgets('back from a cold entry lands on the inbox', (tester) async {
        when(mockGoRouter.canPop).thenReturn(false);

        await pumpTwice(
          tester,
          buildStatusSubject(const RequestPreviewState()),
        );

        await tester.tap(findByTooltip('Back'));
        await tester.pump();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });

      testWidgets('loading offers no accept action', (tester) async {
        await pumpTwice(
          tester,
          buildStatusSubject(const RequestPreviewState()),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.messageRequestViewMessagesButton), findsNothing);
      });

      testWidgets('error offers a retry instead of accept', (tester) async {
        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        expect(find.text(l10n.messageRequestLoadFailed), findsOneWidget);
        expect(find.text(l10n.messageRequestViewMessagesButton), findsNothing);

        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();

        verify(() => mockPreviewCubit.load()).called(1);
      });

      // The unresolved-counterparty gate must not take decline down with the
      // accept action: `declineRequest` keys off the conversation ID alone, and
      // stripping it leaves an unwanted request dismissable only by the
      // inbox-wide "Remove all requests".
      for (final entry in const {
        'loading': RequestPreviewState(),
        'error': RequestPreviewState(status: RequestPreviewStatus.error),
        'participant-less loaded': RequestPreviewState(
          status: RequestPreviewStatus.loaded,
        ),
      }.entries) {
        testWidgets('${entry.key} can still decline the request', (
          tester,
        ) async {
          when(
            () => mockActionsCubit.declineRequest(any()),
          ).thenAnswer((_) async => DeclineRequestOutcome.removed);
          when(mockGoRouter.canPop).thenReturn(true);
          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await pumpTwice(tester, buildStatusSubject(entry.value));

          await tester.tap(
            find.text(l10n.messageRequestDeclineAndRemoveButton),
          );
          await tester.pump();

          verify(
            () => mockActionsCubit.declineRequest(conversationId),
          ).called(1);
          verify(() => mockGoRouter.pop()).called(1);
        });
      }

      // Same one-entry-stack exposure as the back button: decline navigates
      // away too, and a cold deep link has nothing to pop (#6112).
      testWidgets('decline from a cold entry lands on the inbox', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => DeclineRequestOutcome.removed);
        when(mockGoRouter.canPop).thenReturn(false);

        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });

      // With no resolved counterparty there is no name to put in the
      // confirmation, so decline falls back to the name-free "Removed
      // conversation" rather than either staying silent or naming a generated
      // "Adjective Animal N" placeholder (the #7335 leak / #7881 review).
      testWidgets('declining an unresolved request confirms without a name', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => DeclineRequestOutcome.removed);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        verify(() => mockActionsCubit.declineRequest(conversationId)).called(1);
        expect(find.text(l10n.inboxRemovedConversation), findsOneWidget);
      });

      testWidgets('protected unresolved request is kept with an explanation', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => DeclineRequestOutcome.refused);
        when(mockGoRouter.canPop).thenReturn(true);

        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        expect(
          find.text(l10n.messageRequestModerationNoticeCannotBeRemoved),
          findsOneWidget,
        );
        verifyNever(() => mockGoRouter.pop());
        verifyNever(() => mockGoRouter.go(any()));
      });

      testWidgets('error does not name the sender or count its messages', (
        tester,
      ) async {
        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        expect(
          find.textContaining(UserProfile.defaultDisplayNameFor('')),
          findsNothing,
        );
        expect(
          find.textContaining(l10n.messageRequestMessageCount(0)),
          findsNothing,
        );
      });

      testWidgets('loaded without a participant renders the failure state', (
        tester,
      ) async {
        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 2,
            ),
          ),
        );

        expect(find.text(l10n.messageRequestLoadFailed), findsOneWidget);
        expect(find.text(l10n.messageRequestViewMessagesButton), findsNothing);
      });

      for (final entry in const {
        'initial': RequestPreviewState(),
        'error': RequestPreviewState(status: RequestPreviewStatus.error),
        'participant-less loaded': RequestPreviewState(
          status: RequestPreviewStatus.loaded,
        ),
      }.entries) {
        testWidgets(
          'the ${entry.key} build never reads a profile for the empty pubkey',
          (tester) async {
            await pumpTwice(tester, buildStatusSubject(entry.value));

            verifyNever(
              () => mockProfileRepository.getCachedProfile(pubkey: ''),
            );
            verifyNever(
              () => mockProfileRepository.fetchFreshProfile(pubkey: ''),
            );
            verifyNever(() => mockProfileRepository.watchProfile(pubkey: ''));
          },
        );
      }
    });
  });
}
