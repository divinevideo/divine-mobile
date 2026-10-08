// ABOUTME: Widget tests for the viewer-selected video metadata line.
// ABOUTME: Pins independent creator/video/date settings and the author node.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

String _metaLine(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('video_meta_line')))
    .textSpan!
    .toPlainText();

VideoEvent _video({
  String pubkey = _authorPubkey,
  String authorName = 'Kayl',
  Map<String, String> rawTags = const {},
  int? createdAt,
  String? publishedAt,
}) {
  final at = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'video-card-meta-line-test-0123456789abcdef0123456789abcdef0123',
    pubkey: pubkey,
    createdAt: at,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
    rawTags: rawTags,
    publishedAt: publishedAt,
    authorName: authorName,
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

    when(() => mockInteractionsBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockInteractionsBloc.state)
        .thenReturn(const VideoInteractionsState());
    when(
      () => mockRepostsRepository.fetchEventReposters(
        eventId: any(named: 'eventId'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => const <String>[]);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_strangerPubkey);
    when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(() => mockAuthService.authStateStream)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() => authStateController.close());

  /// Pumps the overlay for [video]. [authorTotalLoops] is the author's lifetime
  /// loop total; null means the stats are not known yet.
  Future<void> pump(
    WidgetTester tester, {
    required VideoEvent video,
    int? authorTotalLoops,
    bool isOgDiviner = false,
    bool eligibilityIsLoading = false,
    SharedPreferences? prefs,
    void Function()? onAuthorStatsLookup,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        mockSharedPreferences: prefs,
        additionalOverrides: [
          repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          authServiceProvider.overrideWithValue(mockAuthService),
          ogDivinerEligibilityProvider.overrideWith(
            eligibilityIsLoading
                ? (ref, pubkey) => Completer<bool>().future
                : (ref, pubkey) async => isOgDiviner && pubkey == video.pubkey,
          ),
          videoCardAuthorStatsProvider(video.pubkey).overrideWith((ref) {
            onAuthorStatsLookup?.call();
            return authorTotalLoops == null
                ? const Stream<ProfileStats?>.empty()
                : Stream.value(
                    ProfileStats(
                      pubkey: video.pubkey,
                      totalViews: authorTotalLoops,
                    ),
                  );
          }),
        ],
        child: MaterialApp(
          locale: locale,
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

  String loopLine(WidgetTester tester, int count) => _l10n(tester)
      .videoFeedLoopCountLine(StringUtils.formatCompactNumber(count), count);

  String totalLine(WidgetTester tester, int count) => _l10n(tester)
      .videoOverlayTotalLoops(StringUtils.formatCompactNumber(count), count);

  String totalScope(WidgetTester tester, int count) =>
      _l10n(tester)
          .videoOverlayTotalLoopsScope(StringUtils.formatCompactNumber(count));

  group('video card meta line', () {
    testWidgets('shows all enabled details on one line under the username', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: true,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await withClock(Clock(() => DateTime.utc(2026, 9, 30)), () async {
        await pump(
          tester,
          video: _video(rawTags: {'views': '3'}, createdAt: 1790726400),
          authorTotalLoops: 78600,
          prefs: prefs,
        );
      });

      final line = tester.widget<Text>(
        find.byKey(const Key('video_meta_line')),
      );
      final content = _metaLine(tester);
      expect(content, contains('3 loops'));
      expect(content, contains('78.6K all-time'));
      expect(content, contains('Sep 30'));
      expect(content, contains('\u2009·\u2009'));
      expect(content.indexOf('3 loops'), lessThan(content.indexOf('78.6K')));
      expect(content.indexOf('78.6K'), lessThan(content.indexOf('Sep 30')));
      expect(line.maxLines, 1);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const Key('video_meta_line')),
          matching: find.byType(RichText),
        ),
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason:
            'available=${paragraph.constraints.maxWidth}, content=${paragraph.getMaxIntrinsicWidth(1000)}',
      );
      expect(
        tester.getRect(find.byKey(const Key('video_meta_line'))).right,
        lessThanOrEqualTo(
          tester.getRect(find.byType(VideoOverlayActionColumn)).left,
        ),
      );
    });

    testWidgets('shows video loops without looking up a disabled total', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      var lookups = 0;
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}, createdAt: 1735689600),
        authorTotalLoops: 23200000,
        prefs: prefs,
        onAuthorStatsLookup: () => lookups++,
      );

      expect(_metaLine(tester), loopLine(tester, 50000));
      expect(lookups, 0);
    });

    testWidgets('uses the singular for a video that looped once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '1'}, createdAt: 1735689600),
        prefs: prefs,
      );

      final content = _metaLine(tester);
      expect(content, _l10n(tester).videoFeedLoopCountLine('1', 1));
      expect(content, '1 loop');
    });

    testWidgets('emphasizes each count and not the surrounding copy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: true,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '5'}, createdAt: 1735689600),
        authorTotalLoops: 123,
        prefs: prefs,
        locale: const Locale('ja'),
      );

      final spans = <TextSpan>[];
      tester
          .widget<Text>(find.byKey(const Key('video_meta_line')))
          .textSpan!
          .visitChildren((span) {
            if (span is TextSpan && span.text != null) spans.add(span);
            return true;
          });
      final emphasized = spans
          .where((span) => span.style?.fontWeight == FontWeight.w600)
          .map((span) => span.text)
          .toList();
      final ja = lookupAppLocalizations(const Locale('ja'));

      expect(_metaLine(tester), contains(ja.videoFeedLoopCountLine('5', 5)));
      expect(
        _metaLine(tester),
        contains(ja.videoOverlayTotalLoopsScope('123')),
      );
      // Only the two counts carry the heavy weight; the scope word and the
      // plural noun stay in the lighter style.
      expect(emphasized, ['5', '123']);
    });

    testWidgets('uses the singular for a creator total of one loop', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: true,
        StatsVisibilityPreferences.showVideoLoopsKey: false,
        StatsVisibilityPreferences.showPublishedDateKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '1'}, createdAt: 1735689600),
        authorTotalLoops: 1,
        prefs: prefs,
      );

      expect(_metaLine(tester), totalLine(tester, 1));
      expect(_metaLine(tester), '1 all-time loop');
    });

    testWidgets('shows only the publish date when it alone is enabled', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: false,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}, createdAt: 1735689600),
        authorTotalLoops: 23200000,
        prefs: prefs,
      );

      expect(_metaLine(tester), '1/1/2025');
    });

    testWidgets('uses a short, readable date for a video from this year', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: false,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final published = DateTime.utc(2026, 1, 15);
      await withClock(Clock(() => DateTime.utc(2026, 9, 30)), () async {
        await pump(
          tester,
          video: _video(createdAt: published.millisecondsSinceEpoch ~/ 1000),
          prefs: prefs,
        );

        expect(_metaLine(tester), 'Jan 15');
      });
    });

    testWidgets('shows no line when every setting is disabled', (tester) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: false,
        StatsVisibilityPreferences.showPublishedDateKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}, createdAt: 1735689600),
        authorTotalLoops: 23200000,
        prefs: prefs,
      );

      expect(find.byKey(const Key('video_meta_line')), findsNothing);
    });

    testWidgets('omits unavailable values even when enabled', (tester) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: true,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'platform': 'vine'}, createdAt: 1735689600),
        authorTotalLoops: 0,
        prefs: prefs,
      );

      expect(find.byKey(const Key('video_meta_line')), findsNothing);
    });

    testWidgets('uses a valid published date when creation time is unknown', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: false,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(createdAt: 0, publishedAt: '1735689600'),
        prefs: prefs,
      );

      expect(find.text('1/1/2025'), findsOneWidget);
    });

    testWidgets('keeps the details on one line on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: true,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}, createdAt: 1735689600),
        authorTotalLoops: 23200000,
        prefs: prefs,
      );

      final line = find.byKey(const Key('video_meta_line'));
      expect(tester.widget<Row>(line).mainAxisSize, MainAxisSize.min);
      expect(
        find.descendant(of: line, matching: find.text('1/1/2025')),
        findsOneWidget,
      );
      expect(
        tester.getRect(line).right,
        lessThanOrEqualTo(
          tester.getRect(find.byType(VideoOverlayActionColumn)).left,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the video count and date visible for a long name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: true,
        StatsVisibilityPreferences.showVideoLoopsKey: true,
        StatsVisibilityPreferences.showPublishedDateKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await withClock(Clock(() => DateTime.utc(2026, 9, 30)), () async {
        await pump(
          tester,
          video: _video(
            authorName: 'AnExtraordinarilyLongCreatorName',
            rawTags: {'views': '3'},
            createdAt: 1790726400,
          ),
          authorTotalLoops: 78600,
          prefs: prefs,
        );
      });

      final content = _metaLine(tester);
      expect(content, contains(loopLine(tester, 3)));
      expect(content, contains('Sep 30'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('adds and removes each field while the video stays mounted', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StatsVisibilityPreferences.showTotalLoopsKey: false,
        StatsVisibilityPreferences.showVideoLoopsKey: false,
        StatsVisibilityPreferences.showPublishedDateKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}, createdAt: 1735689600),
        authorTotalLoops: 23200000,
        prefs: prefs,
      );
      final settings = ProviderScope.containerOf(
        tester.element(find.byType(VideoOverlayActions)),
      ).read(statsVisibilityPreferencesProvider);

      await tester.runAsync(() => settings.setShowTotalLoops(true));
      await tester.pumpAndSettle();
      expect(find.textContaining(totalLine(tester, 23200000)), findsOneWidget);
      await tester.runAsync(() => settings.setShowVideoLoops(true));
      await tester.pump();
      expect(
        find.textContaining(
          '${loopLine(tester, 50000)}\u2009·\u2009${totalScope(tester, 23200000)}',
        ),
        findsOneWidget,
      );
      await tester.runAsync(() => settings.setShowPublishedDate(true));
      await tester.pump();
      expect(find.textContaining('1/1/2025'), findsOneWidget);
      await tester.runAsync(() => settings.setShowTotalLoops(false));
      await tester.pump();
      expect(find.textContaining('all-time'), findsNothing);
      expect(find.textContaining(loopLine(tester, 50000)), findsOneWidget);
    });

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

      // Video loops are off by default, so only the creator total appears.
      expect(find.textContaining(totalLine(tester, 23200000)), findsOneWidget);
      expect(find.textContaining(loopLine(tester, 50000)), findsNothing);
    });

    testWidgets('hides the line when the viewer turns total loops off', (
      tester,
    ) async {
      final prefs = MockSharedPreferences();
      when(() => prefs.getBool(any())).thenReturn(false);
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}),
        authorTotalLoops: 50000,
        prefs: prefs,
      );

      expect(find.textContaining(totalLine(tester, 50000)), findsNothing);
    });

    testWidgets('follows the total-loops setting while mounted', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pump(
        tester,
        video: _video(),
        authorTotalLoops: 50000,
        prefs: prefs,
      );
      final settings = ProviderScope.containerOf(
        tester.element(find.byType(VideoOverlayActions)),
      ).read(statsVisibilityPreferencesProvider);
      expect(find.textContaining(totalLine(tester, 50000)), findsOneWidget);

      await tester.runAsync(() => settings.setShowTotalLoops(false));
      await tester.pump();
      expect(find.textContaining(totalLine(tester, 50000)), findsNothing);

      await tester.runAsync(() => settings.setShowTotalLoops(true));
      await tester.pumpAndSettle();
      expect(find.textContaining(totalLine(tester, 50000)), findsOneWidget);
    });

    testWidgets('skips the author stats lookup while total loops are off', (
      tester,
    ) async {
      final prefs = MockSharedPreferences();
      when(() => prefs.getBool(any())).thenReturn(false);
      var lookups = 0;
      await pump(
        tester,
        video: _video(),
        authorTotalLoops: 50000,
        prefs: prefs,
        onAuthorStatsLookup: () => lookups++,
      );

      expect(lookups, equals(0));
    });

    testWidgets('looks up the author stats when total loops are on', (
      tester,
    ) async {
      var lookups = 0;
      await pump(
        tester,
        video: _video(),
        authorTotalLoops: 50000,
        onAuthorStatsLookup: () => lookups++,
      );

      expect(lookups, equals(1));
      expect(find.textContaining(totalLine(tester, 50000)), findsOneWidget);
    });

    testWidgets('hides a zero lifetime total', (tester) async {
      await pump(tester, video: _video(), authorTotalLoops: 0);

      expect(find.textContaining(totalLine(tester, 0)), findsNothing);
    });

    testWidgets('shows the author lifetime total', (tester) async {
      await pump(tester, video: _video(), authorTotalLoops: 10000);

      expect(find.textContaining(totalLine(tester, 10000)), findsOneWidget);
    });

    testWidgets('hides the line while the total is unknown', (tester) async {
      await pump(tester, video: _video(rawTags: {'views': '50000'}));

      expect(find.textContaining(totalLine(tester, 50000)), findsNothing);
    });

    testWidgets('hides the publish date by default', (tester) async {
      await pump(
        tester,
        video: _video(rawTags: {'views': '50000'}, createdAt: 1735689600),
        authorTotalLoops: 50000,
      );

      expect(find.textContaining('1/1/2025'), findsNothing);
      expect(find.textContaining(totalLine(tester, 50000)), findsOneWidget);
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
      expect(
        tester.getRect(find.bySemanticsIdentifier('video_author_name')).width,
        lessThan(200),
      );
      handle.dispose();
    });
  });
}
