// ABOUTME: Data model for classic Vine audio tracks in the Sound Picker
// ABOUTME: Supports metadata, tags for search, and JSON serialization

class VineSound {
  VineSound({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.duration,
    this.artist,
    this.tags = const [],
    this.license,
    this.licenseUrl,
    this.sourceUrl,
    this.isExcerpt = false,
  });

  factory VineSound.fromJson(Map<String, dynamic> json) {
    return VineSound(
      id: json['id'] as String,
      title: json['title'] as String,
      assetPath: json['assetPath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      artist: json['artist'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      license: json['license'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      isExcerpt: json['excerpt'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String assetPath;
  final Duration duration;
  final String? artist;
  final List<String> tags;
  final String? license;
  final String? licenseUrl;
  final String? sourceUrl;

  /// Whether the app ships only a cut of a longer recording, which an
  /// Attribution licence asks the sound's credit to say (CC BY 4.0
  /// §3(a)(1)(B)). The manifest's `excerpt` key.
  final bool isExcerpt;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();

    if (title.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    if (artist != null && artist!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    for (final tag in tags) {
      if (tag.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'assetPath': assetPath,
      'durationMs': duration.inMilliseconds,
      'artist': artist,
      'tags': tags,
      'license': license,
      'licenseUrl': licenseUrl,
      'sourceUrl': sourceUrl,
      if (isExcerpt) 'excerpt': true,
    };
  }

  @override
  String toString() {
    return 'VineSound(id: $id, title: $title)';
  }
}
