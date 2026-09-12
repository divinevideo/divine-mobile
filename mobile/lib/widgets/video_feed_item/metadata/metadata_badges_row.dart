// ABOUTME: Non-interactive badge labels row for the metadata expanded sheet.
// ABOUTME: Shows Human-Made (with tier) and Not Divine badges separated by
// ABOUTME: muted dot separators. Rendered inline inside the header section
// ABOUTME: between the title and the description, so this widget contributes
// ABOUTME: only the wrap of labels — the surrounding container owns padding.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/proofmode_helpers.dart';

/// Row of non-interactive badge labels rendered between the title and
/// description in the metadata expanded sheet.
///
/// Confirmed badges: "Human-Made" (with tier superscript) and "Not Divine".
/// Future: "No AI", "Don't try this at home" (content warnings).
///
/// Returns [SizedBox.shrink] when no badges apply.
///
/// Matches Figma node `15728:87954`.
class MetadataBadgesRow extends StatelessWidget {
  const MetadataBadgesRow({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (video.shouldShowProofModeBadge) {
      badges.add(const _HumanMadeBadge());
    }

    if (video.shouldShowNotDivineBadge) {
      badges.add(_TextBadge(label: context.l10n.metadataBadgeNotDivine));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < badges.length; i++) {
      children.add(badges[i]);
      if (i < badges.length - 1) {
        children.add(const _DotSeparator());
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// "Human-Made" badge with "HM" superscript.
///
/// The "HM" superscript is a typographic flourish of the brand mark and
/// intentionally stays untranslated; only the long-form label flows
/// through localization.
class _HumanMadeBadge extends StatelessWidget {
  const _HumanMadeBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.humanMadeBadge,
      label: context.l10n.metadataBadgeHumanMade,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const DivineIcon(icon: DivineIconName.divineMark),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: context.l10n.metadataBadgeHumanMade,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Text(
                    'HM',
                    style:
                        VineTheme.titleSmallFont(
                          color: context.vineColors.primaryText,
                        ).copyWith(
                          fontSize:
                              VineTheme.titleSmallFont(
                                color: context.vineColors.primaryText,
                              ).fontSize! /
                              1.555,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain text badge (e.g., "Not Divine").
class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: VineTheme.titleSmallFont(color: context.vineColors.primaryText),
    );
  }
}

/// Muted dot separator between badges.
class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '\u2219',
      style: VineTheme.titleSmallFont(color: context.vineColors.outlineMuted),
    );
  }
}
