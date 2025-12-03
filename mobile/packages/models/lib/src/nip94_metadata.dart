// ABOUTME: NIP-94 File Metadata model for Nostr file sharing events
// ABOUTME: Handles vine content metadata structure and Nostr event generation

import 'package:nostr_sdk/event.dart';

// Simple key pair class to replace Keychain temporarily
class SimpleKeyPair {
  const SimpleKeyPair({required this.public, required this.private});
  final String public;
  final String private;
}

/// NIP-94 File Metadata for vine content sharing on Nostr
class NIP94Metadata {
  // Custom additional tags

  const NIP94Metadata({
    required this.url,
    required this.mimeType,
    required this.sha256Hash,
    required this.sizeBytes,
    required this.dimensions,
    this.blurhash,
    this.altText,
    this.summary,
    this.durationMs,
    this.fps,
    this.createdAt,
    this.thumbnailUrl,
    this.magnetLink,
    this.torrentHash,
    this.originalHash,
    this.additionalTags = const {},
  });

  /// Create NIP-94 metadata from GIF result and upload response
  factory NIP94Metadata.fromGifResult({
    required String url,
    required String sha256Hash,
    required int width,
    required int height,
    required int sizeBytes,
    String? summary,
    String? altText,
    String? blurhash,
    int? durationMs,
    double? fps,
    String? thumbnailUrl,
    String? originalHash,
    Map<String, String> additionalTags = const {},
  }) => NIP94Metadata(
    url: url,
    mimeType: 'image/gif',
    sha256Hash: sha256Hash,
    sizeBytes: sizeBytes,
    dimensions: '${width}x$height',
    blurhash: blurhash,
    altText: altText,
    summary: summary,
    durationMs: durationMs,
    fps: fps,
    createdAt: DateTime.now(),
    thumbnailUrl: thumbnailUrl,
    originalHash: originalHash,
    additionalTags: additionalTags,
  );

