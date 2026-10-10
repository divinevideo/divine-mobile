// ABOUTME: Owns the edit-subtitles orchestration: generate VTT → upload to
// ABOUTME: Blossom → publish 39307 subtitle event → republish the video with
// ABOUTME: both the Blossom URL and the addressable event reference.

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
/// - Generating VTT, uploading it to Blossom, publishing a 39307 subtitle
///   event, and republishing the video event with both refs attached.
///
/// Throws [SubtitleEditException] when any step fails.
class SubtitleRepository {
  SubtitleRepository({
    required BlossomUploadService blossomUploadService,
    required VideoEventPublisher videoEventPublisher,
    required AuthService authService,
    required NostrClient nostrClient,
    required http.Client httpClient,
    required SubtitlePollDelay pollDelay,
  }) : _blossom = blossomUploadService,
       _publisher = videoEventPublisher,
       _authService = authService,
       _nostrClient = nostrClient,
       _httpClient = httpClient,
       _pollDelay = pollDelay;

  final BlossomUploadService _blossom;
  final VideoEventPublisher _publisher;
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

  /// Generates VTT from [cues], uploads it to Blossom, publishes a 39307
  /// subtitle event, then republishes the video referencing both.
  ///
  /// [lang] defaults to the language the subtitles are already tagged with,
  /// so an edit keeps it; untagged subtitles are published as English.
  ///
  /// Throws:
  ///
  /// * [SubtitleEditException] when the user is not authenticated.
  /// * [SubtitleEditException] when [video] has no addressable identifier.
  /// * [SubtitleEditException] when the Blossom upload fails.
  /// * [SubtitleEditException] when the subtitle event publish fails.
  /// * [SubtitleEditException] when the video republish fails.
  Future<VideoEvent> publishEditedSubtitles({
    required VideoEvent video,
    required List<SubtitleCue> cues,
    String? lang,
  }) async {
    if (_authService.currentPublicKeyHex == null) {
      throw SubtitleEditException('Not authenticated');
    }
    final vineId = video.vineId;
    if (vineId == null || vineId.isEmpty) {
      throw SubtitleEditException('Video has no addressable identifier');
    }

    final trackLang = lang ?? video.textTrackLang ?? 'en';
    final vtt = SubtitleService.generateVtt(cues);
    final bytes = Uint8List.fromList(utf8.encode(vtt));

    final upload = await _blossom.uploadSubtitleVtt(bytes: bytes);
    final blossomUrl = upload.url;
    if (!upload.success || blossomUrl == null) {
      throw SubtitleEditException('Subtitle upload to Blossom failed');
    }

    final coordsRef = await _publisher.publishSubtitleEvent(
      video: video,
      vttContent: vtt,
      blossomUrl: blossomUrl,
      lang: trackLang,
    );
    if (coordsRef == null) {
      throw SubtitleEditException('Subtitle event publish failed');
    }

    final updatedVideo = await _publisher.republishWithSubtitles(
      existingEvent: video,
      textTrackRef: blossomUrl,
      extraTextTrackRefs: [coordsRef],
      textTrackLang: trackLang,
    );
    if (updatedVideo == null) {
      throw SubtitleEditException('Video republish failed');
    }
    return updatedVideo;
  }
}
