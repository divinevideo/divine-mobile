// ABOUTME: Shared subtitle fetch chain used by the display provider and the
// ABOUTME: editor's load path. Ordered fallback: embedded content → each
// ABOUTME: text-track ref (http or 39307 relay) → Blossom {sha256}/vtt.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback type for delaying between Blossom poll attempts.
typedef SubtitlePollDelay = Future<void> Function(Duration duration);

const _maxBlossomPollAttempts = 4;
const _maxBlossomPollWait = Duration(seconds: 15);
const _defaultBlossomRetryAfter = Duration(seconds: 3);

/// Source ordering for [fetchSubtitleCues].
enum SubtitleSourcePreference {
  /// Prefer embedded REST VTT before trying text-track refs.
  embeddedFirst,

  /// Prefer text-track refs before embedded REST VTT.
  refsFirst,
}

/// Why [fetchSubtitleCues] returned the cues it did.
///
/// Callers need this to tell "transcription is still running" apart from
/// "transcription finished and there was nothing to transcribe" — both yield
/// zero cues but mean opposite things to the user.
enum SubtitleFetchStatus {
  /// A source returned at least one cue.
  available,

  /// A source was reachable and served a subtitle track that holds no cues,
  /// e.g. a video with no speech. Transcription is done; there is nothing
  /// to show.
  empty,

  /// A source reported the track is still being generated (HTTP 202).
  processing,

  /// No source was configured, reachable, or held a subtitle track.
  unavailable,
}

/// Outcome of a subtitle fetch: the cues plus why they are what they are.
class SubtitleFetchResult {
  /// Creates a result with an explicit [status].
  const SubtitleFetchResult(
    this.status, {
    this.cues = const [],
    this.isMachineTranslated = false,
  });

  /// Classifies a [body] a source served as a subtitle track:
  /// [SubtitleFetchStatus.available] when it holds cues, or
  /// [SubtitleFetchStatus.empty] when it is a track with none.
  ///
  /// Returns `null` when [body] is not WebVTT at all. An HTML error page or a
  /// JSON envelope served with HTTP 200 parses to zero cues just like a
  /// silent video's track does, and calling that `empty` would tell the
  /// creator no speech was detected when the fetch actually failed.
  static SubtitleFetchResult? fromBody(
    String body, {
    bool isMachineTranslated = false,
  }) {
    if (!SubtitleService.isWebVtt(body)) return null;
    final cues = SubtitleService.parseVtt(body);
    return cues.isEmpty
        ? const SubtitleFetchResult(SubtitleFetchStatus.empty)
        : SubtitleFetchResult(
            SubtitleFetchStatus.available,
            cues: cues,
            isMachineTranslated: isMachineTranslated,
          );
  }

  /// Why the fetch ended the way it did.
  final SubtitleFetchStatus status;

  /// The resolved cues. Empty unless [status] is
  /// [SubtitleFetchStatus.available].
  final List<SubtitleCue> cues;

  /// True only for a response verified against the translation contract.
  final bool isMachineTranslated;
}

Duration _parseRetryAfter(Map<String, String> headers) {
  final rawValue = headers['retry-after'];
  if (rawValue == null) return _defaultBlossomRetryAfter;

  final seconds = int.tryParse(rawValue.trim());
  if (seconds == null || seconds <= 0) return _defaultBlossomRetryAfter;

  return Duration(seconds: seconds);
}

Uri? _parseHttpSubtitleUrl(String ref) {
  if (ref.isEmpty) return null;

  final uri = Uri.tryParse(ref);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

String _decodeVtt(http.Response response) {
  // WebVTT is always UTF-8, even when the server omits the charset.
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}

Future<SubtitleFetchResult?> _fetchHttp(http.Client client, Uri url) async {
  try {
    final response = await client.get(url);
    if (response.statusCode == 200) {
      return SubtitleFetchResult.fromBody(_decodeVtt(response));
    }
    // Saved refs can point at the same generator Blossom fronts, so a direct
    // ref answers 202 while transcription runs. Report it rather than poll:
    // the retry-after contract belongs to the Blossom path.
    if (response.statusCode == 202) {
      return const SubtitleFetchResult(SubtitleFetchStatus.processing);
    }
  } catch (e) {
    Log.warning(
      'Direct VTT fetch failed for $url: $e',
      name: 'fetchSubtitleCues',
      category: LogCategory.video,
    );
  }
  return null;
}

Future<SubtitleFetchResult?> _fetchRelay(
  NostrClient nostrClient,
  String ref,
) async {
  final parts = ref.split(':');
  if (parts.length < 3) return null;

  final kind = int.tryParse(parts[0]);
  if (kind == null) return null;

  final pubkey = parts[1];
  // d-tag may contain colons (e.g. "subtitles:my-vine-id")
  final dTag = parts.sublist(2).join(':');

  final events = await nostrClient.queryEvents(
    [
      Filter(kinds: [kind], authors: [pubkey], d: [dTag], limit: 1),
    ],
    tempRelays: ['wss://relay.divine.video'],
  );

  if (events.isEmpty) return null;
  return SubtitleFetchResult.fromBody(events.first.content);
}

Future<SubtitleFetchResult?> _fetchBlossom({
  required http.Client client,
  required SubtitlePollDelay delay,
  required Uri vttUrl,
}) async {
  var waited = Duration.zero;

  for (var attempt = 0; attempt < _maxBlossomPollAttempts; attempt++) {
    final response = await client.get(vttUrl);

    if (response.statusCode == 200) {
      return SubtitleFetchResult.fromBody(_decodeVtt(response));
    }

    if (response.statusCode == 202) {
      const stillProcessing = SubtitleFetchResult(
        SubtitleFetchStatus.processing,
      );
      if (attempt == _maxBlossomPollAttempts - 1) return stillProcessing;

      final retryAfter = _parseRetryAfter(response.headers);
      if (waited + retryAfter > _maxBlossomPollWait) return stillProcessing;

      waited += retryAfter;
      await delay(retryAfter);
      continue;
    }

    return null;
  }

  return null;
}

Future<SubtitleFetchResult?> _fetchTranslation({
  required http.Client client,
  required String sha256,
  required String lang,
}) async {
  final url = Uri.parse('https://media.divine.video/$sha256/vtt')
      .replace(queryParameters: {'lang': lang});
  try {
    final response = await client.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200 ||
        response.headers['x-divine-machine-translated'] != 'true' ||
        response.headers['content-language']?.toLowerCase() !=
            lang.toLowerCase()) {
      return null;
    }
    return SubtitleFetchResult.fromBody(
      _decodeVtt(response),
      isMachineTranslated: true,
    );
  } on Object catch (error) {
    Log.warning(
      'Translated VTT fetch failed for $sha256: $error',
      name: 'fetchSubtitleCues',
      category: LogCategory.video,
    );
    return null;
  }
}

