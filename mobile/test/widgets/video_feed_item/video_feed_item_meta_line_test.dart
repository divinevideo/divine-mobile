// ABOUTME: Widget tests for the video card's author lifetime-loops meta line.
// ABOUTME: Pins the author total (not the video's), the chits, the author node.

import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/og_diviner_eligibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

const _authorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const _strangerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockAuthService extends Mock implements AuthService {}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

VideoEvent _video({
  String pubkey = _authorPubkey,
  Map<String, String> rawTags = const {},
}) {
  final at = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'video-card-meta-line-test-0123456789abcdef0123456789abcdef0123',
    pubkey: pubkey,
    createdAt: at,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
    rawTags: rawTags,
  );
}

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockRepostsRepository mockRepostsRepository;
  late _MockAuthService mockAuthService;
  late StreamController<AuthState> authStateController;

  setUp(() {
    authStateController = StreamController<AuthState>.broadcast();
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    mockRepostsRepository = _MockRepostsRepository();
    mockAuthService = _MockAuthService();

    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockInteractionsBloc.state,
    ).thenReturn(const VideoInteractionsState());
    when(
      () => mockRepostsRepository.fetchEventReposters(
        eventId: any(named: 'eventId'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_strangerPubkey);
    when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
  });

  tearDown(() => authStateController.close());

  /// Pumps the overlay for [video]. [authorTotalLoops] is the author's lifetime
  /// loop total; null means the stats are not known yet.
  /// [authorTotalKnown] false models a cached stats row whose total never
  /// arrived, which `ProfileStats` carries as a placeholder zero.
  Future<void> pump(
    WidgetTester tester, {
    required VideoEvent video,
    int? authorTotalLoops,
    bool authorTotalKnown = true,
    bool isOgDiviner = false,
    bool eligibilityIsLoading = false,
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          authServiceProvider.overrideWithValue(mockAuthService),
          ogDivinerEligibilityProvider.overrideWith(
            eligibilityIsLoading
                ? (ref, pubkey) => Completer<bool>().future
                : (ref, pubkey) async => isOgDiviner && pubkey == video.pubkey,
          ),
          videoCardAuthorStatsProvider(video.pubkey).overrideWith(
            (ref) => authorTotalLoops == null
                ? const Stream<ProfileStats?>.empty()
                : Stream.value(
                    ProfileStats(
                      pubkey: video.pubkey,
                      totalViews: authorTotalLoops,
                      hasKnownTotalViews: authorTotalKnown,
                    ),
                  ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: mockInteractionsBloc,
              child: VideoOverlayActions(
                video: video,
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      ),
    );
    // A lookup that never answers has nothing to settle to.
    if (eligibilityIsLoading) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  String loopLine(WidgetTester tester, int count) => _l10n(
    tester,
  ).videoFeedTotalLoopsLine(StringUtils.formatCompactNumber(count));

  group('video card meta line', () {
    testWidgets('shows OG Beta Tester for an eligible non-team member', (
      tester,
    ) async {
      await pump(tester, video: _video(), isOgDiviner: true);

      expect(find.byType(SpecialProfileCheckmark), findsNothing);
      expect(find.byType(OgBetaBadge), findsOneWidget);
    });

    testWidgets('hides OG Beta Tester until the lookup answers', (
      tester,
    ) async {
      await pump(tester, video: _video(), eligibilityIsLoading: true);

      // A lookup that has not answered, or failed and resolved to false, must
      // not put the chit on an account that has not earned it.
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets('hides OG Beta Tester behind the team checkmark', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(pubkey: kDivineTeamPubkeys.first),
        isOgDiviner: true,
      );

      // Team members can also be eligible beta testers, so a name would
      // otherwise carry two chits.
      expect(find.byType(SpecialProfileCheckmark), findsOneWidget);
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets("shows the author lifetime total, not this video's count", (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}),
        authorTotalLoops: 23200000,
      );

      // The card reports the author's body of work, so the per-video view tag
      // is ignored even when it is large.
      expect(find.textContaining(loopLine(tester, 23200000)), findsOneWidget);
      expect(find.textContaining(loopLine(tester, 50000)), findsNothing);
    });

    testWidgets('shows a small lifetime total', (tester) async {
      // The "Total loops:" label makes even a small number read as data, so
      // there is no floor hiding it.
      await pump(
        tester,
        video: _video(rawTags: {'views': '7'}),
        authorTotalLoops: 7,
      );

      expect(find.textContaining(loopLine(tester, 7)), findsOneWidget);
    });

    testWidgets('shows a zero lifetime total', (tester) async {
      await pump(tester, video: _video(), authorTotalLoops: 0);

      expect(find.textContaining(loopLine(tester, 0)), findsOneWidget);
    });

    testWidgets('shows a large lifetime total', (tester) async {
      await pump(tester, video: _video(), authorTotalLoops: 10000);

      expect(find.textContaining(loopLine(tester, 10000)), findsOneWidget);
    });

    testWidgets('hides the line while the total is unknown', (tester) async {
      await pump(tester, video: _video(rawTags: {'views': '50000'}));

      expect(find.textContaining(loopLine(tester, 50000)), findsNothing);
    });

    testWidgets('hides the line when a cached row has no total yet', (
      tester,
    ) async {
      // Follower counts are cached on their own, so a stats row can exist
      // before its total does. With no floor, the known-total flag is the only
      // thing keeping that placeholder zero off the card.
      await pump(
        tester,
        video: _video(),
        authorTotalLoops: 0,
        authorTotalKnown: false,
      );

      expect(
        find.text(UserProfile.generatedNameFor(_authorPubkey)),
        findsOneWidget,
      );
      expect(find.textContaining(loopLine(tester, 0)), findsNothing);
    });

    testWidgets('never shows the post date, even beside a count', (
      tester,
    ) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}),
        authorTotalLoops: 50000,
      );

      expect(find.textContaining(_l10n(tester).timeVerboseNow), findsNothing);
      expect(find.textContaining(loopLine(tester, 50000)), findsOneWidget);
    });

    testWidgets('the author node is a labelled button that opens the profile', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // Without the date there is no text left to merge into the author
      // gesture's own node, so the row only stays labelled if the annotated
      // node is the one carrying the action.
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}),
        authorTotalLoops: 50000,
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      final node = tester.getSemantics(
        find.bySemanticsIdentifier('video_author_name'),
      );
      final data = node.getSemanticsData();
      expect(node.label, isNotEmpty);
      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'the labelled node must be the one that opens the profile',
      );
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });
}
