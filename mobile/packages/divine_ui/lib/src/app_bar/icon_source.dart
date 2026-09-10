import 'package:equatable/equatable.dart';
import 'package:material_ui/material_ui.dart';

/// Type-safe icon source for DiVineAppBar components.
///
/// Supports both SVG assets and Material icons with exhaustive
/// pattern matching.
///
/// Example usage:
/// ```dart
/// // SVG icon
/// const icon = SvgIconSource('assets/icon/CaretLeft.svg');
///
/// // Material icon
/// const icon = MaterialIconSource(Icons.arrow_back);
/// ```
sealed class IconSource extends Equatable {
  const IconSource();
}

/// SVG asset icon source.
///
/// Use this for custom SVG icons from the assets folder.
final class SvgIconSource extends IconSource {
  /// Creates an SVG icon source with the given asset path.
  const SvgIconSource(this.assetPath);

  /// The path to the SVG asset (e.g., 'assets/icon/CaretLeft.svg').
  final String assetPath;

  @override
  List<Object?> get props => [assetPath];
}

/// Material icon source.
///
/// Use this for standard Material Design icons.
@Deprecated(
  'Prefer SvgIconSource with a DivineIconName from the Divine design '
  'system icon set. MaterialIconSource remains supported for existing '
  'call sites that still need a raw Material icon.',
)
final class MaterialIconSource extends IconSource {
  /// Creates a Material icon source with the given icon data.
  @Deprecated(
    'Prefer SvgIconSource with a DivineIconName from the Divine design '
    'system icon set. MaterialIconSource remains supported for existing '
    'call sites that still need a raw Material icon.',
  )
  const MaterialIconSource(this.iconData);

  /// The Material icon data (e.g., Icons.arrow_back).
  final IconData iconData;

  @override
  List<Object?> get props => [iconData];
}
