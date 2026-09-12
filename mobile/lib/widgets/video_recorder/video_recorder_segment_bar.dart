// ABOUTME: Widget that displays recording progress as a segmented bar
// ABOUTME: Shows filled segments for recorded clips with remaining space for more recording

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

/// Displays a horizontal bar showing recording segments.
///
/// Each segment represents a recorded clip, with dividers between them.
/// Remaining space is shown as transparent, indicating available recording
/// time.
class VideoRecorderSegmentBar extends StatelessWidget {
  /// Creates a segment bar widget.
  const VideoRecorderSegmentBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .topCenter,
      child: SafeArea(
        child: SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (_, constraints) => _Segments(constraints: constraints),
          ),
        ),
      ),
    );
  }
}

class _Segments extends ConsumerWidget {
  const _Segments({required this.constraints});

  /// Maximum allowed recording duration.
  static const Duration _maxDuration = VideoEditorConstants.maxDuration;

  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      clipManagerProvider.select(
        (s) => (clips: s.clips, activeRecording: s.activeRecordingDuration),
      ),
    );

    final recordSegments = state.clips;
    final activeRecordingDuration = state.activeRecording;

    var used = Duration.zero;
    final segments = <Widget>[];

    // Build segments with Flexible based on duration
    for (var i = 0; i < recordSegments.length; i++) {
      if (used >= _maxDuration) break;

      final segment = recordSegments[i];
      final remaining = _maxDuration - used;
      final segmentDuration = segment.duration > remaining
          ? remaining
          : segment.duration;

      used += segmentDuration;

      // Add segment as Flexible with flex based on milliseconds
      segments.add(
        Flexible(
          flex: segmentDuration.inMilliseconds,
          child: Container(height: 16, color: VineTheme.tabIndicatorGreen),
        ),
      );

      // Add divider between segments
      if (i < recordSegments.length - 1 || activeRecordingDuration > .zero) {
        if (used < _maxDuration) {
          segments.add(
            Container(
              height: 16,
              width: 2,
              color: context.vineColors.surfaceContainerHigh,
            ),
          );
        }
      }
    }

    // Add active recording segment
    if (activeRecordingDuration > .zero && used < _maxDuration) {
      final remaining = _maxDuration - used;
      final activeDuration = activeRecordingDuration > remaining
          ? remaining
          : activeRecordingDuration;

      segments.add(
        Flexible(
          flex: activeDuration.inMilliseconds,
          child: Stack(
            alignment: .centerRight,
            children: [
              Container(height: 16, color: VineTheme.tabIndicatorGreen),
              Container(
                width: 4,
                height: 48,
                decoration: ShapeDecoration(
                  color: VineTheme.accentYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      used += activeDuration;
    }

    // Add remaining empty space as Flexible
    if (used < _maxDuration) {
      final remaining = _maxDuration - used;
      segments.add(
        Flexible(
          flex: remaining.inMilliseconds,
          child: Container(height: 16, color: const Color(0xFF7F8482)),
        ),
      );
    }

    return RepaintBoundary(child: Row(children: segments));
  }
}