  /// Create NIP-94 metadata from JSON (backend response)
  factory NIP94Metadata.fromJson(Map<String, dynamic> json) => NIP94Metadata(
    url: json['url'] as String,
    mimeType: json['mime_type'] as String,
    sha256Hash: json['sha256'] as String,
    sizeBytes: json['size'] as int,
    dimensions: json['dimensions'] as String,
    blurhash: json['blurhash'] as String?,
    altText: json['alt_text'] as String?,
    summary: json['summary'] as String?,
    durationMs: json['duration_ms'] as int?,
    fps: json['fps'] as double?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    thumbnailUrl: json['thumbnail_url'] as String?,
    magnetLink: json['magnet_link'] as String?,
    torrentHash: json['torrent_hash'] as String?,
    originalHash: json['original_hash'] as String?,
    additionalTags:
        (json['additional_tags'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        {},
  );
  final String url; // File URL (Cloudflare Stream or IPFS)
  final String mimeType; // MIME type (image/gif, video/mp4, etc.)
  final String sha256Hash; // SHA256 hash of file content
  final int sizeBytes; // File size in bytes
  final String dimensions; // WIDTHxHEIGHT format
  final String? blurhash; // Blurhash for loading placeholder
  final String? altText; // Accessibility description
  final String? summary; // Content description/caption
  final int? durationMs; // Video duration in milliseconds
  final double? fps; // Frames per second
  final DateTime? createdAt; // Creation timestamp
  final String? thumbnailUrl; // Thumbnail image URL
  final String? magnetLink; // Magnet link for torrent sharing
  final String? torrentHash; // InfoHash for torrent
  final String? originalHash; // Hash of original file before processing
  final Map<String, String> additionalTags;

  /// Convert to JSON for backend upload
  Map<String, dynamic> toJson() => {
    'url': url,
    'mime_type': mimeType,
    'sha256': sha256Hash,
    'size': sizeBytes,
    'dimensions': dimensions,
    if (blurhash != null) 'blurhash': blurhash,
    if (altText != null) 'alt_text': altText,
    if (summary != null) 'summary': summary,
    if (durationMs != null) 'duration_ms': durationMs,
    if (fps != null) 'fps': fps,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (magnetLink != null) 'magnet_link': magnetLink,
    if (torrentHash != null) 'torrent_hash': torrentHash,
    if (originalHash != null) 'original_hash': originalHash,
    if (additionalTags.isNotEmpty) 'additional_tags': additionalTags,
  };

  /// Convert to Nostr event (NIP-94 kind 1063)
  Event toNostrEvent({
    required SimpleKeyPair keyPairs,
    required String content,
    List<String> hashtags = const [],
    List<String> customTags = const [],
  }) {
    final tags = <List<String>>[
      ['url', url],
      ['m', mimeType],
      ['x', sha256Hash],
      ['size', sizeBytes.toString()],
      ['dim', dimensions],
    ];

    // Add optional metadata tags
    if (blurhash != null) tags.add(['blurhash', blurhash!]);
    if (altText != null) tags.add(['alt', altText!]);
    if (summary != null) tags.add(['summary', summary!]);
    if (durationMs != null) {
      tags.add(['duration', (durationMs! / 1000).toString()]);
    }
    if (fps != null) tags.add(['fps', fps!.toString()]);
    if (thumbnailUrl != null) tags.add(['thumb', thumbnailUrl!]);
    if (magnetLink != null) tags.add(['magnet', magnetLink!]);
    if (torrentHash != null) tags.add(['torrent', torrentHash!]);
    if (originalHash != null) {
      tags.add(['ox', originalHash!]); // original file hash
    }

    // Add hashtags as 't' tags
    for (final hashtag in hashtags) {
      tags.add(['t', hashtag]);
    }

    // Add additional tags from the additionalTags map
    for (final entry in additionalTags.entries) {
      tags.add([entry.key, entry.value]);
    }

    // Add any additional custom tags (legacy support)
    for (final tag in customTags) {
      final parts = tag.split(':');
      if (parts.length >= 2) {
        tags.add([parts[0], parts.sublist(1).join(':')]);
      }
    }

    // Create event using nostr_sdk Event constructor
    final event = Event(
      keyPairs.public,
      1063, // NIP-94 File Metadata
      tags,
      content,
    );

    // Sign the event
    event.sign(keyPairs.private);

    return event;
  }

  /// Extract width from dimensions string
  int get width {
    final parts = dimensions.split('x');
    return parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  }

  /// Extract height from dimensions string
  int get height {
    final parts = dimensions.split('x');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  /// Get file size in MB
  double get fileSizeMB => sizeBytes / (1024 * 1024);

  /// Get duration in seconds
  double? get durationSeconds =>
      durationMs != null ? durationMs! / 1000.0 : null;

  /// Check if this is a GIF file
  bool get isGif => mimeType.toLowerCase() == 'image/gif';

  /// Check if this is a video file
  bool get isVideo => mimeType.toLowerCase().startsWith('video/');

  /// Validate metadata completeness
  bool get isValid =>
      url.isNotEmpty &&
      mimeType.isNotEmpty &&
      sha256Hash.isNotEmpty &&
      sha256Hash.length == 64 && // SHA256 is 64 hex chars
      sizeBytes > 0 &&
      dimensions.contains('x') &&
      width > 0 &&
      height > 0;

  /// Copy with updated fields
  NIP94Metadata copyWith({
    String? url,
    String? mimeType,
    String? sha256Hash,
    int? sizeBytes,
    String? dimensions,
    String? blurhash,
    String? altText,
    String? summary,
    int? durationMs,
    double? fps,
    DateTime? createdAt,
    String? thumbnailUrl,
    String? magnetLink,
    String? torrentHash,
    String? originalHash,
    Map<String, String>? additionalTags,
  }) => NIP94Metadata(
    url: url ?? this.url,
    mimeType: mimeType ?? this.mimeType,
    sha256Hash: sha256Hash ?? this.sha256Hash,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    dimensions: dimensions ?? this.dimensions,
    blurhash: blurhash ?? this.blurhash,
    altText: altText ?? this.altText,
    summary: summary ?? this.summary,
    durationMs: durationMs ?? this.durationMs,
    fps: fps ?? this.fps,
    createdAt: createdAt ?? this.createdAt,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    magnetLink: magnetLink ?? this.magnetLink,
    torrentHash: torrentHash ?? this.torrentHash,
    originalHash: originalHash ?? this.originalHash,
    additionalTags: additionalTags ?? this.additionalTags,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NIP94Metadata &&
        other.url == url &&
        other.mimeType == mimeType &&
        other.sha256Hash == sha256Hash &&
        other.sizeBytes == sizeBytes &&
        other.dimensions == dimensions;
  }

  @override
  int get hashCode =>
      Object.hash(url, mimeType, sha256Hash, sizeBytes, dimensions);

  @override
  String toString() =>
      'NIP94Metadata('
      'url: $url, '
      'type: $mimeType, '
      'size: ${fileSizeMB.toStringAsFixed(2)}MB, '
      'dimensions: $dimensions, '
      'hash: $sha256Hash'
      ')';
}

/// Exception thrown when NIP-94 metadata is invalid
class NIP94ValidationException implements Exception {
  const NIP94ValidationException(this.message);
  final String message;

  @override
  String toString() => 'NIP94ValidationException: $message';
}
