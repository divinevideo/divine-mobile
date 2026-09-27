/// View metrics returned for a single video.
class VideoViewStats {
  /// Creates a response containing whichever metrics are available.
  const VideoViewStats({this.views, this.uniqueViewers});

  /// Parses the views endpoint response without combining the metrics.
  factory VideoViewStats.fromJson(Map<String, dynamic> json) {
    return VideoViewStats(
      views: _parseCount(
        json['views'] ?? json['view_count'] ?? json['total_views'],
      ),
      uniqueViewers: _parseCount(
        json['unique_viewers'] ?? json['unique_views'],
      ),
    );
  }

  /// Total number of times the video was viewed.
  final int? views;

  /// Number of distinct people who viewed the video.
  final int? uniqueViewers;

  static int? _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
