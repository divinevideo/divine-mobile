// ABOUTME: AudioEvent model for NIP-94 Kind 1063 audio file
// ABOUTME: metadata events. Used for audio reuse feature -
// ABOUTME: parsing audio shared for use in other videos

import 'package:meta/meta.dart';
import 'package:models/src/audio_reuse_policy.dart';
import 'package:models/src/nostr_hex_utils.dart';
import 'package:models/src/video_event.dart';
import 'package:models/src/vine_sound.dart';
import 'package:nostr_sdk/event.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

/// Kind number for audio file metadata events (NIP-94)
const int audioEventKind = 1063;

/// The kind of underlying media source backing an [AudioEvent].
///
/// Used to pick the correct loading strategy: a bundled [asset], an
/// on-disk [file] (imported audio), or a remote [network] URL.
enum AudioSourceKind {
  /// Bundled app asset. The resolved path is the bare asset path, with the
  /// `asset://` scheme stripped.
  asset,

  /// Local file on disk (imported audio).
  file,

  /// Remote `http`/`https` URL.
  network,
}

/// Represents an audio file metadata event (Kind 1063)
/// for the audio reuse feature.
///
/// Published when a user opts in to make their audio available for reuse.
/// Contains metadata about the audio file including URL, MIME type, duration,
/// and a reference to the source video (Kind 34236).
///
/// See NIP-94 for the full file metadata specification.
@immutable
class AudioEvent {
  /// Creates a new AudioEvent, normalizing its display text to well-formed
  /// UTF-16.
  ///
  /// Kind 1063 tags are remote text that reaches layout verbatim — the sound
  /// detail screen and the public-credit editor render [title], [source],
  /// [creatorName] and [licenseName] as plain `Text`, and [publicTags] as
  /// chips. Flutter's paragraph builder throws `Invalid argument(s): string
  /// is not well-formed UTF-16` on a lone surrogate, so this constructor is
  /// the display boundary, matching `UserProfile` and `VideoEvent`. Every
  /// factory below funnels through it, so a poisoned tag is repaired once at
  /// the point the event becomes a typed model rather than at each widget.
  ///
  /// [url], [proxyId], [sha256], [mimeType] and the id/reference fields are
  /// left untouched: they select a playback source or address an event, never
  /// reach text layout, and rewriting a code unit inside one would change
  /// which file is resolved.
  AudioEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    this.url,
    this.mimeType,
    this.sha256,
    this.fileSize,
    this.duration,
    String? title,
    String? source,
    this.sourceVideoReference,
    this.sourceVideoRelay,
    this.externalSource,
    String? creatorName,
    this.creatorPubkey,
    this.creatorUrl,
    String? licenseName,
    this.licenseUrl,
    List<String> publicTags = const [],
    this.proxyId,
    this.proxyProtocol,
    this.startOffset = Duration.zero,
    this.volume = 1.0,
    this.startTime = Duration.zero,
    this.endTime,
    this.anchorClipId,
    this.allowsReuse = true,
    this.hasExplicitReuseConsent = false,
  }) : title = sanitizeUtf16OrNull(title),
       source = sanitizeUtf16OrNull(source),
       creatorName = sanitizeUtf16OrNull(creatorName),
       licenseName = sanitizeUtf16OrNull(licenseName),
       publicTags = sanitizeUtf16List(publicTags);

  /// Parse an AudioEvent from a Nostr Event.
  ///
  /// Throws [ArgumentError] if the event is not Kind 1063.
  /// Follows Postel's law: be liberal in what you accept from others.
  factory AudioEvent.fromNostrEvent(Event event) {
    if (event.kind != audioEventKind) {
      throw ArgumentError(
        'Event must be Kind $audioEventKind (audio file metadata), '
        'got Kind ${event.kind}',
      );
    }

    String? url;
    String? mimeType;
    String? sha256;
    int? fileSize;
    double? duration;
    String? title;
    String? source;
    String? sourceVideoReference;
    String? sourceVideoRelay;
    String? creatorName;
    String? creatorPubkey;
    String? creatorUrl;
    String? licenseName;
    String? licenseUrl;
    final publicTags = <String>[];
    String? proxyId;
    String? proxyProtocol;
    var allowsReuse = false;
    var hasExplicitReuseConsent = false;

    // Parse tags according to NIP-94
    for (final tagRaw in event.tags) {
      if (tagRaw.isEmpty) continue;

      final tag = tagRaw.map((e) => e).toList();
      final tagName = tag[0];
      final tagValue = tag.length > 1 ? tag[1] : '';

      switch (tagName) {
        case 'url':
          url = tagValue.isNotEmpty ? tagValue : null;
        case 'm':
          mimeType = tagValue.isNotEmpty ? tagValue : null;
        case 'x':
          sha256 = tagValue.isNotEmpty ? tagValue : null;
        case 'size':
          fileSize = int.tryParse(tagValue);
        case 'duration':
          duration = double.tryParse(tagValue);
        case 'title':
          title = tagValue.isNotEmpty ? tagValue : null;
        case 'source':
          source = tagValue.isNotEmpty ? tagValue : null;
        case 'allow_audio_reuse':
          hasExplicitReuseConsent = true;
          allowsReuse = tagValue == 'true';
        case 'creator':
          creatorName = tagValue.isNotEmpty ? tagValue : null;
        case 'p':
          creatorPubkey ??= tagValue.isNotEmpty ? tagValue : null;
        case 'creator_url':
          creatorUrl = tagValue.isNotEmpty ? tagValue : null;
        case 'license':
          licenseName = tagValue.isNotEmpty ? tagValue : null;
        case 'license_url':
          licenseUrl = tagValue.isNotEmpty ? tagValue : null;
        case 't':
          if (tagValue.trim().isNotEmpty) {
            publicTags.add(tagValue.trim());
          }
        case 'proxy':
          if (tagValue.isNotEmpty && tag.length > 2 && tag[2].isNotEmpty) {
            proxyId = tagValue;
            proxyProtocol = tag[2];
          }
        case 'a':
          // Addressable reference to source video: "34236:<pubkey>:<d-tag>"
          sourceVideoReference = tagValue.isNotEmpty ? tagValue : null;
          // Optional relay hint is the third element
          if (tag.length > 2 && tag[2].isNotEmpty) {
            sourceVideoRelay = tag[2];
          }
      }
    }

    return AudioEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      url: url,
      mimeType: mimeType,
      sha256: sha256,
      fileSize: fileSize,
      duration: duration,
      title: title,
      source: source,
      sourceVideoReference: sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay,
      creatorName: creatorName,
      creatorPubkey: creatorPubkey,
      creatorUrl: creatorUrl,
      licenseName: licenseName,
      licenseUrl: licenseUrl,
      publicTags: _normalizedStringList(publicTags),
      proxyId: proxyId,
      proxyProtocol: proxyProtocol,
      allowsReuse: allowsReuse,
      hasExplicitReuseConsent: hasExplicitReuseConsent,
    );
  }

  /// Create an AudioEvent from a bundled VineSound asset.
  ///
  /// Uses a special `asset://` URL scheme to indicate this is a bundled sound.
  /// The ID is prefixed with [bundledMarker] to distinguish from Nostr events.
  ///
  /// Usage:
  /// ```dart
  /// final audioEvent = AudioEvent.fromBundledSound(vineSound);
  /// if (audioEvent.isBundled) {
  ///   // Play from assets
  /// }
  /// ```
  factory AudioEvent.fromBundledSound(VineSound sound, {int index = 0}) {
    String? source;
    if (sound.artist != null) {
      source =
          sound.sourceUrl != null && sound.sourceUrl!.contains('freesound.org')
          ? '${sound.artist} via Freesound'
          : sound.artist;
    }

    return AudioEvent(
      id: '${bundledMarker}_${sound.id}',
      pubkey: bundledMarker, // Indicates this is not from a Nostr user
      createdAt: index, // List position as recency proxy
      url: 'asset://${sound.assetPath}',
      mimeType: 'audio/mpeg',
      duration: sound.durationInSeconds,
      title: sound.title,
      source: source,
    );
  }

  /// Create a synthetic AudioEvent from a video's audio track.
  ///
  /// Uses the video URL as the audio source. The audio player can extract
  /// the audio track from video files. The ID is prefixed with `video_`
  /// to distinguish from real Kind 1063 events.
  ///
  /// When [creatorName] is provided the [title] reads
  /// `Original sound - $creatorName`; when omitted the [title] is left null so
  /// the display can
  /// resolve the creator from [pubkey] and localize the "Original sound"
  /// label itself (used when synthesizing attribution for a reused original
  /// sound, where the reader owns the localization).
  factory AudioEvent.fromVideoOriginalSound(
    VideoEvent video, {
    String? creatorName,
  }) {
    final reuseTerms = originalSoundReuseTerms(video);
    return AudioEvent(
      id: 'video_${video.id}',
      pubkey: video.pubkey,
      createdAt: video.createdAt,
      url: video.videoUrl,
      duration: video.duration?.toDouble(),
      title: creatorName == null ? null : 'Original sound - $creatorName',
      source: 'Original Sound',
      sourceVideoReference: video.addressableId,
      allowsReuse: reuseTerms ?? false,
      hasExplicitReuseConsent: reuseTerms != null,
    );
  }

  /// Create a draft-local AudioEvent for an imported audio file.
  factory AudioEvent.fromLocalImport({
    required String id,
    required String filePath,
    required int createdAt,
    required String title,
    required String mimeType,
    double? duration,
  }) {
    return AudioEvent(
      id: id,
      pubkey: localImportMarker,
      createdAt: createdAt,
      url: filePath,
      mimeType: mimeType,
      duration: duration,
      title: title,
      source: 'Imported audio',
    );
  }

  /// Deserialize from JSON for draft restoration.
  factory AudioEvent.fromJson(Map<String, dynamic> json) {
    return AudioEvent(
      id: json['id'] as String,
      pubkey: json['pubkey'] as String,
      createdAt: json['createdAt'] as int,
      url: json['url'] as String?,
      mimeType: json['mimeType'] as String?,
      sha256: json['sha256'] as String?,
      fileSize: json['fileSize'] as int?,
      duration: json['duration'] as double?,
      title: json['title'] as String?,
      source: json['source'] as String?,
      sourceVideoReference: json['sourceVideoReference'] as String?,
      sourceVideoRelay: json['sourceVideoRelay'] as String?,
      externalSource: _parseExternalSource(json['externalSource']),
      creatorName: json['creatorName'] as String?,
      creatorPubkey: json['creatorPubkey'] as String?,
      creatorUrl: json['creatorUrl'] as String?,
      licenseName: json['licenseName'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
      publicTags: _normalizedStringList(json['publicTags']),
      proxyId: json['proxyId'] as String?,
      proxyProtocol: json['proxyProtocol'] as String?,
      startOffset: json['startOffsetMs'] != null
          ? Duration(milliseconds: json['startOffsetMs'] as int)
          : Duration.zero,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      startTime: json['startTimeMs'] != null
          ? Duration(milliseconds: json['startTimeMs'] as int)
          : Duration.zero,
      endTime: json['endTimeMs'] != null
          ? Duration(milliseconds: json['endTimeMs'] as int)
          : null,
      anchorClipId: json['anchorClipId'] as String?,
      // Persisted events without a consent field predate the reuse policy.
      // Treat them as unknown and let the source-video resolver decide;
      // defaulting to true would silently grant remix permission.
      allowsReuse: json['allowsReuse'] as bool? ?? false,
      hasExplicitReuseConsent:
          json['hasExplicitReuseConsent'] as bool? ?? false,
    );
  }

  /// Marker for bundled sounds to distinguish from Nostr events.
  /// Used as ID prefix (with underscore) and as pubkey value.
  static const bundledMarker = 'bundled';

  /// Marker for draft-local imported audio.
  static const localImportMarker = 'local_import';

  /// Marker for audio the editor extracted from one of a draft's own clips.
  ///
  /// Deliberately not [localImportMarker]: an extracted track is the video's
  /// own sound rather than material the user brought in, so it must stay out
  /// of the reuse-consent and attribution paths that key on
  /// [isLocalImport]. It is still a draft-local file, which [localFilePath]
  /// and [isDraftLocalAudio] cover.
  static const localExtractedMarker = 'local_extracted';

  /// Marker for sounds resolved from server-side external provider search.
  static const externalProviderMarker = 'external_provider';

  /// Whether this audio is derived from a video's original sound.
  bool get isOriginalSound => id.startsWith('video_');

  /// The Nostr event id a reusing video should reference in its
  /// `["e", <id>, <relay>, "audio"]` attribution tag, or `null` when this
  /// audio has no referenceable Nostr event (bundled sounds, or imported
  /// audio that hasn't been published yet).
  ///
  /// Resolves two id shapes on top of a plain Kind 1063 event id:
  /// * a reused *original sound*, whose [id] is `video_<eventId>` — the source
  ///   Kind 34236 video's own event id (see
  ///   [AudioEvent.fromVideoOriginalSound]); and
  /// * an editor timeline track, whose id carries a trailing `-<timestamp>`
  ///   uniqueness suffix (and, after a duplicate/split, one or more
  ///   `_copy_<micros>` suffixes) so the same sound can appear on the
  ///   timeline more than once.
  ///
  /// Without this the `video_` prefix / timeline suffix make the id fail a
  /// 32-byte-hex check, the attribution tag is dropped at publish, and the
  /// reused audio is mislabelled as the reusing user's original sound.
  String? get attributionEventId {
    var candidate = isOriginalSound ? id.substring('video_'.length) : id;
    // Recover the leading 64-hex event id, dropping any editor-added
    // uniqueness/duplicate suffixes (`-<timestamp>`, `_copy_<micros>`, or a
    // chain of them).
    final base = RegExp(
      r'^([0-9a-fA-F]{64})(?:[-_].*)?$',
    ).firstMatch(candidate);
    if (base != null) candidate = base.group(1)!;
    return NostrHexUtils.isValidEventId(candidate) ? candidate : null;
  }

  /// Whether this track is a video's original sound that is still anchored to
  /// one of the editor's clips.
  ///
  /// Clip-anchored original sound is controlled through its source clip's
  /// volume arc, so the timeline volume panel hides its individual arc. A
  /// standalone original sound the user *added* from another video
  /// (`anchorClipId == null`) is not clip-anchored and therefore keeps its
  /// own volume arc — unlike [isOriginalSound] alone, which would also hide
  /// those added tracks.
  bool get isClipAnchoredOriginalSound => isOriginalSound && isAnchored;

  /// Whether this audio is a bundled sound (from app assets).
  bool get isBundled => id.startsWith('${bundledMarker}_');

  /// Whether this audio is a draft-local imported file.
  bool get isLocalImport => id.startsWith('${localImportMarker}_');

  /// Whether this audio was extracted from one of the draft's own clips.
  bool get isLocalExtracted => id.startsWith('${localExtractedMarker}_');

  /// Whether this audio is backed by a file this device wrote for a draft.
  ///
  /// Covers imported audio, voice-over takes (both [isLocalImport]) and
  /// extracted clip audio. Distinct from [isLocalImport], which additionally
  /// means "material the user brought in" and so gates reuse consent and
  /// attribution.
  bool get isDraftLocalAudio => isLocalImport || isLocalExtracted;

  /// Local file path for draft-local audio.
  ///
  /// Returns null for bundled and published Nostr audio.
  String? get localFilePath {
    if (!isDraftLocalAudio || url == null || url!.isEmpty) return null;
    return url;
  }

  /// Whether this audio came from a normalized external sound provider.
  bool get isExternalProviderSound => externalSource != null;

  /// Get the asset path for bundled sounds.
  /// Returns null if this is not a bundled sound.
  String? get assetPath {
    if (!isBundled || url == null) return null;
    const prefix = 'asset://';
    if (url!.startsWith(prefix)) {
      return url!.substring(prefix.length);
    }
    return null;
  }

  /// Classifies the playable source for this audio and returns the matching
  /// path, or `null` when no usable source exists.
  ///
  /// Imported audio stores its on-disk path in [url]; it must be loaded as a
  /// file rather than parsed as a network URL (which fails with "No host
  /// specified in URI" / iOS "unsupported URL"). Bundled sounds expose a bare
  /// asset path. Bare absolute paths (`/var/mobile/...`) and `file://` URIs —
  /// e.g. clip-extracted J-cut audio whose [url] is a raw on-disk path — are
  /// also classified as files, matching the `#4395` file-vs-network guard used
  /// at the duration/render/waveform call sites so this getter is a true
  /// superset they can migrate onto without reintroducing that bug. Everything
  /// else (`http(s)`, plus unhandled schemes like `content://`/`blob:`) is
  /// network.
  ({AudioSourceKind kind, String path})? get resolvedSource {
    if (isBundled) {
      final path = assetPath;
      return path == null || path.isEmpty
          ? null
          : (kind: AudioSourceKind.asset, path: path);
    }
    if (isLocalImport) {
      final path = localFilePath;
      return path == null || path.isEmpty
          ? null
          : (kind: AudioSourceKind.file, path: path);
    }
    final rawUrl = url;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final parsed = Uri.tryParse(rawUrl);
    final isLocalFile =
        parsed == null ||
        parsed.scheme.isEmpty ||
        parsed.scheme == 'file' ||
        rawUrl.startsWith('/');
    if (isLocalFile) {
      final filePath = parsed != null && parsed.scheme == 'file'
          ? parsed.toFilePath()
          : rawUrl;
      return (kind: AudioSourceKind.file, path: filePath);
    }
    return (kind: AudioSourceKind.network, path: rawUrl);
  }

  /// The Nostr event ID (64-character hex string).
  final String id;

  /// The public key of the audio creator.
  final String pubkey;

  /// Unix timestamp when the event was created.
  final int createdAt;

  /// Blossom audio file URL.
  final String? url;

  /// MIME type of the audio file (e.g., "audio/aac", "audio/mp4").
  final String? mimeType;

  /// SHA-256 hash of the audio file.
  final String? sha256;

  /// File size in bytes.
  final int? fileSize;

  /// Duration in seconds.
  final double? duration;

  /// Audio title (e.g., "Original sound - @username").
  final String? title;

  /// Source attribution (e.g., "Original Sound", "Spotify", "SoundCloud").
  final String? source;

  /// Addressable reference to source video in format "kind:pubkey:d-tag".
  /// For OpenVine videos: `34236:<pubkey>:<vine-id>`
  final String? sourceVideoReference;

  /// Optional relay hint for the source video.
  final String? sourceVideoRelay;

  /// Normalized source, attribution, and license metadata for proxy-backed
  /// sounds from Freesound, Openverse, or future providers.
  final AudioExternalSource? externalSource;

  /// Public creator name included when this sound is shared.
  final String? creatorName;

  /// Public Nostr pubkey of the credited creator.
  final String? creatorPubkey;

  /// Public profile or portfolio URL for the credited creator.
  final String? creatorUrl;

  /// Human-readable public license name.
  final String? licenseName;

  /// Canonical public license URL.
  final String? licenseUrl;

  /// Public catalog tags. These are distinct from private library hashtags.
  final List<String> publicTags;

  /// Provider-native identifier used by a sound proxy.
  final String? proxyId;

  /// Provider protocol paired with [proxyId], such as `freesound`.
  final String? proxyProtocol;

  /// Start offset within the audio track.
  ///
  /// This is the point from which the audio will start
  /// playing during video playback. Default is
  /// [Duration.zero] (start from beginning). Only used
  /// locally, not published to Nostr.
  final Duration startOffset;

  /// Volume of the audio track (0.0 silent, 1.0 full).
  final double volume;

  /// The time on the editor timeline where this audio event starts playing.
  /// Default is [Duration.zero] (start of the timeline).
  final Duration startTime;

  /// The time on the editor timeline where this audio event stops playing.
  /// If null, the audio plays until the end of its duration.
  final Duration? endTime;

  /// ID of the `DivineVideoClip` this audio was extracted from and is
  /// currently anchored to.
  ///
  /// When non-null, the audio is "anchored": editing the source clip's
  /// trim (e.g. trimming its left edge) keeps the audio aligned with the
  /// clip's source content so a J-Cut can be created without losing sync.
  /// Set when audio is extracted from a clip; cleared (set to `null`) when
  /// the user manually moves the audio on the timeline, after which it
  /// behaves as an independent, free-floating track.
  ///
  /// Local-only editor state, never published to Nostr.
  final String? anchorClipId;

  /// Whether the source creator permits this sound to be reused by others.
  ///
  /// Parsed Kind 1063 events fail closed: only an explicit
  /// `allow_audio_reuse=true` tag enables reuse. The constructor retains a
  /// `true` default for bundled and existing in-memory app sounds.
  final bool allowsReuse;

  /// Whether this event carries definitive audio-reuse terms.
  ///
  /// Parsed Kind 1063 events set this only for an explicit consent tag.
  /// Synthetic original sounds also set it when their source video policy is
  /// definitive, including the classic Vine compatibility verdict. This
  /// distinguishes those results from legacy events that still need lookup.
  final bool hasExplicitReuseConsent;

  /// Whether this audio is currently anchored to a source video clip.
  bool get isAnchored => anchorClipId != null;

  /// Get the kind number from the source video reference.
  /// Returns null if no source video reference is set.
  int? get sourceVideoKind {
    if (sourceVideoReference == null) return null;
    final parts = sourceVideoReference!.split(':');
    if (parts.isEmpty) return null;
    return int.tryParse(parts[0]);
  }

  /// Get the pubkey from the source video reference.
  /// Returns null if no source video reference is set or format is invalid.
  String? get sourceVideoPubkey {
    if (sourceVideoReference == null) return null;
    final parts = sourceVideoReference!.split(':');
    if (parts.length < 2) return null;
    return parts[1];
  }

  /// Get the d-tag identifier from the source video reference.
  /// Returns null if no source video reference is set or format is invalid.
  String? get sourceVideoIdentifier {
    if (sourceVideoReference == null) return null;
    final parts = sourceVideoReference!.split(':');
    if (parts.length < 3) return null;
    return parts[2];
  }

  /// Get formatted duration string (e.g., "0:06", "1:05").
  /// Returns empty string if duration is null.
  String get formattedDuration {
    if (duration == null) return '';
    final totalSeconds = duration!.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get file size in kilobytes.
  /// Returns null if file size is not set.
  double? get fileSizeKB {
    if (fileSize == null) return null;
    return fileSize! / 1024.0;
  }

  /// Generate tags list for publishing this audio event.
  ///
  /// Only includes tags for non-null fields.
  List<List<String>> toTags() {
    final tags = <List<String>>[];

    if (url != null) {
      tags.add(['url', url!]);
    }

    if (mimeType != null) {
      tags.add(['m', mimeType!]);
    }

    if (sha256 != null) {
      tags.add(['x', sha256!]);
    }

    if (fileSize != null) {
      tags.add(['size', fileSize.toString()]);
    }

    if (duration != null) {
      tags.add(['duration', duration.toString()]);
    }

    if (title != null) {
      tags.add(['title', title!]);
    }

    if (source != null) {
      tags.add(['source', source!]);
    }

    tags.add(['allow_audio_reuse', allowsReuse.toString()]);

    if (creatorName?.trim().isNotEmpty ?? false) {
      tags.add(['creator', creatorName!.trim()]);
    }
    if (creatorPubkey?.trim().isNotEmpty ?? false) {
      tags.add(['p', creatorPubkey!.trim()]);
    }
    if (creatorUrl?.trim().isNotEmpty ?? false) {
      tags.add(['creator_url', creatorUrl!.trim()]);
    }
    if (licenseName?.trim().isNotEmpty ?? false) {
      tags.add(['license', licenseName!.trim()]);
    }
    if (licenseUrl?.trim().isNotEmpty ?? false) {
      tags.add(['license_url', licenseUrl!.trim()]);
    }
    for (final publicTag in _normalizedStringList(publicTags)) {
      tags.add(['t', publicTag]);
    }
    if ((proxyId?.trim().isNotEmpty ?? false) &&
        (proxyProtocol?.trim().isNotEmpty ?? false)) {
      tags.add(['proxy', proxyId!.trim(), proxyProtocol!.trim()]);
    }

    if (sourceVideoReference != null) {
      if (sourceVideoRelay != null) {
        tags.add(['a', sourceVideoReference!, sourceVideoRelay!]);
      } else {
        tags.add(['a', sourceVideoReference!]);
      }
    }

    return tags;
  }

  /// Create a copy with updated fields.
  AudioEvent copyWith({
    String? id,
    String? pubkey,
    int? createdAt,
    String? url,
    String? mimeType,
    String? sha256,
    int? fileSize,
    double? duration,
    String? title,
    String? source,
    String? sourceVideoReference,
    String? sourceVideoRelay,
    AudioExternalSource? externalSource,
    String? creatorName,
    String? creatorPubkey,
    String? creatorUrl,
    String? licenseName,
    String? licenseUrl,
    List<String>? publicTags,
    String? proxyId,
    String? proxyProtocol,
    Duration? startOffset,
    double? volume,
    Duration? startTime,
    Duration? endTime,
    String? anchorClipId,
    bool clearAnchorClipId = false,
    bool? allowsReuse,
    bool? hasExplicitReuseConsent,
  }) {
    return AudioEvent(
      id: id ?? this.id,
      pubkey: pubkey ?? this.pubkey,
      createdAt: createdAt ?? this.createdAt,
      url: url ?? this.url,
      mimeType: mimeType ?? this.mimeType,
      sha256: sha256 ?? this.sha256,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      title: title ?? this.title,
      source: source ?? this.source,
      sourceVideoReference: sourceVideoReference ?? this.sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay ?? this.sourceVideoRelay,
      externalSource: externalSource ?? this.externalSource,
      creatorName: creatorName ?? this.creatorName,
      creatorPubkey: creatorPubkey ?? this.creatorPubkey,
      creatorUrl: creatorUrl ?? this.creatorUrl,
      licenseName: licenseName ?? this.licenseName,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      publicTags: publicTags ?? this.publicTags,
      proxyId: proxyId ?? this.proxyId,
      proxyProtocol: proxyProtocol ?? this.proxyProtocol,
      startOffset: startOffset ?? this.startOffset,
      volume: volume ?? this.volume,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      anchorClipId: clearAnchorClipId
          ? null
          : (anchorClipId ?? this.anchorClipId),
      allowsReuse: allowsReuse ?? this.allowsReuse,
      hasExplicitReuseConsent:
          hasExplicitReuseConsent ?? this.hasExplicitReuseConsent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioEvent &&
        other.id == id &&
        other.startOffset == startOffset &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.anchorClipId == anchorClipId;
  }

  @override
  int get hashCode =>
      Object.hash(id, startOffset, startTime, endTime, anchorClipId);

  @override
  String toString() {
    return 'AudioEvent('
        'id: $id, '
        'title: $title, '
        'duration: $duration'
        ')';
  }

  /// Serialize to JSON for draft persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'pubkey': pubkey,
    'createdAt': createdAt,
    'url': ?url,
    'mimeType': ?mimeType,
    'sha256': ?sha256,
    'fileSize': ?fileSize,
    'duration': ?duration,
    'title': ?title,
    'source': ?source,
    'sourceVideoReference': ?sourceVideoReference,
    'sourceVideoRelay': ?sourceVideoRelay,
    'creatorName': ?creatorName,
    'creatorPubkey': ?creatorPubkey,
    'creatorUrl': ?creatorUrl,
    'licenseName': ?licenseName,
    'licenseUrl': ?licenseUrl,
    if (publicTags.isNotEmpty) 'publicTags': publicTags,
    'proxyId': ?proxyId,
    'proxyProtocol': ?proxyProtocol,
    'allowsReuse': allowsReuse,
    'hasExplicitReuseConsent': hasExplicitReuseConsent,
    // Always serialize volume so history and draft snapshots preserve
    // explicit user edits instead of relying on an implicit default.
    'volume': volume,
    if (externalSource != null) 'externalSource': externalSource!.toJson(),
    if (startOffset != .zero) 'startOffsetMs': startOffset.inMilliseconds,
    if (startTime != Duration.zero) 'startTimeMs': startTime.inMilliseconds,
    if (endTime != null) 'endTimeMs': endTime!.inMilliseconds,
    'anchorClipId': ?anchorClipId,
  };
}

AudioExternalSource? _parseExternalSource(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  return AudioExternalSource.fromJson(value);
}

/// Normalized metadata for a sound result served by the sound library proxy.
@immutable
class AudioExternalSource {
  /// Creates external-source metadata, normalizing its display text to
  /// well-formed UTF-16.
  ///
  /// The proxy normalizes third-party catalog data (Freesound, Openverse) but
  /// does not own the strings inside it, and the sound detail screen renders
  /// [providerName], [creatorName] and [catalogTags] directly. See
  /// [AudioEvent] for why the constructor is the boundary.
  AudioExternalSource({
    required this.provider,
    required this.providerSoundId,
    required String providerName,
    required this.license,
    String? creatorName,
    this.creatorUrl,
    this.sourceUrl,
    this.previewUrl,
    List<String> catalogTags = const [],
  }) : providerName = sanitizeUtf16(providerName),
       creatorName = sanitizeUtf16OrNull(creatorName),
       catalogTags = sanitizeUtf16List(catalogTags);

  factory AudioExternalSource.fromJson(Map<String, dynamic> json) {
    final licenseJson = json['license'];
    if (licenseJson is! Map<String, dynamic>) {
      throw const FormatException('External audio source missing license');
    }

    return AudioExternalSource(
      provider: json['provider'] as String,
      providerSoundId: json['providerSoundId'] as String,
      providerName: json['providerName'] as String,
      creatorName: json['creatorName'] as String?,
      creatorUrl: json['creatorUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      catalogTags: _normalizedStringList(json['catalogTags']),
      license: AudioLicenseMetadata.fromJson(licenseJson),
    );
  }

  final String provider;
  final String providerSoundId;
  final String providerName;
  final String? creatorName;
  final String? creatorUrl;
  final String? sourceUrl;
  final String? previewUrl;
  final List<String> catalogTags;
  final AudioLicenseMetadata license;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'providerSoundId': providerSoundId,
    'providerName': providerName,
    'creatorName': ?creatorName,
    'creatorUrl': ?creatorUrl,
    'sourceUrl': ?sourceUrl,
    'previewUrl': ?previewUrl,
    'catalogTags': catalogTags,
    'license': license.toJson(),
  };

  @override
  bool operator ==(Object other) {
    return other is AudioExternalSource &&
        other.provider == provider &&
        other.providerSoundId == providerSoundId &&
        other.providerName == providerName &&
        other.creatorName == creatorName &&
        other.creatorUrl == creatorUrl &&
        other.sourceUrl == sourceUrl &&
        other.previewUrl == previewUrl &&
        _stringListsEqual(other.catalogTags, catalogTags) &&
        other.license == license;
  }

  @override
  int get hashCode => Object.hash(
    provider,
    providerSoundId,
    providerName,
    creatorName,
    creatorUrl,
    sourceUrl,
    previewUrl,
    Object.hashAll(catalogTags),
    license,
  );
}

List<String> _normalizedStringList(Object? value) {
  if (value is! List) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final item in value.whereType<String>()) {
    final trimmed = item.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
      result.add(trimmed);
    }
  }
  return List.unmodifiable(result);
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// License metadata that has already been normalized by the sound proxy.
@immutable
class AudioLicenseMetadata {
  /// Creates license metadata, normalizing [name] to well-formed UTF-16.
  ///
  /// [name] is the human-readable licence label the credit UI renders;
  /// [type] and [url] are machine values. See [AudioEvent].
  AudioLicenseMetadata({
    required this.type,
    required String name,
    required this.url,
    required this.allowsCommercialUse,
    required this.allowsDerivatives,
    required this.requiresAttribution,
  }) : name = sanitizeUtf16(name);

  factory AudioLicenseMetadata.fromJson(Map<String, dynamic> json) {
    return AudioLicenseMetadata(
      type: json['type'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      allowsCommercialUse: json['allowsCommercialUse'] as bool,
      allowsDerivatives: json['allowsDerivatives'] as bool? ?? true,
      requiresAttribution: json['requiresAttribution'] as bool,
    );
  }

  final String type;
  final String name;
  final String url;
  final bool allowsCommercialUse;
  final bool allowsDerivatives;
  final bool requiresAttribution;

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'url': url,
    'allowsCommercialUse': allowsCommercialUse,
    'allowsDerivatives': allowsDerivatives,
    'requiresAttribution': requiresAttribution,
  };

  @override
  bool operator ==(Object other) {
    return other is AudioLicenseMetadata &&
        other.type == type &&
        other.name == name &&
        other.url == url &&
        other.allowsCommercialUse == allowsCommercialUse &&
        other.allowsDerivatives == allowsDerivatives &&
        other.requiresAttribution == requiresAttribution;
  }

  @override
  int get hashCode => Object.hash(
    type,
    name,
    url,
    allowsCommercialUse,
    allowsDerivatives,
    requiresAttribution,
  );
}
