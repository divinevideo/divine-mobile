// ABOUTME: Providers for creator analytics repository and feature toggles.
// ABOUTME: Allows swapping between Funnelcake and fixture data sources.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Enables fixture analytics payload for local UI development.
final useFixtureCreatorAnalyticsProvider = StateProvider<bool>((_) => false);

/// Repository used by creator analytics screens.
final creatorAnalyticsRepositoryProvider = Provider<CreatorAnalyticsRepository>(
  (ref) {
    final useFixture = ref.watch(useFixtureCreatorAnalyticsProvider);
    if (useFixture) {
      return _FixtureCreatorAnalyticsRepository();
    }

    final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final soundsRepository = ref.watch(soundsRepositoryProvider);
    return FunnelcakeCreatorAnalyticsRepository(
      funnelcakeClient,
      locallyDeletedEventIds: () => _locallyDeletedEventIds(prefs),
      countVideosUsingSound: soundsRepository.fetchVideosUsingSoundCount,
    );
  },
);

/// Event ids this device has deleted, from the persisted deletion history.
///
/// Read from preferences on each call rather than from the async
/// [ContentDeletionService] provider, so a deletion made after the repository
/// was built still counts and the repository never waits on that service.
Set<String> _locallyDeletedEventIds(SharedPreferences prefs) {
  try {
    return {
      for (final deletion in ContentDeletionService.parseDeletionHistory(
        prefs.getString(ContentDeletionService.deletionsStorageKey),
      ))
        deletion.originalEventId,
    };
  } on Object catch (error, stackTrace) {
    Log.error(
      'Failed to read deletion history for creator analytics',
      name: 'CreatorAnalyticsRepository',
      category: LogCategory.system,
      error: error,
      stackTrace: stackTrace,
    );
    return const {};
  }
}

class _FixtureCreatorAnalyticsRepository implements CreatorAnalyticsRepository {
  @override
  Future<CreatorAnalyticsSnapshot> fetchCreatorAnalytics(String pubkey) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final videos = List.generate(6, (index) {
      final views = 1200 - (index * 120);
      return VideoEvent(
        id: 'fixture-$index',
        pubkey: pubkey,
        createdAt: now - (index * 86400),
        content: 'Fixture content $index',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (now - (index * 86400)) * 1000,
        ),
        title: 'Fixture Video $index',
        rawTags: {'views': '$views', 'loops': '$views'},
        originalLikes: 40 - index,
        originalComments: 12 - (index ~/ 2),
        originalReposts: 4 - (index ~/ 3),
        originalLoops: views,
      );
    });

    return CreatorAnalyticsSnapshot(
      videos: videos,
      socialCounts: const SocialCounts(
        pubkey: 'fixture',
        followerCount: 321,
        followingCount: 87,
      ),
      diagnostics: CreatorAnalyticsDiagnostics(
        totalVideos: videos.length,
        videosWithAnyViews: videos.length,
        videosMissingViews: 0,
        videosHydratedByBulkStats: videos.length,
        videosHydratedByViewsEndpoint: 0,
        sourcesUsed: const {
          AnalyticsDataSource.authorVideos,
          AnalyticsDataSource.bulkVideoStats,
        },
        fetchedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<CreatorSound>> fetchCreatorSounds(String pubkey) async {
    final now = DateTime.now().toUtc();
    return List.generate(3, (index) {
      return CreatorSound(
        id: 'fixture-sound-$index',
        title: 'Fixture Sound $index',
        createdAt: now.subtract(Duration(days: index * 3)),
        videoCount: 24 - (index * 10),
      );
    });
  }
}
