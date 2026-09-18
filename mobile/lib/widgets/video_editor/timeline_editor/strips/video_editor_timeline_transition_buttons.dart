// ABOUTME: The transition affordances drawn over the timeline clip strip —
// ABOUTME: a button per clip boundary, the loop-restart button and its seam.

import 'dart:io';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart';

/// Positions a [_TransitionButton] over every internal clip boundary, centred
/// on the gap between adjacent clips (TikTok-style).
class TimelineTransitionButtonsLayer extends StatelessWidget {
  const TimelineTransitionButtonsLayer({
    required this.clips,
    required this.layout,
    super.key,
  });

  final List<DivineVideoClip> clips;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;

  /// Visible glyph circle.
  static const double _visualSize = 26;

  /// Tap target around the glyph. The 1px clip gap leaves no horizontal room,
  /// so the target overlaps the neighbours and is enlarged toward the
  /// accessibility floor where the strip has room (vertically) without
  /// swallowing too much of the adjacent clips (horizontally).
  static const double hitWidth = 36;
  static const double hitHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < clips.length - 1; i++)
          Positioned(
            left:
                layout.offsets[i] +
                layout.widths[i] +
                TimelineConstants.clipGap / 2 -
                hitWidth / 2,
            top: (TimelineConstants.thumbnailStripHeight - hitHeight) / 2,
            width: hitWidth,
            height: hitHeight,
            child: _TransitionButton(
              visualSize: _visualSize,
              hasTransition: clips[i].transition != null,
              onTap: () => editClipTransition(context, i),
            ),
          ),
      ],
    );
  }
}

/// The loop-blend seam region drawn after the last clip: the span where the
/// last clip's tail dissolves into the first clip's head on restart. Its width
/// is the seam's real playback length ([LoopWrapDisplay.seamDuration]), so the
/// playhead traverses it exactly while the blend plays in the preview.
///
/// Rendered as the actual blend: the last clip's tail frame cross-fading into
/// the first clip's head frame along the region — the same frames the
/// transition picker previews. Falls back to a tinted box when neither frame
/// resolves.
///
/// Builds a [Positioned], so it must be a direct child of a [Stack].
class TimelineLoopSeamRegion extends StatelessWidget {
  const TimelineLoopSeamRegion({
    required this.left,
    required this.width,
    required this.tailFramePath,
    required this.headFramePath,
    super.key,
  });

  final double left;
  final double width;

  /// Last clip's tail frame (ghost frame / thumbnail), fading out.
  final String? tailFramePath;

  /// First clip's head frame (thumbnail), fading in toward the loop point.
  final String? headFramePath;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: VineTheme.primary.withValues(alpha: 0.18),
    );
    // Copied to locals so the null checks below promote; a public final field
    // does not.
    final tailPath = tailFramePath;
    final headPath = headFramePath;
    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: TimelineConstants.thumbnailStripHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(TimelineConstants.thumbnailRadius),
        ),
        child: ExcludeSemantics(
          child: Stack(
            fit: .expand,
            children: [
              if (tailPath == null) fallback else _SeamFrame(path: tailPath),
              if (headPath != null)
                ShaderMask(
                  // Only the gradient's alpha matters (dstIn masks the head
                  // frame in from transparent to opaque across the region).
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [VineTheme.transparent, VineTheme.whiteText],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: _SeamFrame(path: headPath),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One end of the loop seam: a captured still filling the seam region, blank
/// if the file has gone missing.
class _SeamFrame extends StatelessWidget {
  const _SeamFrame({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: .cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// Positions the loop-restart button centred on the strip's end edge — the
/// "end" side of the wrap seam where the last clip's tail flows into the first
/// clip's head so a looping player restarts seamlessly. Straddles the edge like
/// the between-clip buttons straddle their seams; the strip reserves a
/// half-button trailing slot so the right half isn't clipped. Shown even for a
/// single clip, which wraps into itself.
///
/// Builds a [Positioned], so it must be a direct child of a [Stack].
class TimelineLoopTransitionButton extends StatelessWidget {
  const TimelineLoopTransitionButton({
    required this.hasTransition,
    required this.layout,
    super.key,
  });

  final bool hasTransition;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;

  @override
  Widget build(BuildContext context) {
    final foreground = hasTransition
        ? context.vineColors.accentPositive
        : context.vineColors.secondaryText;
    final left = math.max(
      0.0,
      layout.totalWidth - TimelineTransitionButtonsLayer.hitWidth / 2,
    );
    return Positioned(
      left: left,
      top:
          (TimelineConstants.thumbnailStripHeight -
              TimelineTransitionButtonsLayer.hitHeight) /
          2,
      width: TimelineTransitionButtonsLayer.hitWidth,
      height: TimelineTransitionButtonsLayer.hitHeight,
      child: Semantics(
        button: true,
        label: context.l10n.videoEditorLoopTransitionButtonSemanticLabel,
        child: GestureDetector(
          onTap: () => editLoopTransition(context),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: SizedBox.square(
              dimension: TimelineTransitionButtonsLayer._visualSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: foreground, width: 1.5),
                ),
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.repeat,
                    size: 14,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitionButton extends StatelessWidget {
  const _TransitionButton({
    required this.hasTransition,
    required this.onTap,
    required this.visualSize,
  });

  final bool hasTransition;
  final VoidCallback onTap;

  /// Diameter of the visible glyph circle, centred inside the larger tap target.
  final double visualSize;

  @override
  Widget build(BuildContext context) {
    final foreground = hasTransition
        ? context.vineColors.accentPositive
        : context.vineColors.secondaryText;
    return Semantics(
      button: true,
      label: context.l10n.videoEditorTransitionButtonSemanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: SizedBox.square(
            dimension: visualSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: foreground, width: 1.5),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(10, 10),
                  painter: _TransitionGlyphPainter(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the universal "transition" bowtie glyph — two triangles meeting at
/// the centre.
class _TransitionGlyphPainter extends CustomPainter {
  const _TransitionGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, h / 2)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(w, 0)
      ..lineTo(w / 2, h / 2)
      ..lineTo(w, h)
      ..close();
    canvas
      ..drawPath(left, paint)
      ..drawPath(right, paint);
  }

  @override
  bool shouldRepaint(_TransitionGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
