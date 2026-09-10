// ABOUTME: Global error widget shown when a widget throws during build
// ABOUTME: The Divine "tangled vine" - our version of Twitter's fail whale

import 'package:divine_ui/divine_ui.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the global error widget, with a fallback for pre-MaterialApp errors.
///
/// When a widget throws during build, Flutter replaces it with this.
/// Inside the MaterialApp tree we get the full "tangled vine" experience.
/// Before MaterialApp is ready (early startup), we fall back to a minimal
/// branded container that doesn't require Directionality or Theme.
Widget buildGlobalErrorWidget(FlutterErrorDetails details) {
  _reportToCrashlytics(details);

  // Try the nice widget first; fall back if the tree isn't ready yet.
  try {
    return _GlobalErrorWidget(details: details);
  } catch (_) {
    // Pre-MaterialApp: no Directionality, no Theme, no Text allowed.
    return _MinimalFallbackError();
  }
}

/// Tracks which errors we've already reported to avoid spamming Crashlytics
/// on widget rebuilds.
final Set<int> _reportedErrors = {};

void _reportToCrashlytics(FlutterErrorDetails details) {
  final errorHash = Object.hash(
    details.exception.toString(),
    details.stack.toString(),
  );

  if (_reportedErrors.contains(errorHash)) return;
  _reportedErrors.add(errorHash);

  // Keep the set from growing unbounded during long sessions.
  if (_reportedErrors.length > 200) {
    final toRemove = _reportedErrors.take(100).toList();
    _reportedErrors.removeAll(toRemove);
  }

  try {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  } catch (_) {
    // Crashlytics not initialized yet - that's fine.
  }
}

// ---------------------------------------------------------------------------
// Minimal fallback (pre-MaterialApp)
// ---------------------------------------------------------------------------

