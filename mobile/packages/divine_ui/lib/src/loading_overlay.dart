// ABOUTME: Overlay widget that shows a top-edge LinearProgressIndicator
// ABOUTME: while background content stays visible during a silent refresh.

import 'package:divine_ui/src/loading/divine_progress_indicator.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// Wraps [child] and shows a slim [LinearProgressIndicator] at the top edge
/// while [isLoading] is true.
///
/// Designed for "silent refresh" scenarios where the previous content remains
/// visible and a subtle indicator communicates the ongoing update:
///
/// ```dart
/// LoadingOverlay(
///   isLoading: state.isRefreshing,
///   child: MyListView(),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  /// Creates a [LoadingOverlay].
  const LoadingOverlay({
    required this.child,
    required this.isLoading,
    this.padding = .zero,
    super.key,
  });

  /// The primary content displayed behind the loading indicator.
  final Widget child;

  /// When true, a [LinearProgressIndicator] is shown at the top edge.
  final bool isLoading;

  /// Optional padding applied around the loading indicator.
  final EdgeInsets padding;

  static const _animationDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        Padding(
          padding: padding,
          child: AnimatedSize(
            duration: _animationDuration,
            child: Align(
              alignment: Alignment.topCenter,
              child: isLoading
                  ? const DivineLinearProgressIndicator(
                      color: VineTheme.primary,
                      backgroundColor: Colors.transparent,
                    )
                  : const SizedBox(width: .infinity),
            ),
          ),
        ),
      ],
    );
  }
}
