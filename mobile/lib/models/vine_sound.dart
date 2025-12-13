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
  });

  final String id;
  final String title;
  final String assetPath;
  final Duration duration;
  final String? artist;
  final List<String> tags;

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
    };
  }

  factory VineSound.fromJson(Map<String, dynamic> json) {
    return VineSound(
      id: json['id'] as String,
      title: json['title'] as String,
      assetPath: json['assetPath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      artist: json['artist'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  String toString() {
    return 'VineSound(id: $id, title: $title)';
  }
}
