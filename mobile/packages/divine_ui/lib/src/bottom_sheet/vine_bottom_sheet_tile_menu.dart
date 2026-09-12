// ABOUTME: Tile menu bottom sheet with icon-labeled action items
// ABOUTME: Supports destructive actions and disabled states

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:material_ui/material_ui.dart';

/// Data class representing an action tile in the bottom sheet menu.
class VineBottomSheetTileData {
  /// Creates a [VineBottomSheetTileData].
  const VineBottomSheetTileData({
    required this.iconPath,
    required this.label,
    required this.isDestructive,
    required this.onTap,
  });

  /// The path to the SVG icon asset to display.
  final String iconPath;

  /// The display text for this tile.
  final String label;

  /// Whether this action is destructive (e.g., delete, remove).
  ///
  /// Destructive actions are displayed in red.
  final bool isDestructive;

  /// Callback when the tile is tapped.
  ///
  /// If null, the tile is displayed as disabled.
  final VoidCallback? onTap;
}

/// A bottom sheet menu displaying action tiles with icons.
///
/// Each tile displays an SVG icon and label. Supports destructive actions
/// (shown in red) and disabled states (when [VineBottomSheetTileData.onTap]
/// is null).
///
/// Example:
/// ```dart
/// await VineBottomSheetTileMenu.show(
///   context: context,
///   options: [
///     VineBottomSheetTileData(
///       iconPath: 'assets/icons/edit.svg',
///       label: 'Edit',
///       isDestructive: false,
///       onTap: () => handleEdit(),
///     ),
///     VineBottomSheetTileData(
///       iconPath: 'assets/icons/delete.svg',
///       label: 'Delete',
///       isDestructive: true,
///       onTap: () => handleDelete(),
///     ),
///   ],
/// );
/// ```
class VineBottomSheetTileMenu {
  /// Shows the tile menu as a modal bottom sheet.
  ///
  /// Returns the selected option's value when tapped, or null if dismissed.
  static Future<String?> show({
    required BuildContext context,
    required List<VineBottomSheetTileData> options,
    Widget? title,
    String? selectedValue,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      title: title,
      expanded: false,
      isScrollControlled: true,
      body: Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            children: [
              for (final option in options)
                _VineBottomSheetListTile(data: option),
            ],
          ),
        ),
      ),
    );
  }
}

class _VineBottomSheetListTile extends StatelessWidget {
  const _VineBottomSheetListTile({required this.data});

  final VineBottomSheetTileData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final effectiveColor = data.onTap != null
        ? data.isDestructive
              ? colors.primaryText
              : VineTheme.error
        : colors.disabled;

    return ListTile(
      iconColor: effectiveColor,
      textColor: effectiveColor,
      enabled: data.onTap != null,
      minTileHeight: 56,
      leading: SizedBox(
        height: 24,
        width: 24,
        child: SvgPicture.asset(
          data.iconPath,
          colorFilter: .mode(effectiveColor, .srcIn),
        ),
      ),
      title: Text(
        data.label,
        style: VineTheme.titleMediumFont(color: colors.primaryText),
        maxLines: 1,
        overflow: .ellipsis,
      ),
      onTap: data.onTap,
    );
  }
}
