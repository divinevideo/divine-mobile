// ABOUTME: Verifies the hashtag feed hides blocked/muted authors at the
// ABOUTME: assembly seam and refetches REST results on blocklist changes.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockHashtagService extends Mock implements HashtagService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

VideoEvent _video(String id, String pubkey) {
  final created = DateTime(2026, 3, 30, 12);
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    content: '',
    title: 'Video $id',
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    createdAt: created.millisecondsSinceEpoch ~/ 1000,
    timestamp: created,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<VideoEvent>[]);
  });

  const blockedPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late _MockVideosRepository mockVideosRepository;
  late _MockHashtagService mockHashtagService;
  late _MockContentBlocklistRepository mockBlocklist;
  late _MockVideoEventService mockVideoEventService;

  setUp(() {
    mockVideosRepository = _MockVideosRepository();
    mockHashtagService = _MockHashtagService();
    mockBlocklist = _MockContentBlocklistRepository();
    mockVideoEventService = _MockVideoEventService();

    when(() => mockHashtagService.getVideosByHashtags(any())).thenReturn([]);
    when(() => mockHashtagService.getHashtagStats(any())).thenReturn(null);
    when(
      () => mockHashtagService.subscribeToHashtagVideos(any()),
    ).thenAnswer((_) async {});
    when(() => mockBlocklist.shouldFilterFromFeeds(any())).thenReturn(false);
    when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
      invocation,
    ) {
      final videos = invocation.positionalArguments.first as List<VideoEvent>;
      return videos
          .where((video) => !mockBlocklist.shouldFilterFromFeeds(video.pubkey))
          .toList();
    });
  });

  Widget buildSubject(String hashtag) {
    return ProviderScope(
      overrides: [
        videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        hashtagServiceProvider.overrideWith((ref) => mockHashtagService),
        contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
        videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        subscribedListVideoCacheProvider.overrideWithValue(null),
        // The screen hosts a ComposableVideoGrid, which resolves the viewer's
        // pubkey through the auth service to decide per-video ownership.
        sharedPreferencesProvider.overrideWithValue(
          createMockSharedPreferences(),
        ),
        authServiceProvider.overrideWithValue(createMockAuthService()),
        nostrServiceProvider.overrideWithValue(createMockNostrService()),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HashtagFeedScreen(hashtag: hashtag),
      ),
    );
  }

  group(HashtagFeedScreen, () {
    testWidgets(
      "the assembly seam removes a blocked author's video even when a source "
      'bypasses the repository parse-gate (#4782)',
      (tester) async {
        // Simulate a source that did NOT filter (e.g. the WebSocket path):
        // the seam filter must still consult the blocklist before rendering.
        when(
          () => mockVideosRepository.getHashtagFeedVideos(
            hashtag: any(named: 'hashtag'),
          ),
        ).thenAnswer(
          (_) async => HashtagFeedVideosResult.success([
            _video('blocked-vid', blockedPubkey),
          ]),
        );
        when(
          () => mockBlocklist.shouldFilterFromFeeds(blockedPubkey),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject('bts'));
        await tester.pump(); // run post-frame _loadHashtagVideos
        await tester.pump(const Duration(milliseconds: 100)); // settle REST
        await tester.pump(); // rebuild with filtered list

        verify(
          () => mockBlocklist.shouldFilterFromFeeds(blockedPubkey),
        ).called(greaterThanOrEqualTo(1));
        expect(
          find.byType(ComposableVideoGrid),
          findsNothing,
          reason: "A blocked author's only video must not render a grid",
        );
        // Mutation note: if the filter were deleted or inverted, the blocked
        // video would render the grid above and this assertion would fail.
      },
    );

    testWidgets(
      'refetches the REST feed when the blocklist changes, so an unblock '
      're-shows content the parse-gate had dropped (#948)',
      (tester) async {
        when(
          () => mockVideosRepository.getHashtagFeedVideos(
            hashtag: any(named: 'hashtag'),
          ),
        ).thenAnswer(
          (_) async => const HashtagFeedVideosResult.success(<VideoEvent>[]),
        );

        await tester.pumpWidget(buildSubject('bts'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockVideosRepository.getHashtagFeedVideos(hashtag: 'bts'),
        ).called(1);

        // A block/unblock anywhere in the app bumps the blocklist version.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HashtagFeedScreen)),
        );
        container.read(blocklistVersionProvider.notifier).increment();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockVideosRepository.getHashtagFeedVideos(hashtag: 'bts'),
        ).called(1);
      },
    );

    testWidgets(
      'preserves an existing REST cache when a blocklist-triggered refetch '
      'fails',
      (tester) async {
        final cachedVideo = _video('cached-vid', 'allowed-pubkey');
        var callCount = 0;
        when(
          () => mockVideosRepository.getHashtagFeedVideos(
            hashtag: any(named: 'hashtag'),
          ),
        ).thenAnswer((_) async {
          callCount += 1;
          if (callCount == 1) {
            return HashtagFeedVideosResult.success([cachedVideo]);
          }
          return const HashtagFeedVideosResult.failure();
        });

        await tester.pumpWidget(buildSubject('bts'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.byType(ComposableVideoGrid), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HashtagFeedScreen)),
        );
        container.read(blocklistVersionProvider.notifier).increment();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(
          find.byType(ComposableVideoGrid),
          findsOneWidget,
          reason: 'A failed background refetch must not blank a populated feed',
        );
        verify(
          () => mockVideosRepository.getHashtagFeedVideos(hashtag: 'bts'),
        ).called(2);
      },
    );
  });
}
