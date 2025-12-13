// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, and JSON serialization for persistence

class RecordingClip {
  RecordingClip({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.orderIndex,
    required this.recordedAt,
    this.thumbnailPath,
  });

  final String id;
  final String filePath;
  final Duration duration;
  final int orderIndex;
  final DateTime recordedAt;
  final String? thumbnailPath;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  RecordingClip copyWith({
    String? id,
    String? filePath,
    Duration? duration,
    int? orderIndex,
    DateTime? recordedAt,
    String? thumbnailPath,
  }) {
    return RecordingClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      orderIndex: orderIndex ?? this.orderIndex,
      recordedAt: recordedAt ?? this.recordedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'durationMs': duration.inMilliseconds,
      'orderIndex': orderIndex,
      'recordedAt': recordedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory RecordingClip.fromJson(Map<String, dynamic> json) {
    return RecordingClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      orderIndex: json['orderIndex'] as int,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s, order: $orderIndex)';
  }
}
