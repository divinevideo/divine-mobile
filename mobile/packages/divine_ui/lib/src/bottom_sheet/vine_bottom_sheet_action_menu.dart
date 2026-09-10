// ABOUTME: Action menu bottom sheet with icon-labeled action items
// ABOUTME: Supports destructive actions and disabled states

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:material_ui/material_ui.dart';

/// Data class representing an action item in the bottom sheet menu.
class VineBottomSheetActionData {
  /// Creates a [VineBottomSheetActionData].
  const VineBottomSheetActionData({
    required this.iconPath,
    required this.label,
    this.isDestructive = false,
    this.closeOnTap = true,
    this.onTap,
  });

  /// The path to the SVG icon asset to display.
  final String iconPath;

  /// The display text for this action.
  final String label;

  /// Whether this action is destructive (e.g., delete, remove).
  ///
  /// Destructive actions are displayed in red.
  final bool isDestructive;

  /// Whether to automatically close the bottom sheet when tapped.
  ///
  /// Defaults to `true`.
  final bool closeOnTap;

  /// Callback when the action is tapped.
  ///
  /// If null, the action is displayed as disabled.
  final VoidCallback? onTap;
}

/// A bottom sheet menu displaying action items with icons.
///
/// Each action displays an SVG icon and label. Supports destructive actions
/// (shown in red) and disabled states (when [VineBottomSheetActionData.onTap]
/// is null).
///
/// Example:
/// ```dart
/// await VineBottomSheetActionMenu.show(
///   context: context,
///   options: [
///     VineBottomSheetActionData(
///       iconPath: 'assets/icons/edit.svg',
///       label: 'Edit',
///       isDestructive: false,
///       onTap: () => handleEdit(),
///     ),
///     VineBottomSheetActionData(
///       iconPath: 'assets/icons/delete.svg',
///       label: 'Delete',
///       isDestructive: true,
///       onTap: () => handleDelete(),
///     ),
///   ],
/// );
/// ```
class VineBottomSheetActionMenu {
  /// Shows the action menu as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required List<VineBottomSheetActionData> options,
    Widget? title,
  }) {
    return VineBottomSheet.show(
      context: context,
      title: title,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: SingleChildScrollView(
        padding: const .only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              _VineBottomSheetListTile(data: option),
          ],
        ),
      ),
    );
  }
}

class _VineBottomSheetListTile extends StatelessWidget {
  const _VineBottomSheetListTile({required this.data});

  final VineBottomSheetActionData data;

  @override
  Widget build(BuildContext context) {
    final isEnabled = data.onTap != null;

    final colors = context.vineColors;
    final color = isEnabled
        ? data.isDestructive
              ? VineTheme.error
              : colors.primaryText
        : colors.disabled;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        enabled: isEnabled,
        minTileHeight: 56,
        leading: SizedBox.square(
          dimension: DivineIcon.scaleSize(context, 24),
          child: SvgPicture.asset(
            data.iconPath,
            colorFilter: .mode(color, .srcIn),
          ),
        ),
        title: Text(
          data.label,
          style: VineTheme.titleMediumFont(color: color),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        onTap: isEnabled
            ? () {
                if (data.closeOnTap) Navigator.pop(context);
                data.onTap!();
              }
            : null,
      ),
    );
  }
}
