// ABOUTME: Tracks video download bandwidth across playback sessions
// ABOUTME: Uses rolling average to recommend original/720p/480p quality

import 'dart:collection';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Quality recommendation based on measured bandwidth
enum VideoQuality {
  /// Original MP4 - fast connections (>4 Mbps effective)
  high,

  /// 720p variant (~2.5 Mbps) - decent connections (2-4 Mbps)
  medium,

  /// 480p variant (~1 Mbps) - slow connections (<2 Mbps effective)
  low,
}

/// Tracks video download performance to recommend optimal quality.
///
/// Since videos are only 6 seconds, HLS adaptive bitrate doesn't have
/// time to adjust within a single video. Instead, we track performance
/// across videos and pick the right quality for the NEXT video.
///
/// Metrics tracked:
/// - Time to first frame (buffering latency)
/// - Estimated bandwidth based on video size and load time
class BandwidthTrackerService {
  BandwidthTrackerService._();

  static final BandwidthTrackerService _instance = BandwidthTrackerService._();
  static BandwidthTrackerService get instance => _instance;

  /// Rolling window of recent bandwidth samples (Mbps)
  final Queue<double> _bandwidthSamples = Queue();

  /// Maximum samples to keep
  static const int _maxSamples = 10;

  /// Threshold for switching to low quality (Mbps)
  /// 480p variant at ~1 Mbps needs at least 2 Mbps to stream smoothly
  static const double _lowQualityThreshold = 2.0;

  /// Threshold for switching to high (original) quality (Mbps)
  /// Original MP4 at full resolution needs fast connection
  static const double _highQualityThreshold = 4.0;

  /// Persisted quality preference key
  static const String _qualityPrefKey = 'video_quality_preference';

  /// User override (null = auto, otherwise forced quality)
  VideoQuality? _userOverride;

  /// Whether service is initialized
  bool _initialized = false;

  /// Initialize the service - loads persisted preferences
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedQuality = prefs.getString(_qualityPrefKey);

      if (savedQuality == 'high') {
        _userOverride = VideoQuality.high;
      } else if (savedQuality == 'medium') {
        _userOverride = VideoQuality.medium;
      } else if (savedQuality == 'low') {
        _userOverride = VideoQuality.low;
      } else {
        _userOverride = null; // Auto mode
      }

      _initialized = true;
      _log('Initialized with quality preference: ${_userOverride ?? "auto"}');
    } catch (e) {
      _log('Failed to load quality preference: $e');
      _initialized = true;
    }
  }

  /// Record a bandwidth sample from video playback
  ///
  /// [videoSizeBytes] - Size of video file in bytes
  /// [loadTimeMs] - Time to load/buffer the video in milliseconds
  void recordSample({required int videoSizeBytes, required int loadTimeMs}) {
    if (loadTimeMs <= 0 || videoSizeBytes <= 0) return;

    // Calculate bandwidth in Mbps
    // bytes / ms = KB/s, convert to Mbps
    final bytesPerMs = videoSizeBytes / loadTimeMs;
    final mbps = (bytesPerMs * 1000 * 8) / (1024 * 1024);

    _bandwidthSamples.addLast(mbps);
    while (_bandwidthSamples.length > _maxSamples) {
      _bandwidthSamples.removeFirst();
    }

    _log(
      'Recorded bandwidth sample: ${mbps.toStringAsFixed(2)} Mbps '
      '(${_bandwidthSamples.length} samples)',
    );
  }

  /// Get current average bandwidth estimate (Mbps)
  double get averageBandwidth {
    if (_bandwidthSamples.isEmpty) return 3.0; // Assume decent connection
    return _bandwidthSamples.reduce((a, b) => a + b) / _bandwidthSamples.length;
  }

  /// Get recommended quality based on measured bandwidth
  ///
  /// - `> 4 Mbps` → [VideoQuality.high] (original MP4)
  /// - `2-4 Mbps` → [VideoQuality.medium] (720p variant, ~2.5 Mbps)
  /// - `< 2 Mbps` → [VideoQuality.low] (480p variant, ~1 Mbps)
  VideoQuality get recommendedQuality {
    // User override takes precedence
    if (_userOverride != null) {
      return _userOverride!;
    }

    // Auto mode - use measured bandwidth
    final avg = averageBandwidth;
    if (avg >= _highQualityThreshold) {
      return VideoQuality.high;
    } else if (avg >= _lowQualityThreshold) {
      return VideoQuality.medium;
    }
    return VideoQuality.low;
  }

  /// Check if we should use high or medium quality (not low/480p)
  bool get shouldUseHighQuality =>
      recommendedQuality == VideoQuality.high ||
      recommendedQuality == VideoQuality.medium;

  /// Set user quality override
  ///
  /// [quality] - Forced quality, or null for auto mode
  Future<void> setQualityOverride(VideoQuality? quality) async {
    _userOverride = quality;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (quality == null) {
        await prefs.remove(_qualityPrefKey);
        _log('Set quality preference: auto');
      } else {
        await prefs.setString(_qualityPrefKey, quality.name);
        _log('Set quality preference: ${quality.name}');
      }
    } catch (e) {
      _log('Failed to save quality preference: $e');
    }
  }

  /// Get current user override (null = auto mode)
  VideoQuality? get qualityOverride => _userOverride;

  /// Clear all samples (useful for testing or reset)
  void clearSamples() {
    _bandwidthSamples.clear();
    _log('Cleared bandwidth samples');
  }

  void _log(String message) {
    Log.debug(
      '[BandwidthTracker] $message',
      name: 'BandwidthTrackerService',
      category: LogCategory.video,
    );
  }
}

/// Singleton instance for easy access
final BandwidthTrackerService bandwidthTracker =
    BandwidthTrackerService.instance;
