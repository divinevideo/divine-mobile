// ABOUTME: Full-width bottom indicator bar signalling the environment / relay
// ABOUTME: scope, with rounded top corners that curve up to meet the feed above.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/providers/environment_indicator_provider.dart';

/// A full-width bar pinned at the bottom edge of the app, colored by
/// [environmentIndicatorColorProvider]. Its top corners are rounded so the
/// color curves up to meet the rounded bottom of the feed above it.
/// Decorative (excluded from semantics).
class EnvironmentIndicatorLine extends ConsumerWidget {
  const EnvironmentIndicatorLine({super.key});

  static const double _height = 4;
  static const double _cornerRadius = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(environmentIndicatorColorProvider);
    if (color == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_cornerRadius),
          ),
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}
