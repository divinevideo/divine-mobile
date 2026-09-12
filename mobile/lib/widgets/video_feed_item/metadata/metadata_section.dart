// ABOUTME: Reusable section wrapper for the metadata expanded sheet.
// ABOUTME: Renders a labeled section with bottom divider matching Figma spec.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Explainer affordance for a [MetadataSection] header.
///
/// [label] describes the explainer that [onPressed] opens ("What do these
/// checks mean?"), not the icon.
typedef MetadataSectionInfo = ({VoidCallback onPressed, String label});

/// Vertical slack folded into the info header so its tap target clears the
/// 48 dp minimum.
///
/// The header row is 20 dp tall, so 14 dp above and below lands it exactly on
/// 48. [MetadataSection] subtracts the same amount from its own top padding
/// and from the label-to-content gap, which keeps both at the Figma-specified
/// 16 px however the row grows under text scaling.
const _infoHeaderTapSlack = 14.0;

/// A labeled section in the metadata expanded sheet.
///
/// Each section has:
/// - A bottom border in the semantic `outlineDisabled` color
/// - 16px padding on all sides
/// - A small label in the semantic `onSurfaceVariant` color
/// - 16px gap between label and content
///
/// Sections conditionally render: pass `null` to [child] or wrap the
/// entire widget in a conditional check to hide sections with no data.
///
/// Pass [info] to append an info icon to the header and make the whole header
/// row tappable — for sections whose content needs explaining.
class MetadataSection extends StatelessWidget {
  const MetadataSection({
    required this.label,
    required this.child,
    this.info,
    super.key,
  });

  /// Section header label (e.g. "Creator", "Tags", "Collaborators").
  final String label;

  /// Section content widget.
  final Widget child;

  /// Explainer opened from the header. When null, no info icon renders.
  final MetadataSectionInfo? info;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: VineTheme.labelSmallFont(
        color: context.vineColors.onSurfaceVariant,
      ),
    );

    // The info header carries its own vertical padding, so the section gives
    // back the same amount to keep the label where the plain header sits.
    final sectionInfo = info;
    final headerSlack = sectionInfo == null ? 0.0 : _infoHeaderTapSlack;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.vineColors.outlineDisabled),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16 - headerSlack, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16 - headerSlack,
          children: [
            if (sectionInfo == null)
              labelText
            else
              _SectionHeaderWithInfo(
                onPressed: sectionInfo.onPressed,
                sectionLabel: label,
                infoLabel: sectionInfo.label,
                child: labelText,
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Section header whose full width is the tap target for an explainer.
///
/// The tap target is the whole header row rather than the 20 dp icon alone,
/// so it stays comfortably hittable horizontally; [_infoHeaderTapSlack]
/// supplies the height that gets it to 48 dp without moving the label.
class _SectionHeaderWithInfo extends StatelessWidget {
  const _SectionHeaderWithInfo({
    required this.onPressed,
    required this.sectionLabel,
    required this.infoLabel,
    required this.child,
  });

  final VoidCallback onPressed;
  final String sectionLabel;
  final String infoLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Both children below are excluded, leaving nothing to anchor this
      // annotation to — without an explicit container it folds into the
      // enclosing section node and takes the whole section's label with it.
      container: true,
      button: true,
      // The visible section label is excluded below, so it is folded in here
      // — otherwise the section the checklist belongs to is never announced.
      label: context.l10n.metadataSectionInfoSemanticsLabel(
        sectionLabel,
        infoLabel,
      ),
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: infoLabel,
          // The message is already this node's semantic label; without this
          // the platform appends it a second time (iOS onto the label,
          // Android as tooltipText).
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _infoHeaderTapSlack),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ExcludeSemantics(child: child),
                ExcludeSemantics(
                  child: DivineIcon(
                    icon: DivineIconName.info,
                    size: 20,
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
