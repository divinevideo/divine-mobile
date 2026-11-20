// ABOUTME: Owns the edit-subtitles orchestration: generate VTT → upload to
// ABOUTME: Blossom → republish the video with the Blossom URL and the 39307
// ABOUTME: address → publish the 39307 subtitle event at that address.

import 'dart:convert';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:http/http.dart' as http;
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/exceptions/video_exceptions.dart'
    show AccountRestrictedPublishException;
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/utils/newest_video_revision.dart';
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
  /// it is replaced only after the video republish succeeds: a republish that
  /// fails leaves the published captions alone. If that last publish fails,
  /// the save fails too, because playback prefers the captions served from
  /// it; saving again rebuilds both from the newest revision.
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
  /// * [SubtitleEditException] when the subtitle event publish fails after
  ///   the video republish.
  /// * [AccountRestrictedPublishException] when the configured Divine relay
  ///   reports that the account is suspended or banned.
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
      throw SubtitleEditException(
        'Republished video ${updatedVideo.id}, but its subtitle event was not '
        'published',
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
    // revision. A save or another device can have replaced that track since
    // the copy was opened: then the copy's own tags name it, or else the
    // newest revision's only caption track in that base language is it.
    final ref = video.textTrackRef;
    final newest = _trackLanguageAt(newestTags, ref);
    if (newest != null) return newest.isEmpty ? video.textTrackLang : newest;
    final opened = _trackLanguageAt(video.nostrEventTags, ref);
    if (opened != null && opened.isNotEmpty) return opened;
    final baseLanguage = video.textTrackLang?.toLowerCase();
    final sameBase = {
      for (final tag in newestTags)
        if (tag.length > 4 &&
            tag.first == 'text-track' &&
            const {'', 'captions', 'subtitles'}.contains(tag[3]) &&
            tag[4].trim().split('-').first.toLowerCase() == baseLanguage)
          tag[4].trim(),
    };
    return sameBase.length == 1 ? sameBase.single : video.textTrackLang;
  }

  /// The language of the `text-track` at [ref] among [tags]: `''` when that
  /// track names none, or null when [tags] holds no track at [ref].
  static String? _trackLanguageAt(List<List<String>> tags, String? ref) {
    String? language;
    for (final tag in tags) {
      if (tag.length < 2 || tag.first != 'text-track' || tag[1] != ref) {
        continue;
      }
      final named = tag.length > 4 ? tag[4].trim() : '';
      if (named.isNotEmpty) return named;
      language = '';
    }
    return language;
  }
}
