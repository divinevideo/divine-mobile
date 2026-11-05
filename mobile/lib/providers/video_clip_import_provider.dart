// ABOUTME: Riverpod wiring for importing videos into the clip library.
// ABOUTME: Keeps the import service testable while using app cache and storage services.

import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/published_clip_source_resolver.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_clip_import_provider.g.dart';

@riverpod
VideoClipImportService videoClipImportService(Ref ref) {
  final mediaCache = ref.watch(mediaCacheProvider);
  final videosRepository = ref.watch(videosRepositoryProvider);

  return VideoClipImportService(
    clipLibraryService: ref.watch(clipLibraryServiceProvider),
    getDocumentsPath: getDocumentsPath,
    downloadVideo: ({required String url, required String cacheKey}) async {
      final cached = mediaCache.getCachedFileSync(cacheKey);
      if (cached != null && cached.existsSync()) return cached;
      return mediaCache.cacheFile(url, key: cacheKey);
    },
    extractThumbnail: ({required videoPath, required targetTimestamp}) async {
      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        targetTimestamp: targetTimestamp,
      );
      if (result == null) return null;
      return VideoClipThumbnail(
        path: result.path,
        timestamp: result.timestamp,
      );
    },
    extractLastFrame: VideoThumbnailService.extractLastFrame,
    publishedSourceResolver: PublishedClipSourceResolver(
      mediaServer: Uri.parse(ref.watch(currentEnvironmentProvider).blossomUrl),
      videosByAuthor: videosRepository.getVideosByAuthor,
      videosByFileHash: videosRepository.getVideosByFileHash,
      isVerifiedArchive: verifiedArchiveLookup(videosRepository),
    ),
  );
}

/// Answers [IsVerifiedArchive] from the event's REST stats row, which the
/// server classifies against that exact event.
///
/// No row, or an API that is not configured, answers false, so the file is
/// not credited. A failed request throws, and so does a row the server could
/// not check against its archive ([ArchiveVerificationUnavailableException]),
/// so the import reports a lookup it could not make rather than "not a Vine".
IsVerifiedArchive verifiedArchiveLookup(VideosRepository repository) =>
    (eventId) async {
      final stats = await repository.getVideoStats(eventId);
      if (stats == null) return false;
      if (stats.isArchiveVerificationUnknown) {
        throw ArchiveVerificationUnavailableException(eventId);
      }
      return stats.isVerifiedArchive;
    };