/// Resolves subtitle cues with ordered fallback.
///
/// When [lang] and [sha256] are supplied, try a verified translation first.
/// A pending, failed, or unmarked response immediately falls back to the
/// original chain; translation requests never poll or replace creator captions
/// with an unmarked server transcript.
///
/// Original strategy (first source with cues wins): embedded content, then
/// HTTP/relay refs, then the plain Blossom URL with bounded transcription polling.
/// [sourcePreference] can place refs before embedded content for the editor.
///
/// A source that resolves to zero cues does not end the chain — the next
/// source still gets a turn. When no source yields cues, the returned status
/// says why: [SubtitleFetchStatus.processing] if any source reported the track
/// is still being generated, [SubtitleFetchStatus.empty] if a track was served
/// but held no cues, otherwise [SubtitleFetchStatus.unavailable].
///
/// Only a body carrying the WebVTT signature counts as a served track — see
/// [SubtitleFetchResult.fromBody].
Future<SubtitleFetchResult> fetchSubtitleCues({
  required http.Client httpClient,
  required NostrClient? nostrClient,
  required SubtitlePollDelay delay,
  String? textTrackContent,
  List<String> textTrackRefs = const [],
  String? sha256,
  String? lang,
  SubtitleSourcePreference sourcePreference =
      SubtitleSourcePreference.embeddedFirst,
}) async {
  if (lang != null && lang.isNotEmpty && sha256 != null && sha256.isNotEmpty) {
    final translated = await _fetchTranslation(
      client: httpClient,
      sha256: sha256,
      lang: lang,
    );
    if (translated?.status == SubtitleFetchStatus.available) return translated!;
  }

  var sawProcessing = false;
  var sawEmpty = false;

  // Returns the result only when it carries cues; otherwise records why this
  // source came up short so the chain can continue and still explain itself.
  SubtitleFetchResult? accept(SubtitleFetchResult? result) {
    switch (result?.status) {
      case SubtitleFetchStatus.available:
        return result;
      case SubtitleFetchStatus.processing:
        sawProcessing = true;
      case SubtitleFetchStatus.empty:
        sawEmpty = true;
      case SubtitleFetchStatus.unavailable:
      case null:
        break;
    }
    return null;
  }

  SubtitleFetchResult? embedded() {
    if (textTrackContent == null || textTrackContent.isEmpty) return null;
    return SubtitleFetchResult.fromBody(textTrackContent);
  }

  if (sourcePreference == SubtitleSourcePreference.embeddedFirst) {
    final cues = accept(embedded());
    if (cues != null) return cues;
  }

  for (final ref in textTrackRefs) {
    final httpUrl = _parseHttpSubtitleUrl(ref);
    if (httpUrl != null) {
      final cues = accept(await _fetchHttp(httpClient, httpUrl));
      if (cues != null) return cues;
      continue;
    }

    if (nostrClient != null) {
      try {
        final cues = accept(await _fetchRelay(nostrClient, ref));
        if (cues != null) return cues;
      } catch (e) {
        Log.warning(
          'Relay VTT fetch failed for $ref: $e',
          name: 'fetchSubtitleCues',
          category: LogCategory.video,
        );
      }
    }
  }

  if (sourcePreference == SubtitleSourcePreference.refsFirst) {
    final cues = accept(embedded());
    if (cues != null) return cues;
  }

  if (sha256 != null && sha256.isNotEmpty) {
    final vttUrl = Uri.parse('https://media.divine.video/$sha256/vtt');
    try {
      final cues = accept(
        await _fetchBlossom(client: httpClient, delay: delay, vttUrl: vttUrl),
      );
      if (cues != null) return cues;
    } catch (e) {
      Log.warning(
        'Blossom VTT fetch failed for $sha256: $e',
        name: 'fetchSubtitleCues',
        category: LogCategory.video,
      );
    }
  }

  if (sawProcessing) {
    return const SubtitleFetchResult(SubtitleFetchStatus.processing);
  }
  if (sawEmpty) return const SubtitleFetchResult(SubtitleFetchStatus.empty);
  return const SubtitleFetchResult(SubtitleFetchStatus.unavailable);
}
