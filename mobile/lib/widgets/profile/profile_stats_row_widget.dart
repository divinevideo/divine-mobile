// ABOUTME: Stats column widget for profile page showing stat count + label
// ABOUTME: Displays animated stat values with loading states

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Individual stat column widget for followers/following/likes/loops counts.
///
/// Numbers use [VineTheme.statNumberFont] (Bricolage Grotesque 800 20/28/0).
/// Labels use bodySmall (Inter 12/16). Both are center-aligned.
class ProfileStatColumn extends StatelessWidget {
  const ProfileStatColumn({
    required this.count,
    required this.label,
    required this.isLoading,
    this.onTap,
    super.key,
  });

  final int? count;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final column = MediaQuery.withClampedTextScaling(
      maxScaleFactor: statColumnTextScaleLimit,
      child: Padding(
        padding: const .symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isLoading || count == null
                    ? '—'
                    : StringUtils.formatCompactNumber(count!),
                key: ValueKey(isLoading ? 'loading' : count),
                style: VineTheme.statNumberFont(
                  color: isLoading || count == null
                      ? context.vineColors.onSurfaceMuted
                      : context.vineColors.primaryText,
                ),
              ),
            ),
            Skeleton.keep(
              child: Text(
                label,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
                softWrap: false,
                maxLines: 1,
                overflow: .fade,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: column,
        ),
      );
    }

    return column;
  }
}
