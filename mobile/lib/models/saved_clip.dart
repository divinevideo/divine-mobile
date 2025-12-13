// ABOUTME: Data model for a saved video clip in the clip library
// ABOUTME: Supports JSON serialization, thumbnails, and display formatting

class SavedClip {
  const SavedClip({
    required this.id,
    required this.filePath,
    required this.thumbnailPath,
    required this.duration,
    required this.createdAt,
    required this.aspectRatio,
  });

  final String id;
  final String filePath;
  final String? thumbnailPath;
  final Duration duration;
  final DateTime createdAt;
  final String aspectRatio;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  String get displayDuration {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inDays > 0) {
      return '${elapsed.inDays}d ago';
    } else if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ago';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  SavedClip copyWith({
    String? id,
    String? filePath,
    String? thumbnailPath,
    Duration? duration,
    DateTime? createdAt,
    String? aspectRatio,
  }) {
    return SavedClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'durationMs': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'aspectRatio': aspectRatio,
    };
  }

  factory SavedClip.fromJson(Map<String, dynamic> json) {
    return SavedClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
      aspectRatio: json['aspectRatio'] as String,
    );
  }

  @override
  String toString() {
    return 'SavedClip(id: $id, duration: ${durationInSeconds}s, aspectRatio: $aspectRatio)';
  }
}
