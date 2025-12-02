// ABOUTME: Visual overlay to display video loading metrics directly in the app UI
// ABOUTME: Shows real-time performance data when videos load, bypassing console logging issues

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/video_loading_metrics.dart';

/// Visual overlay showing video loading metrics in development builds
/// Fixed to avoid Stack Overflow errors by using StreamBuilder instead of setState
class VideoMetricsOverlay extends StatefulWidget {
  final Widget child;

  const VideoMetricsOverlay({required this.child, super.key});

  @override
  State<VideoMetricsOverlay> createState() => _VideoMetricsOverlayState();
}

class _VideoMetricsOverlayState extends State<VideoMetricsOverlay> {
  final StreamController<List<String>> _metricsController =
      StreamController<List<String>>.broadcast();
  final List<String> _recentMetrics = [];
  static const int maxMetrics = 5;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      // Hook into metrics system with debouncing to prevent rapid rebuilds
      _setupMetricsListener();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _metricsController.close();
    VideoLoadingMetrics.instance.onMetricsEvent = null;
    super.dispose();
  }

  void _setupMetricsListener() {
    // Use debouncing to prevent rapid setState calls that could cause Stack Overflow
    VideoLoadingMetrics.instance.onMetricsEvent = (String event) {
      if (!mounted) return;

      // Cancel any existing timer
      _debounceTimer?.cancel();

      // Add metric to list
      _recentMetrics.insert(0, event);
      if (_recentMetrics.length > maxMetrics) {
        _recentMetrics.removeLast();
      }

      // Debounce updates by 100ms to prevent rapid rebuilds
      _debounceTimer = Timer(const Duration(milliseconds: 100), () {
        if (!_metricsController.isClosed && mounted) {
          _metricsController.add(List<String>.from(_recentMetrics));
        }
      });
    };
  }

  void _clearMetrics() {
    _recentMetrics.clear();
    if (!_metricsController.isClosed) {
      _metricsController.add([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kDebugMode)
          StreamBuilder<List<String>>(
            stream: _metricsController.stream,
            initialData: const [],
            builder: (context, snapshot) {
              final metrics = snapshot.data ?? [];
              if (metrics.isEmpty) return const SizedBox.shrink();

              return Positioned(
                top: 50,
                left: 10,
                right: 10,
                child: IgnorePointer(
                  ignoring: false,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.analytics,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Video Metrics Debug',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _clearMetrics,
                                child: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...metrics.map(
                            (metric) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                metric,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Static debug info widget
class VideoMetricsDebugInfo extends StatelessWidget {
  const VideoMetricsDebugInfo({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '📊 Metrics Status',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Active Sessions: ${VideoLoadingMetrics.instance.activeSessions}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              'Total Started: ${VideoLoadingMetrics.metricsCount}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
