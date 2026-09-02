// ABOUTME: Shared pieces of the discovery list cards: the scrim count badge
// ABOUTME: and the title/description footer block under the media collage.

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';

/// Scrim badge overlaid on a list card's media: an icon plus a compact count.
///
/// Fixed media chrome by design: the scrim and white ink sit on user imagery
/// in both appearances, and the badge must not scale with system text size
/// or it overflows its fixed corner.
class ListCardBadge extends StatelessWidget {
  const ListCardBadge({required this.icon, required this.count, super.key});

  final DivineIconName icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.backgroundColor.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              DivineIcon(icon: icon, color: VineTheme.primaryText, size: 16),
              Text(
                CountFormatter.formatCompact(count),
                style: VineTheme.labelMediumFont(color: VineTheme.whiteText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title and description block under a list card's media.
///
/// Both card types share this structure so equal-width cards come out
/// equal-height and the two-column gallery reads as rows.
class ListCardFooter extends StatelessWidget {
  const ListCardFooter({required this.title, this.description, super.key});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListCardTitle(title: title),
        ListCardDescription(description: description),
      ],
    );
  }
}

/// Single-line list title under a card's media.
class ListCardTitle extends StatelessWidget {
  const ListCardTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: VineTheme.titleSmallFont(color: context.vineColors.primaryText),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// List description under a card's title, in a fixed two-line box.
///
/// The box keeps its two-line height whether the text overflows (trimmed
/// with an ellipsis), fits on one line, or is absent — that reserved space
/// is what keeps gallery rows level.
class ListCardDescription extends StatelessWidget {
  const ListCardDescription({required this.description, super.key});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodySmallFont(
      color: context.vineColors.secondaryText,
    );
    final lineHeight =
        style.height! * MediaQuery.textScalerOf(context).scale(style.fontSize!);
    return SizedBox(
      height: lineHeight * 2,
      width: double.infinity,
      child: switch (description) {
        final text? when text.isNotEmpty => LinkifiedText(
          text: text,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        _ => null,
      },
    );
  }
}
