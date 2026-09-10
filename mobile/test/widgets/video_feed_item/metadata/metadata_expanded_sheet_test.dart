// ABOUTME: Tests for MetadataExpandedSheet and all metadata section widgets.
// ABOUTME: Verifies each section renders when data is present and hides when
// ABOUTME: data is absent. Covers badges, title, stats, creator, tags,
// ABOUTME: collaborators, inspired by, reposted by, and sounds sections.

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_badges_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_sounds_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_stats_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_tags_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_user_chips.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_verification_info_sheet.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_verification_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/upload_explainer_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../helpers/test_provider_overrides.dart';
import '../../../helpers/url_launcher_test_double.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockVideoRepostersCubit extends Mock implements VideoRepostersCubit {}

class _MockVideosRepository extends Mock implements VideosRepository {}

// Stable 64-char hex pubkeys for deterministic tests.
const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaborator1 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collaborator2 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _inspiredByPubkey =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _reposterPubkey =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _audioPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _audioEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _parentEventId =
    '32e8069cb2f468548236bf743563bfd930b96fe2e5731a4b2f58e38d24df82b2';
const _parentAddressableId =
    '34236:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:parent-d-tag';

/// Chips dimmed by [Opacity]. Deliberately ignores fully opaque wrappers so
/// the assertion means "nothing is dimmed" rather than "nothing anywhere
/// uses Opacity".
Finder _dimmed() =>
    find.byWidgetPredicate((widget) => widget is Opacity && widget.opacity < 1);

/// Placeholder pills painted by `Skeletonizer` while chip names resolve.
Finder _skeletonChips() =>
    find.byWidgetPredicate((widget) => widget is Skeleton);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

UserProfile _makeProfile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  name: name.toLowerCase(),
  rawData: const {},
  createdAt: DateTime(2025),
  eventId: 'evt_$pubkey',
);

VideoEvent _makeVideo({
  String id =
      'test_video_id_00000000000000000000000000000000000000000000000000',
  List<String> hashtags = const [],
  List<String> categories = const [],
  List<String> collaboratorPubkeys = const [],
  InspiredByInfo? inspiredByVideo,
  List<String>? reposterPubkeys,
  int? nostrRepostCount,
  String? audioEventId,
  String? title,
  String content = '',
  Map<String, String> rawTags = const {},
  int originalLoops = 1500,
  int createdAt = 1700000000,
  String? publishedAt,
  List<List<String>> nostrEventTags = const [],
}) => VideoEvent(
  id: id,
  pubkey: _creatorPubkey,
  createdAt: createdAt,
  content: content,
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
  title: title,
  videoUrl: 'https://example.com/video.mp4',
  hashtags: hashtags,
  categories: categories,
  collaboratorPubkeys: collaboratorPubkeys,
  inspiredByVideo: inspiredByVideo,
  reposterPubkeys: reposterPubkeys,
  nostrRepostCount: nostrRepostCount,
  audioEventId: audioEventId,
  originalLoops: originalLoops,
  rawTags: rawTags,
  publishedAt: publishedAt,
  nostrEventTags: nostrEventTags,
);

