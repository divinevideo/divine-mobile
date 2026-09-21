/// Videos Repository - manages video event storage and retrieval.
///
/// Follows the repository pattern with abstract interfaces for testability:
/// - `VideoLocalStorage` - abstract interface for local storage
/// - `DbVideoLocalStorage` - db_client implementation
/// - `VideosRepository` - main repository (orchestrates Nostr + Storage)
library;

export 'src/author_feed_result.dart';
export 'src/db_video_local_storage.dart';
export 'src/home_feed_result.dart';
export 'src/in_memory_feed_cache.dart';
export 'src/popular_videos_page.dart';
export 'src/profile_video_merge.dart';
export 'src/recommendation_session_seed.dart';
export 'src/seen_video_lookup.dart';
export 'src/video_content_filter.dart';
export 'src/video_event_filter.dart';
export 'src/video_local_storage.dart';
export 'src/video_merge_helpers.dart';
export 'src/video_route_lookup_result.dart';
export 'src/video_route_ref.dart';
export 'src/video_search_sort.dart';
export 'src/videos_repository.dart';
