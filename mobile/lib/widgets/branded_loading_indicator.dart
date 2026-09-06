// ABOUTME: Branded loading indicator using sprite sheet animation
// ABOUTME: Efficient GPU-based rendering with single texture, cached frames

import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:unified_logger/unified_logger.dart';

/// A branded loading indicator that displays the animated Divine logo.
///
/// Uses a sprite sheet for efficient GPU rendering. The sprite sheet contains
/// [frameCount] square frames arranged vertically. Animation cycles through
/// frames using an AnimationController for smooth, consistent playback.
///
/// Benefits over GIF:
/// - Single texture load (GPU efficient)
/// - No per-frame decoding
/// - Consistent animation across widget rebuilds
/// - Better performance on repeated displays
class BrandedLoadingIndicator extends StatefulWidget {
  const BrandedLoadingIndicator({
    super.key,
    this.size = 80.0,
    this.semanticsLabel,
  });

  /// Sprite sheet backing the animation: the Divine brand mark
  /// (`assets/icon/divine_mark.svg`) in white, drawn as a wing-flap cycle.
  @visibleForTesting
  static const String spriteAsset = 'assets/loading-brand-sprite.png';

  /// Number of square frames stacked vertically in [spriteAsset].
  ///
  /// Slicing depends on this matching the sheet exactly, so
  /// `branded_loading_indicator_test.dart` pins it against the asset.
  @visibleForTesting
  static const int frameCount = 27;

  /// The size (width and height) of the loading indicator.
  final double size;

  /// What a screen reader announces while the indicator is on screen.
  ///
  /// Defaults to the localized "Loading". Pass a more specific label when the
  /// indicator stands in for a named control; wrap the indicator in
  /// [ExcludeSemantics] instead when a sibling already announces the wait.
  final String? semanticsLabel;

  @override
  State<BrandedLoadingIndicator> createState() =>
      _BrandedLoadingIndicatorState();
}

class _BrandedLoadingIndicatorState extends State<BrandedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Duration _animationDuration = Duration(milliseconds: 1800);

  /// Frame shown when motion is reduced. 0 is the mark's rest pose — the frame
  /// `branded_loading_indicator_test.dart` pins the brand silhouette against —
  /// so the static form is the logo at rest rather than mid-wing-flap.
  static const int _restFrame = 0;

  @override
  void initState() {
    super.initState();
    // Deliberately not started here. Whether this animates depends on
    // MediaQuery, which is not available until didChangeDependencies.
    _controller = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToMotionPreference();
  }

  /// Starts or stops the loop to match the platform's reduced-motion setting.
  ///
  /// Beyond the accessibility rule in `.claude/rules/accessibility.md`, this is
  /// load-bearing for UI tests. `repeat()` never settles, and XCUITest blocks
  /// every query until the app under test reaches quiescence — so while this
  /// indicator is on screen each query waits out XCUITest's internal timeout,
  /// measured at a fixed 3m31s on Explore, where this widget is the `loading:`
  /// state (#7204). Honouring reduced motion lets the app go idle, which is
  /// what the E2E suite needs and what a reduced-motion user should get anyway.
  void _syncToMotionPreference() {
    if (context.reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value =
          _restFrame / BrandedLoadingIndicator.frameCount.toDouble();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Blur radius of the light-mode shadow, as a fraction of `size`, so a 16px
  /// inline spinner and an 80px full-screen one carry the same weight.
  static const double _shadowBlurRatio = 0.055;

  /// Downward shadow offset, as a fraction of `size`.
  static const double _shadowOffsetRatio = 0.025;

  /// Opacity of the shadow against the light surface.
  static const double _shadowOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    // The mark is white, which all but disappears on the light palette's
    // off-white surfaces. A shadow gives it an edge while it stays white.
    final shadowSprite = Theme.of(context).brightness == Brightness.light
        ? Image.asset(
            BrandedLoadingIndicator.spriteAsset,
            width: widget.size,
            height: widget.size * BrandedLoadingIndicator.frameCount,
            fit: BoxFit.fitWidth,
            color: context.vineColors.onSurface.withValues(
              alpha: _shadowOpacity,
            ),
            colorBlendMode: BlendMode.srcIn,
            // The mark layer already surfaces a failed sheet.
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          )
        : null;

    // The sprite is an unlabelled [Image], which reaches a screen reader as a
    // bare "image" node. Excluding it and labelling the wrapper is what turns
    // the indicator into an announcement that something is still running.
    return Semantics(
      label: widget.semanticsLabel ?? context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Calculate current frame based on animation value
            final frameIndex =
                (_controller.value * BrandedLoadingIndicator.frameCount)
                    .floor();
            final clampedFrame = frameIndex.clamp(
              0,
              BrandedLoadingIndicator.frameCount - 1,
            );

            final mark = _SpriteFrame(
              size: widget.size,
              frameIndex: clampedFrame,
              child: child!,
            );

            if (shadowSprite == null) return mark;

            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, widget.size * _shadowOffsetRatio),
                  // Blurring the sliced frame rather than the full sheet keeps
                  // the filter layer at the indicator's size.
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: widget.size * _shadowBlurRatio,
                      sigmaY: widget.size * _shadowBlurRatio,
                    ),
                    child: _SpriteFrame(
                      size: widget.size,
                      frameIndex: clampedFrame,
                      child: shadowSprite,
                    ),
                  ),
                ),
                mark,
              ],
            );
          },
          child: Image.asset(
            BrandedLoadingIndicator.spriteAsset,
            width: widget.size,
            height: widget.size * BrandedLoadingIndicator.frameCount,
            fit: BoxFit.fitWidth,
            errorBuilder: (context, error, stackTrace) {
              Log.warning(
                'Failed to load sprite sheet: $error',
                name: 'BrandedLoadingIndicator',
                category: LogCategory.ui,
              );
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: Center(
                  child: DivineCircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.vineColors.onSurfaceMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Windows the vertically stacked sheet down to a single square frame.
class _SpriteFrame extends StatelessWidget {
  const _SpriteFrame({
    required this.size,
    required this.frameIndex,
    required this.child,
  });

  final double size;
  final int frameIndex;

  /// The full sheet, sized `size` × `size * frameCount`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: size,
          maxHeight: size * BrandedLoadingIndicator.frameCount,
          alignment: Alignment.topCenter,
          // Scrolls the sheet up until the wanted frame fills the box.
          child: Transform.translate(
            offset: Offset(0, -frameIndex * size),
            child: child,
          ),
        ),
      ),
    );
  }
}