final _testAudio = AudioEvent(
  id: _audioEventId,
  pubkey: _audioPubkey,
  createdAt: 1700000000,
  title: 'Test Sound',
  source: 'Test Artist',
  url: 'https://example.com/audio.aac',
);

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late _MockVideoRepostersCubit mockRepostersCubit;
  late _MockVideosRepository mockVideosRepository;
  late UrlLauncherPlatform originalUrlLauncherPlatform;
  late UrlLauncherTestDouble urlLauncher;

  setUp(() {
    originalUrlLauncherPlatform = UrlLauncherPlatform.instance;
    urlLauncher = UrlLauncherTestDouble();
    UrlLauncherPlatform.instance = urlLauncher;

    mockVideosRepository = _MockVideosRepository();
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockInteractionsBloc.state).thenReturn(
      const VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        likeCount: 250,
        commentCount: 42,
        repostCount: 15,
      ),
    );

    mockRepostersCubit = _MockVideoRepostersCubit();
    when(
      () => mockRepostersCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockRepostersCubit.state,
    ).thenReturn(const VideoRepostersState(isLoading: false));
    when(() => mockRepostersCubit.close()).thenAnswer((_) async {});
    when(
      () => mockVideosRepository.fetchVideoWithStatsForRouteId(any()),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncherPlatform;
  });

  /// Pumps a metadata widget inside the required provider tree.
  Widget buildSubject({
    required Widget child,
    List<Override> providerOverrides = const [],
    VideoRepostersState? repostersState,
  }) {
    if (repostersState != null) {
      when(() => mockRepostersCubit.state).thenReturn(repostersState);
    }

    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            createMockSharedPreferences(),
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          ...providerOverrides,
        ],
      ),
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
              ),
              BlocProvider<VideoRepostersCubit>.value(
                value: mockRepostersCubit,
              ),
            ],
            child: child,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Overview section
  // ---------------------------------------------------------------------------
  group('_OverviewSection (via $MetadataExpandedSheet)', () {
    testWidgetsWithSurfaceSize(
      'renders fetched parent context for a video reply',
      (tester) async {
        final video = _makeVideo(
          title: 'Comment video',
          rawTags: const {
            'A': _parentAddressableId,
            'E': _parentEventId,
            'K': '34236',
            'a': _parentAddressableId,
          },
          inspiredByVideo: const InspiredByInfo(
            addressableId: _parentAddressableId,
          ),
        );
        final parentVideo = _makeVideo(
          title: 'Original cat video',
          content: 'where the reply belongs',
        );
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            _parentAddressableId,
          ),
        ).thenAnswer((_) async => parentVideo);

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('In reply to'), findsOneWidget);
        expect(find.text('Reply to Original cat video'), findsOneWidget);
        expect(find.textContaining('Inspired by'), findsNothing);
        verify(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            _parentAddressableId,
          ),
        ).called(1);
      },
    );

    testWidgetsWithSurfaceSize('renders title and description when present', (
      tester,
    ) async {
      final video = _makeVideo(title: 'Who knew?', content: 'A description');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      expect(find.text('Who knew?'), findsOneWidget);
      expect(find.text('A description'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('renders description with clickable rich text', (
      tester,
    ) async {
      final video = _makeVideo(
        title: 'Who knew?',
        content: 'Read more at https://example.com/docs #proof',
      );

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      expect(find.text('Who knew?'), findsOneWidget);
      expect(find.byType(LinkifiedText), findsNWidgets(2));
    });

    testWidgetsWithSurfaceSize('renders title with clickable rich text', (
      tester,
    ) async {
      final video = _makeVideo(title: '@shutupphia FOLLOW HER');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      expect(find.text('@shutupphia FOLLOW HER'), findsOneWidget);
      expect(find.byType(LinkifiedText), findsOneWidget);
    });

    testWidgetsWithSurfaceSize(
      'still renders the section without title or description',
      (tester) async {
        final video = _makeVideo();

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );

        // Stats row is always visible.
        expect(find.byType(MetadataStatsRow), findsOneWidget);
        // The title text must not appear since the video has no title.
        expect(find.text('Who knew?'), findsNothing);
        // The date renders even with no title or description. The visible
        // text is just the date — "Posted on …" is the screen-reader label.
        final expectedDate = DateFormat.yMMMMd('en').format(
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
        );
        expect(find.text(expectedDate), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize('renders posted date for a recent post', (
      tester,
    ) async {
      final video = _makeVideo(title: 'Who knew?', content: 'A description');

      await tester.pumpWidget(
        buildSubject(child: MetadataExpandedSheet(video: video)),
      );

      final expectedDate = DateFormat.yMMMMd('en').format(
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
      expect(find.text(expectedDate), findsOneWidget);
    });

    testWidgetsWithSurfaceSize(
      'prefers published_at for the visible posted date',
      (tester) async {
        const publishedAt = 1700604800;
        final video = _makeVideo(
          title: 'Who knew?',
          content: 'A description',
          publishedAt: '$publishedAt',
        );

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );

        final expectedDate = DateFormat.yMMMMd('en').format(
          DateTime.fromMillisecondsSinceEpoch(publishedAt * 1000, isUtc: true),
        );
        expect(find.text(expectedDate), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'hides posted date when an original Vine has no original date',
      (tester) async {
        const importedAt = 1777489813;
        final video = _makeVideo(
          id: '0e5e24db5148c7eda48b874dd44d5365071020e131a4f399f3ea6c7b996d3196',
          title: 'Classic vine',
          content: 'From the archive',
          createdAt: importedAt,
          rawTags: {'platform': 'vine'},
        );

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );

        final importedDate = DateFormat.yMMMMd('en').format(
          DateTime.fromMillisecondsSinceEpoch(importedAt * 1000, isUtc: true),
        );
        expect(find.text(importedDate), findsNothing);
        expect(find.text('Classic vine'), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'renders farewell-day date when original Vine has a published_at tag',
      (tester) async {
        const publishedAt = 1484627482;
        final video = _makeVideo(
          title: 'Final vine',
          content: 'Thanks for everything',
          createdAt: 1777489813,
          publishedAt: '$publishedAt',
          rawTags: const {'platform': 'vine', 'published_at': '1484627482'},
        );

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );

        final expectedDate = DateFormat.yMMMMd('en').format(
          DateTime.fromMillisecondsSinceEpoch(publishedAt * 1000, isUtc: true),
        );
        expect(find.text(expectedDate), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'renders Vine-era date for a classic vine timestamp',
      (tester) async {
        // 2012-12-11 21:38 UTC — a classic Vine-era timestamp.
        final video = _makeVideo(
          title: 'Classic vine',
          content: 'From the archives',
          createdAt: 1355261891,
        );

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );

        // Year 2012 must be visible regardless of locale-specific month name.
        expect(find.textContaining('2012'), findsWidgets);
      },
    );

    testWidgetsWithSurfaceSize(
      'applies labelSmall typography with onSurfaceVariant color',
      (tester) async {
        final video = _makeVideo(title: 'Who knew?');

        await tester.pumpWidget(
          buildSubject(child: MetadataExpandedSheet(video: video)),
        );

        final expectedDate = DateFormat.yMMMMd('en').format(
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
        );
        final dateText = tester.widget<Text>(find.text(expectedDate));
        expect(dateText.style?.fontSize, equals(11));
        expect(dateText.style?.fontWeight, equals(FontWeight.w600));
        expect(dateText.style?.color, equals(VineTheme.onSurfaceVariant));
      },
    );

    testWidgetsWithSurfaceSize(
      'wraps the date in a Semantics with the localized label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final video = _makeVideo(title: 'Who knew?');

          await tester.pumpWidget(
            buildSubject(child: MetadataExpandedSheet(video: video)),
          );

          final expectedDate = DateFormat.yMMMMd('en').format(
            DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
          );
          final l10n = _l10n(tester);
          final node = tester.getSemantics(find.text(expectedDate));
          expect(
            node.label,
            contains(l10n.metadataPostedDateSemantics(expectedDate)),
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------
  group(MetadataStatsRow, () {
    testWidgetsWithSurfaceSize('renders all four stat columns with counts', (
      tester,
    ) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataStatsRow(video: video)),
      );

      expect(find.text('1.5K'), findsOneWidget); // originalLoops
      expect(find.text('250'), findsOneWidget); // likeCount
      expect(find.text('42'), findsOneWidget); // commentCount
      expect(find.text('15'), findsOneWidget); // repostCount
      final l10n = _l10n(tester);
      expect(
        find.text(l10n.metadataLoopsLabel(video.totalLoops)),
        findsOneWidget,
      );
      expect(find.text(l10n.metadataLikesLabel), findsOneWidget);
      expect(find.text(l10n.metadataCommentsLabel), findsOneWidget);
      expect(find.text(l10n.metadataRepostsLabel), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('uses singular Loop label when count is 1', (
      tester,
    ) async {
      final video = _makeVideo(originalLoops: 1);

      await tester.pumpWidget(
        buildSubject(child: MetadataStatsRow(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataLoopsLabel(1)), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('shows dash when loading', (tester) async {
      when(() => mockInteractionsBloc.state).thenReturn(
        const VideoInteractionsState(status: VideoInteractionsStatus.loading),
      );

      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataStatsRow(video: video)),
      );

      // Likes, Comments, Reposts show dash; Loops is static.
      expect(find.text('—'), findsNWidgets(3));
    });

    testWidgetsWithSurfaceSize(
      'shows Vine and Divine breakdown for classic Vines',
      (tester) async {
        // Combined display counts in the mock bloc state are 250/42/15;
        // the archival baselines below leave 50/12/5 as the Divine share.
        final video = _makeVideo(
          rawTags: const {'platform': 'vine', 'views': '3020'},
        ).copyWith(originalLikes: 200, originalComments: 30);

        await tester.pumpWidget(
          buildSubject(
            child: MetadataStatsRow(video: video.copyWith(originalReposts: 10)),
          ),
        );

        final l10n = _l10n(tester);
        expect(find.text(l10n.metadataVineStatsLabel), findsOneWidget);
        expect(
          find.text(l10n.metadataVineStatsLine('1.5K', '200', '30', '10')),
          findsOneWidget,
        );
        expect(find.text(l10n.metadataDivineStatsLabel), findsOneWidget);
        expect(
          find.text(l10n.metadataDivineStatsLine('3.02K', '50', '12', '5')),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithSurfaceSize(
      'falls back to live nostr counts in the breakdown while loading',
      (tester) async {
        when(() => mockInteractionsBloc.state).thenReturn(
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
        );

        final video = _makeVideo(
          rawTags: const {'platform': 'vine', 'views': '3020'},
        ).copyWith(originalLikes: 200, nostrLikeCount: 50);

        await tester.pumpWidget(
          buildSubject(child: MetadataStatsRow(video: video)),
        );

        final l10n = _l10n(tester);
        expect(
          find.text(l10n.metadataDivineStatsLine('3.02K', '50', '0', '0')),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithSurfaceSize(
      'hides the per-source breakdown for non-Vine videos',
      (tester) async {
        final video = _makeVideo();

        await tester.pumpWidget(
          buildSubject(child: MetadataStatsRow(video: video)),
        );

        final l10n = _l10n(tester);
        expect(find.text(l10n.metadataVineStatsLabel), findsNothing);
        expect(find.text(l10n.metadataDivineStatsLabel), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Creator section
  // ---------------------------------------------------------------------------
  group(MetadataCreatorSection, () {
    testWidgetsWithSurfaceSize('renders creator chip with profile name', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_creatorPubkey).overrideWith(
              (ref) async => _makeProfile(_creatorPubkey, 'Sebastian Heit'),
            ),
          ],
          child: const MetadataCreatorSection(pubkey: _creatorPubkey),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creator'), findsOneWidget);
      expect(find.text('Sebastian Heit'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Badges row
  // ---------------------------------------------------------------------------
  group(MetadataBadgesRow, () {
    testWidgetsWithSurfaceSize('renders Human-Made badge when hasProofMode', (
      tester,
    ) async {
      final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.textContaining(l10n.metadataBadgeHumanMade), findsOneWidget);
    });

    testWidgetsWithSurfaceSize(
      'renders the divine-mark icon next to the Human-Made label',
      (tester) async {
        final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
        await tester.pumpWidget(
          buildSubject(child: MetadataBadgesRow(video: video)),
        );

        final l10n = _l10n(tester);
        expect(
          find.textContaining(l10n.metadataBadgeHumanMade),
          findsOneWidget,
        );
        final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(icon.icon, equals(DivineIconName.divineMark));
      },
    );

    testWidgetsWithSurfaceSize('renders Not Divine badge for external videos', (
      tester,
    ) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      // Default test video URL is example.com (not Divine hosted)
      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataBadgeNotDivine), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('renders both badges with dot separator', (
      tester,
    ) async {
      // hasProofMode but not Divine hosted
      final video = _makeVideo(rawTags: {'verification': 'verified_web'});
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      // ProofMode badge shows but shouldShowNotDivineBadge is false
      // (hasProofMode suppresses Not Divine badge)
      final l10n = _l10n(tester);
      expect(find.textContaining(l10n.metadataBadgeHumanMade), findsOneWidget);
      expect(find.text(l10n.metadataBadgeNotDivine), findsNothing);
    });

    testWidgetsWithSurfaceSize('hides when no badges apply', (tester) async {
      // Divine-hosted video with no proof → no badges
      // (isFromDivineServer = true, so Not Divine hidden; no proof = no HM)
      final video = VideoEvent(
        id: 'test_video_id_0000000000000000000000000000000000000000000000000',
        pubkey: _creatorPubkey,
        createdAt: 1700000000,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        videoUrl: 'https://media.divine.video/test/720p.mp4',
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataBadgesRow(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataBadgeHumanMade), findsNothing);
      expect(find.text(l10n.metadataBadgeNotDivine), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Tags section
  // ---------------------------------------------------------------------------
  group(MetadataTagsSection, () {
    testWidgetsWithSurfaceSize('renders hashtag chips when tags exist', (
      tester,
    ) async {
      final video = _makeVideo(hashtags: ['sick', 'cool', 'baller']);
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      // Tags section has no label per Figma spec — only chip text.
      expect(find.text('sick'), findsOneWidget);
      expect(find.text('cool'), findsOneWidget);
      expect(find.text('baller'), findsOneWidget);
      expect(find.text('#'), findsNWidgets(3));
    });

    testWidgetsWithSurfaceSize('prepends classic hashtag for original Vine', (
      tester,
    ) async {
      final video = _makeVideo(rawTags: {'platform': 'vine'});
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      expect(find.text('classic'), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('renders classic and hashtags together', (
      tester,
    ) async {
      final video = _makeVideo(
        hashtags: ['grease'],
        rawTags: {'platform': 'vine'},
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      expect(find.text('classic'), findsOneWidget);
      expect(find.text('grease'), findsOneWidget);
      // "classic" + "grease" = 2 hashtag chips
      expect(find.text('#'), findsNWidgets(2));
    });

    testWidgetsWithSurfaceSize('hides when no hashtags and not Classic', (
      tester,
    ) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      // No hashtag chips should appear.
      expect(find.text('#'), findsNothing);
    });

    testWidgetsWithSurfaceSize('renders category chips with accent colors', (
      tester,
    ) async {
      final video = _makeVideo(
        categories: ['animals', 'music'],
        hashtags: ['cool'],
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      // Category chips show display name and emoji
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('🐾'), findsOneWidget);
      expect(find.text('🎸'), findsOneWidget);
      // Hashtag chip still present
      expect(find.text('cool'), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('renders only categories when no hashtags', (
      tester,
    ) async {
      final video = _makeVideo(categories: ['sports']);
      await tester.pumpWidget(
        buildSubject(child: MetadataTagsSection(video: video)),
      );

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('🏆'), findsOneWidget);
      expect(find.text('#'), findsNothing);
    });

    testWidgetsWithSurfaceSize(
      'hashtag chip exposes a tappable button affordance',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final video = _makeVideo(hashtags: ['comedy']);
          await tester.pumpWidget(
            buildSubject(child: MetadataTagsSection(video: video)),
          );

          // The chip is wrapped in Semantics(button: true) plus a
          // GestureDetector with a non-null onTap — proving the tap target
          // is wired. The actual navigation is exercised by
          // HashtagScreenRouter's own tests.
          final node = tester.getSemantics(find.text('comedy'));
          expect(node.label, contains('comedy'));

          final gesture = tester.widgetList<GestureDetector>(
            find.ancestor(
              of: find.text('comedy'),
              matching: find.byType(GestureDetector),
            ),
          );
          expect(gesture, isNotEmpty);
          expect(gesture.first.onTap, isNotNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgetsWithSurfaceSize(
      'hashtag chip tap target meets the 48 dp WCAG minimum (visible '
      'chip stays 40 dp tall)',
      (tester) async {
        final video = _makeVideo(hashtags: ['comedy']);
        await tester.pumpWidget(
          buildSubject(child: MetadataTagsSection(video: video)),
        );

        // The GestureDetector wraps a Padding(vertical: 4) wrapping the
        // visible 40 dp chip — so the tap-target bounds are 48 dp tall
        // while the chip itself remains 40 dp tall.
        final gestureFinder = find.ancestor(
          of: find.text('comedy'),
          matching: find.byType(GestureDetector),
        );
        expect(tester.getSize(gestureFinder).height, equals(48));

        // The visible chip is the Container immediately above the
        // tag's Text — its bounds match the rendered 40 dp height.
        final containerFinder = find
            .ancestor(of: find.text('comedy'), matching: find.byType(Container))
            .first;
        expect(tester.getSize(containerFinder).height, equals(40));
      },
    );

    testWidgetsWithSurfaceSize(
      'hashtag chip Wrap uses runSpacing 0 (so chips own the inter-row '
      'gap via their invisible tap-target padding)',
      (tester) async {
        // The visible 8 dp gap between two rows of hashtag chips is
        // produced by each chip contributing 4 dp of transparent
        // padding above + 4 dp below (see `_HashtagChip`), NOT by
        // `Wrap.runSpacing`. Bumping runSpacing double-counts and
        // breaks the Figma layout. This test pins the contract so a
        // well-meaning "fix the gap" edit fails loudly.
        final video = _makeVideo(hashtags: ['a', 'b', 'c']);
        await tester.pumpWidget(
          buildSubject(child: MetadataTagsSection(video: video)),
        );

        final wrap = tester.widget<Wrap>(find.byType(Wrap));
        expect(
          wrap.runSpacing,
          equals(0.0),
          reason:
              'runSpacing must stay at 0 — the chips own the inter-row '
              'visible gap. See `_HashtagChip` for the full contract.',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Collaborators section
  // ---------------------------------------------------------------------------
  group(MetadataCollaboratorsSection, () {
    testWidgetsWithSurfaceSize('renders collaborator chips when present', (
      tester,
    ) async {
      final video = _makeVideo(
        collaboratorPubkeys: const [_collaborator1, _collaborator2],
      );
      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_collaborator1).overrideWith(
              (ref) async => _makeProfile(_collaborator1, 'Josh Musick'),
            ),
            fetchUserProfileProvider(_collaborator2).overrideWith(
              (ref) async => _makeProfile(_collaborator2, 'Dan Spurgin'),
            ),
          ],
          child: MetadataCollaboratorsSection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataCollaboratorsLabel), findsOneWidget);
      expect(find.text('Josh Musick'), findsOneWidget);
      expect(find.text('Dan Spurgin'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('hides when no collaborators', (tester) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataCollaboratorsSection(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataCollaboratorsLabel), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Collaborators section body (status-aware rendering)
  // ---------------------------------------------------------------------------
  group(MetadataCollaboratorsSectionBody, () {
    testWidgetsWithSurfaceSize(
      'fallback mode: renders all chips without Pending decoration',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(_collaborator1).overrideWith(
                (ref) async => _makeProfile(_collaborator1, 'Alice'),
              ),
              fetchUserProfileProvider(_collaborator2).overrideWith(
                (ref) async => _makeProfile(_collaborator2, 'Bob'),
              ),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility.fallback(
                taggedPubkeys: [_collaborator1, _collaborator2],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = _l10n(tester);
        expect(find.text(l10n.metadataCollaboratorsLabel), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(
          find.text(l10n.videoCollaboratorPendingDecoration),
          findsNothing,
        );
        expect(_dimmed(), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'inviter view: pending chip shows Pending label and is dimmed',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(_collaborator1).overrideWith(
                (ref) async => _makeProfile(_collaborator1, 'Alice'),
              ),
              fetchUserProfileProvider(_collaborator2).overrideWith(
                (ref) async => _makeProfile(_collaborator2, 'Bob'),
              ),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collaborator1, _collaborator2],
                statusByPubkey: {
                  _collaborator1: CollaboratorStatus.pending,
                  _collaborator2: CollaboratorStatus.confirmed,
                },
                currentUserPubkey: _creatorPubkey,
                creatorPubkey: _creatorPubkey,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = _l10n(tester);
        // Exactly one chip has the Pending label (Alice).
        expect(
          find.text(l10n.videoCollaboratorPendingDecoration),
          findsOneWidget,
        );
        // The pending chip is the only one wrapped in a dimming Opacity.
        final dimmed = tester.widgetList<Opacity>(_dimmed());
        expect(dimmed, hasLength(1));
        expect(dimmed.first.opacity, closeTo(0.7, 0.001));
      },
    );

    testWidgetsWithSurfaceSize(
      'recipient view (ignored): own chip filtered out',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(_collaborator1).overrideWith(
                (ref) async => _makeProfile(_collaborator1, 'Alice'),
              ),
              fetchUserProfileProvider(_collaborator2).overrideWith(
                (ref) async => _makeProfile(_collaborator2, 'Bob'),
              ),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collaborator1, _collaborator2],
                statusByPubkey: {
                  _collaborator1: CollaboratorStatus.ignored,
                  _collaborator2: CollaboratorStatus.confirmed,
                },
                currentUserPubkey: _collaborator1,
                creatorPubkey: _creatorPubkey,
                isResolved: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Alice (current user, ignored) is hidden; Bob is visible.
        expect(find.text('Alice'), findsNothing);
        expect(find.text('Bob'), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'recipient view (ignored, sole collaborator): section shrinks',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collaborator1],
                statusByPubkey: {_collaborator1: CollaboratorStatus.ignored},
                currentUserPubkey: _collaborator1,
                creatorPubkey: _creatorPubkey,
              ),
            ),
          ),
        );

        final l10n = _l10n(tester);
        expect(find.text(l10n.metadataCollaboratorsLabel), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'third-party view: confirmed chip renders with no Pending decoration',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(_collaborator1).overrideWith(
                (ref) async => _makeProfile(_collaborator1, 'Alice'),
              ),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collaborator1],
                statusByPubkey: {_collaborator1: CollaboratorStatus.confirmed},
                currentUserPubkey: _reposterPubkey,
                creatorPubkey: _creatorPubkey,
                isResolved: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = _l10n(tester);
        expect(find.text('Alice'), findsOneWidget);
        expect(
          find.text(l10n.videoCollaboratorPendingDecoration),
          findsNothing,
        );
        expect(_dimmed(), findsNothing);
      },
    );

    testWidgets(
      'third-party view: unconfirmed collaborator is not rendered',
      (tester) async {
        // Pre-#6907 a creator-tagged pubkey rendered here regardless of
        // whether they ever accepted, publicly crediting them.
        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(_collaborator1).overrideWith(
                (ref) async => _makeProfile(_collaborator1, 'Alice'),
              ),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility(
                taggedPubkeys: [_collaborator1],
                statusByPubkey: {_collaborator1: CollaboratorStatus.pending},
                currentUserPubkey: _reposterPubkey,
                creatorPubkey: _creatorPubkey,
                isResolved: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'reveals fallback names after the profile grace window',
      (tester) async {
        final profile = Completer<UserProfile?>();

        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(
                _collaborator1,
              ).overrideWith((ref) => profile.future),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility.fallback(
                taggedPubkeys: [_collaborator1],
              ),
            ),
          ),
        );
        await tester.pump();

        final l10n = _l10n(tester);
        expect(_skeletonChips(), findsNWidgets(1));
        expect(find.byType(UserAvatar), findsNothing);

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.text(l10n.metadataCollaboratorsLabel), findsOneWidget);
        expect(_skeletonChips(), findsNothing);

        profile.complete(_makeProfile(_collaborator1, 'Alice'));
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'holds the row open with one placeholder per tagged collaborator',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              for (final pubkey in [_collaborator1, _collaborator2])
                fetchUserProfileProvider(
                  pubkey,
                ).overrideWith((ref) => Completer<UserProfile?>().future),
            ],
            child: const MetadataCollaboratorsSectionBody(
              visibility: CollaboratorVisibility.fallback(
                taggedPubkeys: [_collaborator1, _collaborator2],
              ),
            ),
          ),
        );
        await tester.pump();

        // The tagged list is known synchronously, so the row can take its
        // final size while only the names are still in flight.
        expect(
          find.text(_l10n(tester).metadataCollaboratorsLabel),
          findsOneWidget,
        );
        expect(_skeletonChips(), findsNWidgets(2));
        expect(find.byType(UserAvatar), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Inspired By section
  // ---------------------------------------------------------------------------
  group(MetadataInspiredBySection, () {
    testWidgetsWithSurfaceSize('renders chip when inspired-by exists', (
      tester,
    ) async {
      final video = _makeVideo(
        inspiredByVideo: const InspiredByInfo(
          addressableId: '34236:$_inspiredByPubkey:some-dtag',
        ),
      );

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_inspiredByPubkey).overrideWith(
              (ref) async =>
                  _makeProfile(_inspiredByPubkey, 'Inspiring Creator'),
            ),
          ],
          child: MetadataInspiredBySection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inspired by'), findsOneWidget);
      expect(find.text('Inspiring Creator'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('hides when no inspired-by', (tester) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataInspiredBySection(video: video)),
      );

      expect(find.text('Inspired by'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Reposted By section
  // ---------------------------------------------------------------------------
  group(MetadataRepostedBySection, () {
    testWidgetsWithSurfaceSize(
      'holds the row open with one chip per known repost while loading',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(),
            child: MetadataRepostedBySection(
              video: _makeVideo(nostrRepostCount: 3),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text(_l10n(tester).metadataRepostedByLabel),
          findsOneWidget,
        );
        expect(_skeletonChips(), findsNWidgets(3));
        expect(find.byType(UserAvatar), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'reserves the more button placeholder for popular videos',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(),
            child: MetadataRepostedBySection(
              video: _makeVideo(nostrRepostCount: 4200),
            ),
          ),
        );
        await tester.pump();

        expect(_skeletonChips(), findsNWidgets(6));
      },
    );

    testWidgetsWithSurfaceSize(
      'keeps the more button space while fetched reposter names resolve',
      (tester) async {
        final reposterPubkeys = List.generate(
          7,
          (index) => (index + 1).toRadixString(16).padLeft(64, '0'),
        );

        await tester.pumpWidget(
          buildSubject(
            repostersState: VideoRepostersState(pubkeys: reposterPubkeys),
            providerOverrides: [
              for (final pubkey in reposterPubkeys.take(5))
                fetchUserProfileProvider(
                  pubkey,
                ).overrideWith((ref) => Completer<UserProfile?>().future),
            ],
            child: MetadataRepostedBySection(video: _makeVideo()),
          ),
        );
        await tester.pump();

        expect(
          find.text(_l10n(tester).metadataRepostedByLabel),
          findsOneWidget,
        );
        expect(_skeletonChips(), findsNWidgets(6));
        expect(find.byType(UserAvatar), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'stays hidden while loading when the feed knows of no reposts',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(),
            child: MetadataRepostedBySection(video: _makeVideo()),
          ),
        );
        await tester.pump();

        expect(find.text(_l10n(tester).metadataRepostedByLabel), findsNothing);
        expect(_skeletonChips(), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'stays hidden when the promised repost count is negative',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(),
            child: MetadataRepostedBySection(
              video: _makeVideo(nostrRepostCount: -1),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(_l10n(tester).metadataRepostedByLabel), findsNothing);
        expect(_skeletonChips(), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'drops the placeholders when the relay finds no reposters',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(isLoading: false),
            child: MetadataRepostedBySection(
              video: _makeVideo(nostrRepostCount: 3),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_l10n(tester).metadataRepostedByLabel), findsNothing);
        expect(_skeletonChips(), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize('renders reposters fetched from relay', (
      tester,
    ) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(
          repostersState: const VideoRepostersState(
            pubkeys: [_reposterPubkey],
            isLoading: false,
          ),
          providerOverrides: [
            fetchUserProfileProvider(_reposterPubkey).overrideWith(
              (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
            ),
          ],
          child: MetadataRepostedBySection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n(tester).metadataRepostedByLabel), findsOneWidget);
      expect(find.text('Improvising'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('renders pre-populated reposterPubkeys', (
      tester,
    ) async {
      final video = _makeVideo(reposterPubkeys: [_reposterPubkey]);

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_reposterPubkey).overrideWith(
              (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
            ),
          ],
          child: MetadataRepostedBySection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n(tester).metadataRepostedByLabel), findsOneWidget);
      expect(find.text('Improvising'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize(
      'caps the chips and offers the rest through the full list',
      (tester) async {
        final pubkeys = List<String>.generate(
          12,
          (index) => (index + 1).toRadixString(16).padLeft(64, '0'),
        );

        await tester.pumpWidget(
          buildSubject(
            repostersState: VideoRepostersState(
              pubkeys: pubkeys,
              isLoading: false,
            ),
            providerOverrides: [
              for (final pubkey in pubkeys)
                fetchUserProfileProvider(
                  pubkey,
                ).overrideWith((ref) async => null),
            ],
            child: MetadataRepostedBySection(video: _makeVideo()),
          ),
        );
        await tester.pumpAndSettle();

        // Every reposter would otherwise be a chip that fetches its own
        // profile — a popular video has thousands.
        expect(find.byType(UserAvatar), findsNWidgets(5));
        expect(
          find.text(_l10n(tester).metadataMoreReposters(7)),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithSurfaceSize(
      'the more-reposters button dismisses the sheet before navigating',
      (tester) async {
        final pubkeys = List<String>.generate(
          12,
          (index) => (index + 1).toRadixString(16).padLeft(64, '0'),
        );
        when(
          () => mockRepostersCubit.state,
        ).thenReturn(VideoRepostersState(pubkeys: pubkeys, isLoading: false));

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              createMockSharedPreferences(),
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            for (final pubkey in pubkeys)
              fetchUserProfileProvider(
                pubkey,
              ).overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider<VideoInteractionsBloc>.value(
                            value: mockInteractionsBloc,
                          ),
                          BlocProvider<VideoRepostersCubit>.value(
                            value: mockRepostersCubit,
                          ),
                        ],
                        child: MetadataRepostedBySection(video: _makeVideo()),
                      ),
                    ),
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/video/:eventId/reposters',
              name: VideoEngagementListScreen.repostersRouteName,
              builder: (context, state) =>
                  const Scaffold(body: Text('reposters list')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();

        final moreLabel = _l10n(tester).metadataMoreReposters(7);
        expect(
          find.text(_l10n(tester).metadataRepostedByLabel),
          findsOneWidget,
        );

        await tester.tap(find.text(moreLabel));
        await tester.pumpAndSettle();

        expect(find.text('reposters list'), findsOneWidget);

        // Every other destination in this sheet hands off the same way:
        // dismiss, then push from the root navigator. Pushing with the sheet
        // still mounted leaves it stacked over the list, so backing out of
        // the list drops the user onto the sheet again instead of the video.
        router.pop();
        await tester.pumpAndSettle();

        expect(find.text('open sheet'), findsOneWidget);
        expect(find.text(_l10n(tester).metadataRepostedByLabel), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'waits for the chip names before swapping the placeholders out',
      (tester) async {
        final profile = Completer<UserProfile?>();

        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(
              pubkeys: [_reposterPubkey],
              isLoading: false,
            ),
            providerOverrides: [
              fetchUserProfileProvider(
                _reposterPubkey,
              ).overrideWith((ref) => profile.future),
            ],
            child: MetadataRepostedBySection(video: _makeVideo()),
          ),
        );
        await tester.pump();

        // A chip falls back to a generated name while its profile loads.
        // Showing the real chips first would swap every label a moment later
        // and reflow the rows around the new widths, so a placeholder of the
        // known size stands in.
        expect(
          find.text(_l10n(tester).metadataRepostedByLabel),
          findsOneWidget,
        );
        expect(_skeletonChips(), findsNWidgets(1));
        expect(find.byType(UserAvatar), findsNothing);

        profile.complete(_makeProfile(_reposterPubkey, 'Improvising'));
        await tester.pumpAndSettle();

        expect(find.text('Improvising'), findsOneWidget);
        expect(_skeletonChips(), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'reveals fallback chips after the profile grace window',
      (tester) async {
        final profile = Completer<UserProfile?>();

        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(
              pubkeys: [_reposterPubkey],
              isLoading: false,
            ),
            providerOverrides: [
              fetchUserProfileProvider(
                _reposterPubkey,
              ).overrideWith((ref) => profile.future),
            ],
            child: MetadataRepostedBySection(video: _makeVideo()),
          ),
        );
        await tester.pump();

        expect(_skeletonChips(), findsNWidgets(1));

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(
          find.text(_l10n(tester).metadataRepostedByLabel),
          findsOneWidget,
        );
        expect(_skeletonChips(), findsNothing);
        expect(find.byType(UserAvatar), findsOneWidget);

        profile.complete(_makeProfile(_reposterPubkey, 'Improvising'));
        await tester.pumpAndSettle();

        expect(find.text('Improvising'), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'shows every reposter when they fit under the cap',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(
              pubkeys: [_reposterPubkey],
              isLoading: false,
            ),
            providerOverrides: [
              fetchUserProfileProvider(_reposterPubkey).overrideWith(
                (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
              ),
            ],
            child: MetadataRepostedBySection(video: _makeVideo()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Improvising'), findsOneWidget);
        expect(find.textContaining('more'), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize(
      'hides when relay returns empty and no pre-populated data',
      (tester) async {
        final video = _makeVideo();

        await tester.pumpWidget(
          buildSubject(child: MetadataRepostedBySection(video: video)),
        );
        await tester.pumpAndSettle();

        expect(find.text(_l10n(tester).metadataRepostedByLabel), findsNothing);
      },
    );

    testWidgetsWithSurfaceSize('grows in when the relay answers late', (
      tester,
    ) async {
      final reposters = StreamController<VideoRepostersState>.broadcast();
      addTearDown(reposters.close);
      when(() => mockRepostersCubit.stream).thenAnswer((_) => reposters.stream);

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            fetchUserProfileProvider(_reposterPubkey).overrideWith(
              (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
            ),
          ],
          child: MetadataRepostedBySection(video: _makeVideo()),
        ),
      );
      await tester.pumpAndSettle();

      final section = find.byType(AnimatedReveal);
      expect(tester.getSize(section).height, 0);

      reposters.add(const VideoRepostersState(pubkeys: [_reposterPubkey]));
      // The reposters are laid out on this frame, but the section is still
      // collapsed — it grows from there rather than snapping the sections
      // below it down.
      await tester.pump();
      final revealingHeight = tester.getSize(section).height;

      await tester.pumpAndSettle();

      expect(find.text(_l10n(tester).metadataRepostedByLabel), findsOneWidget);
      expect(revealingHeight, lessThan(tester.getSize(section).height));
    });

    testWidgetsWithSurfaceSize(
      'stays revealed while a late relay answer widens the row',
      (tester) async {
        final relayPubkeys = List<String>.generate(
          4,
          (index) => (index + 1).toRadixString(16).padLeft(64, '0'),
        );
        final relayProfiles = {
          for (final pubkey in relayPubkeys) pubkey: Completer<UserProfile?>(),
        };

        final reposters = StreamController<VideoRepostersState>.broadcast();
        addTearDown(reposters.close);
        when(
          () => mockRepostersCubit.stream,
        ).thenAnswer((_) => reposters.stream);

        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(),
            providerOverrides: [
              fetchUserProfileProvider(_reposterPubkey).overrideWith(
                (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
              ),
              for (final entry in relayProfiles.entries)
                fetchUserProfileProvider(
                  entry.key,
                ).overrideWith((ref) => entry.value.future),
            ],
            // Feed consolidation pre-populated a single reposter, so the row
            // is already on screen when the relay answers.
            child: MetadataRepostedBySection(
              video: _makeVideo(reposterPubkeys: const [_reposterPubkey]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final section = find.byType(AnimatedReveal);
        final revealedHeight = tester.getSize(section).height;
        expect(revealedHeight, greaterThan(0));

        reposters.add(
          VideoRepostersState(pubkeys: [_reposterPubkey, ...relayPubkeys]),
        );
        await tester.pumpAndSettle();

        // Re-gating on the widened set would drop the section to nothing
        // while the four new profiles load — a bigger jump than the one the
        // gate prevents. The already-named chip keeps its place.
        expect(find.text('Improvising'), findsOneWidget);
        expect(find.textContaining('more'), findsNothing);
        expect(tester.getSize(section).height, revealedHeight);

        for (final completer in relayProfiles.values) {
          completer.complete(null);
        }
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsNWidgets(5));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Verification section
  // ---------------------------------------------------------------------------
  group(MetadataVerificationSection, () {
    testWidgetsWithSurfaceSize('renders checklist when video has proof data', (
      tester,
    ) async {
      final video = _makeVideo(
        rawTags: {
          'verification': 'verified_mobile',
          'device_attestation': 'token_abc',
          'proofmode': '{"pgpSignature":"-----BEGIN PGP SIGNATURE-----"}',
        },
      );
      await tester.pumpWidget(
        buildSubject(child: MetadataVerificationSection(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataVerificationLabel), findsOneWidget);
      expect(find.text(l10n.metadataDeviceAttestation), findsOneWidget);
      expect(find.text(l10n.metadataPgpSignature), findsOneWidget);
      expect(find.text(l10n.metadataC2paCredentials), findsOneWidget);
      expect(find.text(l10n.metadataProofManifest), findsOneWidget);
      // Three passed (device attestation, PGP via manifest, proof manifest),
      // one failed (C2PA). DivineIcon renders SVGs — find by widget type
      // and icon enum value.
      final checkIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .where((w) => w.icon == DivineIconName.check);
      final failIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .where((w) => w.icon == DivineIconName.x);
      expect(checkIcons.length, 3);
      expect(failIcons.length, 1);
    });

    testWidgetsWithSurfaceSize('hides when no proof data', (tester) async {
      final video = _makeVideo();
      await tester.pumpWidget(
        buildSubject(child: MetadataVerificationSection(video: video)),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.metadataVerificationLabel), findsNothing);
    });

    testWidgetsWithSurfaceSize(
      'tapping the header explains every check and the missing-check caveat',
      (tester) async {
        final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
        await tester.pumpWidget(
          buildSubject(child: MetadataVerificationSection(video: video)),
        );

        final l10n = _l10n(tester);
        await tester.tap(find.text(l10n.metadataVerificationLabel));
        await tester.pumpAndSettle();

        expect(find.byType(MetadataVerificationInfoSheet), findsOneWidget);
        expect(find.text(l10n.metadataVerificationInfoTitle), findsOneWidget);
        expect(
          find.text(l10n.metadataVerificationInfoDeviceAttestation),
          findsOneWidget,
        );
        expect(
          find.text(l10n.metadataVerificationInfoPgpSignature),
          findsOneWidget,
        );
        expect(
          find.text(l10n.metadataVerificationInfoC2paCredentials),
          findsOneWidget,
        );
        expect(
          find.text(l10n.metadataVerificationInfoProofManifest),
          findsOneWidget,
        );
        // The caveat is the load-bearing half of the sheet: without it the
        // four ticks over-claim, since a muted X only means "not proven".
        expect(
          find.text(l10n.metadataVerificationInfoFootnote),
          findsOneWidget,
        );
        // The URL is a placeholder inside the sentence, so a locale that
        // moves it still renders one continuous line.
        final learnMore = find.text(
          l10n.metadataVerificationInfoLearnMore('divine.video/proofmode'),
          findRichText: true,
        );
        expect(learnMore, findsOneWidget);
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: learnMore,
                      matching: find.byType(GestureDetector),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(48),
        );
      },
    );

    testWidgetsWithSurfaceSize(
      'learn-more tap opens proofmode URL externally',
      (tester) async {
        final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
        await tester.pumpWidget(
          buildSubject(child: MetadataVerificationSection(video: video)),
        );

        final l10n = _l10n(tester);
        await tester.tap(find.text(l10n.metadataVerificationLabel));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            l10n.metadataVerificationInfoLearnMore('divine.video/proofmode'),
            findRichText: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(urlLauncher.launched, isNotEmpty);
        expect(urlLauncher.launched.last.url, equals(proofmodeLearnMoreUrl));
        expect(urlLauncher.launched.last.useExternalApplication, isTrue);
      },
    );

    testWidgetsWithSurfaceSize(
      'dismissing nested explainer preserves parent metadata sheet hold',
      (tester) async {
        final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
        await tester.pumpWidget(
          buildSubject(child: MetadataVerificationSection(video: video)),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MetadataVerificationSection)),
          listen: false,
        );
        final parentOwner = Object();
        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpenForOwner(parentOwner, isOpen: true);

        final l10n = _l10n(tester);
        await tester.tap(find.text(l10n.metadataVerificationLabel));
        await tester.pumpAndSettle();
        expect(find.byType(MetadataVerificationInfoSheet), findsOneWidget);
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        Navigator.of(
          tester.element(find.byType(MetadataVerificationInfoSheet)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
        expect(find.byType(MetadataVerificationInfoSheet), findsNothing);
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpenForOwner(parentOwner, isOpen: false);
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      },
    );

    testWidgetsWithSurfaceSize('header info affordance is a labeled button', (
      tester,
    ) async {
      final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
      await tester.pumpWidget(
        buildSubject(child: MetadataVerificationSection(video: video)),
      );

      final l10n = _l10n(tester);
      // The label names the section as well as the explainer: the visible
      // "Verification" text is excluded from semantics, so dropping it here
      // would leave the checklist with no announced section at all.
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(
          l10n.metadataSectionInfoSemanticsLabel(
            l10n.metadataVerificationLabel,
            l10n.metadataVerificationInfoTooltip,
          ),
        ),
      );
      expect(semantics.flagsCollection.isButton, isTrue);
      // The tooltip carries the same string; announcing it again as a
      // tooltip duplicates it on both platforms.
      expect(semantics.tooltip, isEmpty);
    });

    testWidgetsWithSurfaceSize(
      'header tap target clears 48 dp without moving the label',
      (tester) async {
        final video = _makeVideo(rawTags: {'verification': 'verified_mobile'});
        await tester.pumpWidget(
          buildSubject(child: MetadataVerificationSection(video: video)),
        );

        final l10n = _l10n(tester);
        final tapTarget = find
            .ancestor(
              of: find.text(l10n.metadataVerificationLabel),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(tapTarget).height, greaterThanOrEqualTo(48));

        // The extra height is slack around the row, not layout: the Figma
        // spec's 16 px above the header and 16 px below it both survive.
        final headerRow = find
            .ancestor(
              of: find.text(l10n.metadataVerificationLabel),
              matching: find.byType(Row),
            )
            .first;
        final firstCheckRow = find
            .ancestor(
              of: find.text(l10n.metadataDeviceAttestation),
              matching: find.byType(Row),
            )
            .first;

        final sectionTop = tester.getTopLeft(find.byType(MetadataSection)).dy;
        expect(tester.getTopLeft(headerRow).dy - sectionTop, 16);
        expect(
          tester.getTopLeft(firstCheckRow).dy -
              tester.getBottomLeft(headerRow).dy,
          16,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Sounds section
  // ---------------------------------------------------------------------------
  group(MetadataSoundsSection, () {
    testWidgetsWithSurfaceSize('renders sound info when audio exists', (
      tester,
    ) async {
      final video = _makeVideo(audioEventId: _audioEventId);

      await tester.pumpWidget(
        buildSubject(
          providerOverrides: [
            soundByIdProvider(
              _audioEventId,
            ).overrideWith((ref) async => _testAudio),
            userProfileReactiveProvider(_audioPubkey).overrideWith(
              (ref) =>
                  Stream.value(_makeProfile(_audioPubkey, 'Audio Creator')),
            ),
          ],
          child: MetadataSoundsSection(video: video),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('Test Sound'), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('shows original sound when no audio reference', (
      tester,
    ) async {
      final video = _makeVideo();

      await tester.pumpWidget(
        buildSubject(child: MetadataSoundsSection(video: video)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('Original sound'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Full sheet integration
  // ---------------------------------------------------------------------------
  group('$MetadataExpandedSheet full integration', () {
    testWidgetsWithSurfaceSize(
      'renders all sections for fully populated video',
      (tester) async {
        final video = _makeVideo(
          title: 'Who knew?',
          content: 'What really happens behind the scenes',
          hashtags: ['grease', 'take503'],
          collaboratorPubkeys: [_collaborator1],
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$_inspiredByPubkey:some-dtag',
          ),
          audioEventId: _audioEventId,
          rawTags: {'verification': 'verified_mobile'},
        );

        await tester.pumpWidget(
          buildSubject(
            repostersState: const VideoRepostersState(
              pubkeys: [_reposterPubkey],
              isLoading: false,
            ),
            providerOverrides: [
              fetchUserProfileProvider(_creatorPubkey).overrideWith(
                (ref) async => _makeProfile(_creatorPubkey, 'Sebastian Heit'),
              ),
              fetchUserProfileProvider(_collaborator1).overrideWith(
                (ref) async => _makeProfile(_collaborator1, 'Josh Musick'),
              ),
              fetchUserProfileProvider(_inspiredByPubkey).overrideWith(
                (ref) async =>
                    _makeProfile(_inspiredByPubkey, 'Inspiring Creator'),
              ),
              fetchUserProfileProvider(_reposterPubkey).overrideWith(
                (ref) async => _makeProfile(_reposterPubkey, 'Improvising'),
              ),
              soundByIdProvider(
                _audioEventId,
              ).overrideWith((ref) async => _testAudio),
              userProfileReactiveProvider(_audioPubkey).overrideWith(
                (ref) =>
                    Stream.value(_makeProfile(_audioPubkey, 'Audio Creator')),
              ),
            ],
            child: MetadataExpandedSheet(video: video),
          ),
        );
        await tester.pumpAndSettle();

        // Title + description
        expect(find.text('Who knew?'), findsOneWidget);
        expect(
          find.text('What really happens behind the scenes'),
          findsOneWidget,
        );

        // Stats
        final l10n = _l10n(tester);
        expect(
          find.text(l10n.metadataLoopsLabel(video.totalLoops)),
          findsOneWidget,
        );
        expect(find.text(l10n.metadataLikesLabel), findsOneWidget);

        // Badges row (Human-Made from verification, not Classic Vine).
        // Tags now live inside the header section, so they're visible
        // without scrolling.
        expect(
          find.textContaining(l10n.metadataBadgeHumanMade),
          findsOneWidget,
        );
        expect(find.text('grease'), findsOneWidget);

        // Top section labels
        expect(find.text(l10n.metadataCreatorLabel), findsOneWidget);

        // Scroll to reveal sections below the fold
        final listFinder = find.byType(ListView);
        await tester.drag(listFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(find.text('Sebastian Heit'), findsOneWidget);

        // Scroll further to reveal collaborators
        await tester.drag(listFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(find.text(l10n.metadataCollaboratorsLabel), findsOneWidget);
        expect(find.text('Josh Musick'), findsOneWidget);

        // Scroll further to reveal remaining sections including
        // Verification, which now sits at the very bottom per Figma.
        await tester.drag(listFinder, const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text(l10n.metadataInspiredByLabel), findsOneWidget);
        expect(find.text('Inspiring Creator'), findsOneWidget);
        expect(find.text(l10n.metadataRepostedByLabel), findsOneWidget);
        expect(find.text('Improvising'), findsOneWidget);
        // Sounds section label is still hardcoded English in lib code
        // (metadata_sounds_section.dart) — flagged as pre-existing l10n debt.
        expect(find.text('Sounds'), findsOneWidget);
        expect(find.text('Test Sound'), findsOneWidget);

        // Verification section moved to the bottom of the sheet.
        await tester.drag(listFinder, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text(l10n.metadataVerificationLabel), findsOneWidget);
      },
    );

    testWidgetsWithSurfaceSize(
      'renders only populated sections for sparse video',
      (tester) async {
        final video = _makeVideo(title: 'Simple video', hashtags: ['hello']);

        await tester.pumpWidget(
          buildSubject(
            providerOverrides: [
              fetchUserProfileProvider(_creatorPubkey).overrideWith(
                (ref) async => _makeProfile(_creatorPubkey, 'Test User'),
              ),
            ],
            child: MetadataExpandedSheet(video: video),
          ),
        );
        await tester.pumpAndSettle();

        // Present
        expect(find.text('Simple video'), findsOneWidget);
        expect(find.text('Creator'), findsOneWidget);
        // Tags section has no label — verify chip text directly.
        expect(find.text('hello'), findsOneWidget);

        // Absent
        expect(
          find.text(_l10n(tester).metadataCollaboratorsLabel),
          findsNothing,
        );
        expect(find.text('Inspired by'), findsNothing);
        expect(find.text(_l10n(tester).metadataRepostedByLabel), findsNothing);

        // Sounds section is always present (shows "Original sound")
        // Scroll down to find it
        final listFinder = find.byType(ListView);
        await tester.drag(listFinder, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Sounds'), findsOneWidget);
        expect(find.text('Original sound'), findsOneWidget);
      },
    );
  });
}

void testWidgetsWithSurfaceSize(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await callback(tester);
  });
}