class _MinimalFallbackError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.background,
      child: const Center(
        child: SizedBox(
          width: 80,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // vineGreen at 40% opacity - gentle, branded, not alarming
              color: Color(0x6627C58B),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full error widget (inside MaterialApp tree)
// ---------------------------------------------------------------------------

class _GlobalErrorWidget extends StatelessWidget {
  const _GlobalErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: context.vineColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The tangled vine illustration
                const SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(painter: _TangledVinePainter()),
                ),
                const SizedBox(height: 28),

                // Headline
                Text(
                  'got a bit tangled',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Friendly explanation
                Text(
                  "something tripped up here.\nit's not you, it's us.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.vineColors.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Gentle nudge
                Text(
                  'try navigating away and coming back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.vineColors.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),

                // Debug info for developers
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.vineColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.vineColors.disabled),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'debug info',
                          style: TextStyle(
                            color: context.vineColors.accentPositive,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          details.exceptionAsString(),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VineTheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'monospace',
                            decoration: TextDecoration.none,
                            height: 1.4,
                          ),
                        ),
                        if (details.context != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            details.context!.toDescription(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.vineColors.onSurfaceMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'monospace',
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                        if (details.library != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'library: ${details.library}',
                            style: TextStyle(
                              color: context.vineColors.onSurfaceMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'monospace',
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The tangled vine illustration - Divine's "fail whale"
// ---------------------------------------------------------------------------

/// Paints a cute tangled vine with drooping leaves.
///
/// The vine starts from the bottom, spirals up and gets knotted in the middle,
/// with a few sad leaves hanging off. Drawn entirely in vineGreen tones.
class _TangledVinePainter extends CustomPainter {
  const _TangledVinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Main vine stem paint
    final stemPaint = Paint()
      ..color = VineTheme.vineGreen
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Lighter vine for the tangle loops
    final tanglePaint = Paint()
      ..color = VineTheme.vineGreenLight
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Leaf paint
    final leafPaint = Paint()
      ..color = VineTheme.vineGreen
      ..style = PaintingStyle.fill;

    // Faded leaf paint for droopy leaves
    final fadedLeafPaint = Paint()
      ..color =
          const Color(0x9927C58B) // 60% vineGreen
      ..style = PaintingStyle.fill;

    // --- Vine stem from bottom, curving up ---
    final stem = Path()
      ..moveTo(cx, size.height) // bottom center
      ..cubicTo(
        cx - 10,
        size.height * 0.8,
        cx + 15,
        size.height * 0.65,
        cx - 5,
        size.height * 0.52,
      );
    canvas.drawPath(stem, stemPaint);

    // --- The tangle / knot in the middle ---
    // Loop 1 (going right)
    final loop1 = Path()
      ..moveTo(cx - 5, size.height * 0.52)
      ..cubicTo(
        cx + 35,
        size.height * 0.42,
        cx + 40,
        size.height * 0.55,
        cx + 10,
        size.height * 0.48,
      );
    canvas.drawPath(loop1, tanglePaint);

    // Loop 2 (going left, crossing over)
    final loop2 = Path()
      ..moveTo(cx + 10, size.height * 0.48)
      ..cubicTo(
        cx - 35,
        size.height * 0.38,
        cx - 30,
        size.height * 0.55,
        cx - 8,
        size.height * 0.44,
      );
    canvas.drawPath(loop2, tanglePaint);

    // Loop 3 (small inner twist)
    final loop3 = Path()
      ..moveTo(cx - 8, size.height * 0.44)
      ..cubicTo(
        cx + 20,
        size.height * 0.35,
        cx + 15,
        size.height * 0.5,
        cx,
        size.height * 0.38,
      );
    canvas.drawPath(loop3, stemPaint);

    // --- Stem continues up from the knot, but droopy ---
    final topStem = Path()
      ..moveTo(cx, size.height * 0.38)
      ..cubicTo(
        cx - 12,
        size.height * 0.28,
        cx + 8,
        size.height * 0.2,
        cx - 3,
        size.height * 0.12,
      );
    canvas.drawPath(topStem, stemPaint);

    // --- Drooping tip at the top (the vine gave up) ---
    final droopTip = Path()
      ..moveTo(cx - 3, size.height * 0.12)
      ..quadraticBezierTo(
        cx + 15,
        size.height * 0.06,
        cx + 20,
        size.height * 0.14,
      );
    canvas.drawPath(droopTip, stemPaint);

    // --- Leaves ---

    // Healthy leaf on the lower stem (still doing ok)
    _drawLeaf(
      canvas,
      Offset(cx + 15, size.height * 0.65),
      leafPaint,
      angle: -0.3,
      scale: 1.0,
    );

    // Droopy leaf hanging off the tangle (sad)
    _drawLeaf(
      canvas,
      Offset(cx + 35, size.height * 0.48),
      fadedLeafPaint,
      angle: 1.8, // pointing down - drooping
      scale: 0.8,
    );

    // Another droopy leaf on the left
    _drawLeaf(
      canvas,
      Offset(cx - 30, size.height * 0.42),
      fadedLeafPaint,
      angle: 2.5, // pointing down-left
      scale: 0.7,
    );

    // Small leaf near the top
    _drawLeaf(
      canvas,
      Offset(cx + 8, size.height * 0.2),
      fadedLeafPaint,
      angle: -0.8,
      scale: 0.6,
    );

    // Tiny droopy leaf at the tip
    _drawLeaf(
      canvas,
      Offset(cx + 20, size.height * 0.14),
      fadedLeafPaint,
      angle: 2.0,
      scale: 0.5,
    );

    // --- Small dots / tendrils ---
    final dotPaint = Paint()
      ..color =
          const Color(0x6627C58B) // 40% vineGreen
      ..style = PaintingStyle.fill;

    // Little curly tendril from the knot
    canvas.drawCircle(Offset(cx + 28, size.height * 0.4), 2.5, dotPaint);
    canvas.drawCircle(Offset(cx + 33, size.height * 0.37), 1.8, dotPaint);
    canvas.drawCircle(Offset(cx - 25, size.height * 0.5), 2.0, dotPaint);
  }

  /// Draws a simple leaf shape at [center] rotated by [angle] radians.
  void _drawLeaf(
    Canvas canvas,
    Offset center,
    Paint paint, {
    required double angle,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(8, -12, 18, -10, 20, 0)
      ..cubicTo(18, 10, 8, 12, 0, 0);
    canvas.drawPath(leaf, paint);

    // Leaf vein
    final veinPaint = Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, const Offset(18, 0), veinPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
