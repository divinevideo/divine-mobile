// ABOUTME: Owns the edit-subtitles orchestration: generate VTT → upload to
// ABOUTME: Blossom → republish the video with the Blossom URL and the 39307
// ABOUTME: address → publish the 39307 subtitle event at that address.

import 'dart:convert';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:http/http.dart' as http;
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/utils/newest_video_revision.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

/// Thrown when an edited-subtitle publish cannot complete. Carries no PII.
class SubtitleEditException implements Exception {
  SubtitleEditException(this.message);

  final String message;

  @override
  String toString() => 'SubtitleEditException: $message';
}

/// Orchestrates the full subtitle-edit publish pipeline.
///
/// Responsibilities:
/// - Loading existing cues from the shared fallback chain.
/// - Generating VTT, uploading it to Blossom, republishing the video event
///   with both refs attached, and publishing the 39307 subtitle event.
///
/// Throws [SubtitleEditException] when any step fails.
class SubtitleRepository {
  SubtitleRepository({
    required BlossomUploadService blossomUploadService,
    required VideoEventPublisher videoEventPublisher,
    required VideosRepository videosRepository,
    required AuthService authService,
    required NostrClient nostrClient,
    required http.Client httpClient,
    required SubtitlePollDelay pollDelay,
  }) : _blossom = blossomUploadService,
       _publisher = videoEventPublisher,
       _videosRepository = videosRepository,
       _authService = authService,
       _nostrClient = nostrClient,
       _httpClient = httpClient,
       _pollDelay = pollDelay;

  final BlossomUploadService _blossom;
  final VideoEventPublisher _publisher;
  final VideosRepository _videosRepository;
  final AuthService _authService;
  final NostrClient _nostrClient;
  final http.Client _httpClient;
  final SubtitlePollDelay _pollDelay;

  /// Loads the current cues for [video] using the shared fallback chain.
  ///
  /// The returned [SubtitleFetchResult.status] distinguishes a track that is
  /// still being generated from one that finished with nothing to transcribe,
  /// so the editor can say which.
  Future<SubtitleFetchResult> loadCues(VideoEvent video) {
    return fetchSubtitleCues(
      httpClient: _httpClient,
      nostrClient: _nostrClient,
      delay: _pollDelay,
      textTrackContent: video.textTrackContent,
      textTrackRefs: video.textTrackRefs.isNotEmpty
          ? video.textTrackRefs
          : [
              if (video.textTrackRef != null && video.textTrackRef!.isNotEmpty)
                video.textTrackRef!,
            ],
      sha256: video.sha256,
      sourcePreference: SubtitleSourcePreference.refsFirst,
    );
  }

  /// Generates VTT from [cues], uploads it to Blossom, republishes the video
  /// referencing the upload and its 39307 address, then publishes the 39307
  /// subtitle event there.
  ///
  /// [lang] defaults to the language the subtitles are already tagged with,
  /// so an edit keeps it; untagged subtitles are published as English.
  ///
  /// The 39307 address serves the captions of every revision of [video], so
  /// it is replaced only after the video republish succeeds: a save that
  /// fails leaves the published captions alone. If only that last publish
  /// fails, the republished video is still returned; its Blossom track plays
  /// the edit and the relay fallback keeps the previous captions.
  ///
  /// Throws:
  ///
  /// * [SubtitleEditException] when the user is not authenticated.
  /// * [SubtitleEditException] when [video] is not the signed-in account's.
  /// * [SubtitleEditException] when [video] has no addressable identifier.
  /// * [SubtitleEditException] when the newest revision of [video] cannot be
  ///   read.
  /// * [SubtitleEditException] when the Blossom upload fails.
  /// * [SubtitleEditException] when the video republish fails.
  Future<VideoEvent> publishEditedSubtitles({
    required VideoEvent video,
    required List<SubtitleCue> cues,
    String? lang,
  }) async {
    final signedIn = _authService.currentPublicKeyHex;
    if (signedIn == null) {
      throw SubtitleEditException('Not authenticated');
    }
    if (signedIn != video.pubkey) {
      throw SubtitleEditException("Video is not the signed-in account's");
    }
    final vineId = video.vineId;
    if (vineId == null || vineId.isEmpty) {
      throw SubtitleEditException('Video has no addressable identifier');
    }
    final newest = await newestVideoRevision(
      _videosRepository,
      video,
      logName: 'SubtitleRepository',
    );
    if (newest == null) {
      throw SubtitleEditException('Newest revision of the video unavailable');
    }

    final trackLang = lang ?? _editedTrackLanguage(video, newest.tags) ?? 'en';
    final vtt = SubtitleService.generateVtt(cues);
    final bytes = Uint8List.fromList(utf8.encode(vtt));

    final upload = await _blossom.uploadSubtitleVtt(bytes: bytes);
    final blossomUrl = upload.url;
    if (!upload.success || blossomUrl == null) {
      throw SubtitleEditException('Subtitle upload to Blossom failed');
    }

    final updatedVideo = await _publisher.republishWithSubtitles(
      existingEvent: video,
      textTrackRef: blossomUrl,
      extraTextTrackRefs: [
        VideoEventPublisher.subtitleEventAddress(
          pubkey: signedIn,
          vineId: vineId,
        ),
      ],
      textTrackLang: trackLang,
    );
    if (updatedVideo == null) {
      throw SubtitleEditException('Video republish failed');
    }

    final published = await _publisher.publishSubtitleEvent(
      video: updatedVideo,
      vttContent: vtt,
      blossomUrl: blossomUrl,
      lang: trackLang,
    );
    if (published == null) {
      Log.warning(
        'Republished video ${updatedVideo.id} with edited subtitles, but '
        'its 39307 subtitle event was not published',
        name: 'SubtitleRepository',
        category: LogCategory.video,
      );
    }
    return updatedVideo;
  }

  static String? _editedTrackLanguage(
    VideoEvent video,
    List<List<String>> newestTags,
  ) {
    // The playback model keeps only the base language, and a copy restored
    // from a cache has no raw tags. Editing needs the full language of the
    // selected reference to replace that track, so read it from the newest
    // revision.
    for (final tag in newestTags) {
      if (tag.length < 5 ||
          tag.first != 'text-track' ||
          tag[1] != video.textTrackRef) {
        continue;
      }
      final language = tag[4].trim();
      if (language.isNotEmpty) return language;
    }
    return video.textTrackLang;
  }
}
