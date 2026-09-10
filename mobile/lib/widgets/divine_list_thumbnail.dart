// ABOUTME: The list thumbnail card used everywhere a list is shown in a
// ABOUTME: gallery: Explore discovery, the profile My Lists tab, and search.
// ABOUTME: Two media variants (video fan, people collage) share one card.

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Number of portrait card slots in the video fan.
const _fanSlotCount = 5;

/// Width of every seam and outline painted over the media.
const _seamWidth = 2.0;

/// Corner radius of the media block and each fan slot.
const _mediaRadius = 16.0;

/// Media block aspect ratio (from Figma 177:120, shared by both variants
/// so equal-width cards come out equal-height).
const double _mediaAspectRatio = 177 / 120;

/// Portrait fan slot aspect ratio (width:height, from Figma 177:236).
const double _fanSlotAspectRatio = 177 / 236;

/// Fraction of the collage width taken by the large left tile.
///
/// From Figma: the right column starts at 66.1% of the media width.
const _largeTileFraction = 0.661;

/// One list rendered as a gallery thumbnail card: media block on top, then
/// a fixed-height title/description footer.
///
/// Every surface that shows a list card instantiates this widget, so its
/// appearance — media box, seams, badge, footer metrics — changes in one
/// place. The two variants differ only in the media block:
///
/// * [DivineListThumbnail.videos] fans out up to five video thumbnails with
///   a play-count badge.
/// * [DivineListThumbnail.people] collages up to three member avatars with
///   a member-count badge.
class DivineListThumbnail extends StatelessWidget {
  /// Card for a curated video list (kind 30005).
  ///
  /// [thumbnailsPending] says the list's thumbnails are still being
  /// resolved: fan slots that could still fill shimmer instead of sitting
  /// as flat placeholders. Slots beyond the list's video count never fill
  /// and stay flat either way.
  DivineListThumbnail.videos({
    required CuratedList curatedList,
    required this.onTap,
    this.thumbnailsPending = false,
    super.key,
  }) : name = curatedList.name,
       description = curatedList.description,
       isPrivate = !curatedList.isPublic,
       _count = curatedList.videoEventIds.length,
       _kind = _ListKind.videos,
       _media = _VideoFanMedia(
         thumbnailUrls: curatedList.thumbnailUrls,
         videoCount: curatedList.videoEventIds.length,
         pending: thumbnailsPending,
       );

  /// Card for a people list (kind 30000).
  DivineListThumbnail.people({
    required UserList userList,
    required this.onTap,
    super.key,
  }) : name = userList.name,
       description = userList.description,
       isPrivate = false,
       thumbnailsPending = false,
       _count = userList.pubkeys.length,
       _kind = _ListKind.people,
       _media = _PeopleCollageMedia(
         memberPubkeys: userList.pubkeys,
         memberCount: userList.pubkeys.length,
       );

  final String name;
  final String? description;

  /// A device-only list: the owner sees a lock beside the title so a
  /// private list and a shared one never look the same in My Lists.
  final bool isPrivate;
  final VoidCallback onTap;

  /// Whether a video list's thumbnails are still resolving; see [videos].
  final bool thumbnailsPending;
  final int _count;
  final _ListKind _kind;
  final Widget _media;

  /// One spoken sentence for the whole card: the name, its visibility when
  /// private, and the count the badge shows.
  ///
  /// The subtree is excluded so a screen reader does not read the title
  /// twice with a bare count in between — the badge and the footer are
  /// both decorative once this label carries their content. The description
  /// travels as the hint, so the card's text is still heard.
  String _semanticLabel(AppLocalizations l10n) => [
    name,
    if (isPrivate) l10n.listVisibilityPrivate,
    switch (_kind) {
      _ListKind.videos => l10n.listVideoCount(_count),
      _ListKind.people => l10n.listMemberCount(_count),
    },
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticLabel(context.l10n),
      hint: switch (description) {
        final text? when text.trim().isNotEmpty => text,
        _ => null,
      },
      // Without this the card is announced as text: the tap action is
      // exposed by the GestureDetector, but the role is not, so it never
      // shows up in a screen reader's button rotor.
      button: true,
      container: true,
      // Excluding the subtree also drops the GestureDetector's tap action,
      // so the node has to expose it itself or assistive tech cannot
      // activate the card.
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _media,
            const SizedBox(height: 8),
            _Footer(
              title: name,
              description: description,
              isPrivate: isPrivate,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ListKind { videos, people }

/// Overlapping portrait cards arranged left-to-right.
///
/// Renders [_fanSlotCount] cards where the leftmost card has the highest
/// z-index. Cards with a resolved thumbnail URL show the image; the rest
/// are colored placeholders.
class _VideoFanMedia extends StatelessWidget {
  const _VideoFanMedia({
    required this.thumbnailUrls,
    required this.videoCount,
    required this.pending,
  });

  final List<String> thumbnailUrls;
  final int videoCount;

  /// The resolver has not returned yet: empty slots that a video could
  /// still fill shimmer as bones.
  final bool pending;

  String? _urlAt(int index) =>
      index < thumbnailUrls.length ? thumbnailUrls[index] : null;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: pending,
      ignoreContainers: true,
      effect: listSkeletonEffectOf(context),
      child: _FanFrame(
        slotBuilder: (index) {
          final url = _urlAt(index);
          if (pending && url == null && index < videoCount) {
            return const _FanSlotBone();
          }
          return Skeleton.keep(child: _FanSlot(imageUrl: url));
        },
        badge: _CountBadge(icon: DivineIconName.play, count: videoCount),
      ),
    );
  }
}

/// The fan's geometry, shared by the card and its loading silhouette.
///
/// [_fanSlotCount] portrait slots step across the media box edge to edge,
/// index 0 on top, with an optional [badge] in the bottom-left corner.
class _FanFrame extends StatelessWidget {
  const _FanFrame({required this.slotBuilder, this.badge});

  final Widget Function(int index) slotBuilder;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mediaAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_mediaRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;
            final cardWidth = cardHeight * _fanSlotAspectRatio;
            final step = (totalWidth - cardWidth) / (_fanSlotCount - 1);

            return Stack(
              children: [
                // Cards in reverse order so index 0 is on top.
                for (int i = _fanSlotCount - 1; i >= 0; i--)
                  Positioned(
                    left: i * step,
                    top: 0,
                    width: cardWidth,
                    height: cardHeight,
                    child: slotBuilder(i),
                  ),
                if (badge case final badge?)
                  Positioned(
                    left: 8,
                    bottom: 9,
                    child: Skeleton.keep(child: badge),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A single portrait fan card with a border and optional image.
class _FanSlot extends StatelessWidget {
  const _FanSlot({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Foreground border, or the full-bleed thumbnail paints over it and
    // only the empty placeholder cards show their seams.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          width: _seamWidth,
          color: context.vineColors.surface,
        ),
        borderRadius: BorderRadius.circular(_mediaRadius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_mediaRadius),
          color: context.vineColors.containerLow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_mediaRadius),
          child: switch (imageUrl) {
            final url? => PassiveAuthThumbnailImage(
              url: url,
              alignment: Alignment.center,
              errorWidget: (_, _, _) => const SizedBox(),
              logName: 'DivineListThumbnail',
              logPrefix: 'List thumbnail',
            ),
            null => const SizedBox(),
          },
        ),
      ),
    );
  }
}

/// One large tile left, two stacked tiles right, badge bottom-left.
///
/// Each filled slot watches its member's profile here: a tile whose
/// profile is still loading shimmers as a bone, the same way a video
/// card's pending fan slots do, and settles into a picture or the accent
/// placeholder once the profile is known.
class _PeopleCollageMedia extends ConsumerWidget {
  const _PeopleCollageMedia({
    required this.memberPubkeys,
    required this.memberCount,
  });

  final List<String> memberPubkeys;
  final int memberCount;

  String? _pubkeyAt(int index) =>
      index < memberPubkeys.length ? memberPubkeys[index] : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = [
      for (var slot = 0; slot < 3; slot++)
        switch (_pubkeyAt(slot)) {
          final pubkey? => ref.watch(fetchUserProfileProvider(pubkey)),
          null => null,
        },
    ];
    final pending = profiles.any((profile) => profile?.isLoading ?? false);
    return Skeletonizer(
      enabled: pending,
      ignoreContainers: true,
      effect: listSkeletonEffectOf(context),
      child: _CollageFrame(
        tileBuilder: (slot, seams) {
          final profile = profiles[slot];
          if (profile != null && profile.isLoading) {
            return _TileBone(slot: slot, seams: seams);
          }
          return Skeleton.keep(
            child: _MemberTile(
              pubkey: _pubkeyAt(slot),
              pictureUrl: profile?.value?.picture,
              slot: slot,
              seams: seams,
            ),
          );
        },
        badge: _CountBadge(icon: DivineIconName.users, count: memberCount),
      ),
    );
  }
}

/// The collage's geometry, shared by the card and its loading silhouette.
///
/// Seam structure from Figma: the large tile (slot 0) carries the vertical
/// seam (right 2), the two small tiles (slots 1 and 2) split the horizontal
/// seam (bottom 1 / top 1), and the whole collage wears a 2px outline. The
/// outline is kept out of skeletonization so a silhouette still reads as
/// three tiles.
class _CollageFrame extends StatelessWidget {
  const _CollageFrame({required this.tileBuilder, this.badge});

  final Widget Function(int slot, Border seams) tileBuilder;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final seam = BorderSide(
      width: _seamWidth,
      color: context.vineColors.surface,
    );
    final halfSeam = seam.copyWith(width: _seamWidth / 2);

    return AspectRatio(
      aspectRatio: _mediaAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_mediaRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: (_largeTileFraction * 1000).round(),
                      child: tileBuilder(0, Border(right: seam)),
                    ),
                    Expanded(
                      flex: ((1 - _largeTileFraction) * 1000).round(),
                      child: Column(
                        children: [
                          Expanded(
                            child: tileBuilder(1, Border(bottom: halfSeam)),
                          ),
                          Expanded(
                            child: tileBuilder(2, Border(top: halfSeam)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (badge case final badge?)
                  Positioned(
                    left: 8,
                    bottom: 9,
                    child: Skeleton.keep(child: badge),
                  ),
              ],
            ),
          ),
          Skeleton.keep(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.fromBorderSide(seam),
                borderRadius: BorderRadius.circular(_mediaRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One collage tile: the member's profile picture, or an accent placeholder
/// with a generic avatar glyph when the profile has none (or no member fills
/// this slot).
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.pubkey,
    required this.pictureUrl,
    required this.slot,
    required this.seams,
  });

  final String? pubkey;

  /// The member's resolved profile picture, if any.
  final String? pictureUrl;

  /// Position in the collage; seeds the placeholder tone of an empty slot.
  final int slot;

  /// This tile's share of the collage seams, painted over the image.
  final Border seams;

  @override
  Widget build(BuildContext context) {
    // Same seed rule as UserAvatar, so a member keeps one accent across
    // every surface; the ink comes from the same palette so the glyph
    // reads on every fill rather than washing out on lime.
    final colors = userAvatarPlaceholderColors(
      userAvatarToneForSeed(pubkey ?? 'slot-$slot'),
    );
    final tile = switch (pictureUrl) {
      final url? when url.isNotEmpty => VineCachedImage(imageUrl: url),
      _ => ColoredBox(
        color: colors.base,
        child: Center(
          child: DivineIcon(
            icon: DivineIconName.user,
            color: colors.figure,
            size: 28,
          ),
        ),
      ),
    };

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: seams),
      child: tile,
    );
  }
}

/// Scrim badge overlaid on the media: an icon plus a compact count.
///
/// Fixed media chrome by design: the scrim and white ink sit on user imagery
/// in both appearances, and the badge must not scale with system text size
/// or it overflows its fixed corner.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.icon, required this.count});

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

/// The line box a [style] produces at the current text scale, independent
/// of content: emoji and fallback-font glyphs can stretch a line past the
/// style's declared height, and a content-dependent line silently breaks
/// the gallery's equal-height row contract.
double _scaledLineHeight(BuildContext context, TextStyle style) =>
    style.height! * MediaQuery.textScalerOf(context).scale(style.fontSize!);

/// Title and description block under the media.
///
/// Both variants share this structure so equal-width cards come out
/// equal-height and a two-column gallery reads as rows.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.title,
    required this.description,
    required this.isPrivate,
  });

  final String title;
  final String? description;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Title(title: title, isPrivate: isPrivate),
        _Description(description: description),
      ],
    );
  }
}

/// Single-line list title in a fixed one-line box, with a lock trailing it
/// when the list is private.
class _Title extends StatelessWidget {
  const _Title({required this.title, required this.isPrivate});

  final String title;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.titleSmallFont(
      color: context.vineColors.primaryText,
    );
    return SizedBox(
      height: _scaledLineHeight(context, style),
      width: double.infinity,
      child: Row(
        spacing: 4,
        children: [
          Expanded(
            child: Text(
              title,
              style: style,
              strutStyle: StrutStyle.fromTextStyle(
                style,
                forceStrutHeight: true,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPrivate)
            DivineIcon(
              icon: DivineIconName.lockSimple,
              size: 16,
              color: context.vineColors.secondaryText,
            ),
        ],
      ),
    );
  }
}

/// List description in a fixed two-line box.
///
/// The box keeps its two-line height whether the text overflows (trimmed
/// with an ellipsis), fits on one line, or is absent — that reserved space
/// is what keeps gallery rows level.
class _Description extends StatelessWidget {
  const _Description({required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodySmallFont(
      color: context.vineColors.secondaryText,
    );
    return SizedBox(
      height: _scaledLineHeight(context, style) * 2,
      width: double.infinity,
      child: switch (description) {
        final text? when text.isNotEmpty => ClipRect(
          child: _PlainLinkText(text: text, style: style),
        ),
        _ => null,
      },
    );
  }
}

/// [LinkifiedText] keeps its resolution behaviour (nostr mentions render as
/// display names) but drops the accent link styling: in a card preview the
/// whole card is the tap target, so links are plain description text.
class _PlainLinkText extends StatelessWidget {
  const _PlainLinkText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LinkifiedText(
      text: text,
      style: style,
      linkStyle: style,
      mentionStyle: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The shimmer every list-card placeholder uses, in the fan placeholder's
/// own fill so a bone and a flat slot read as the same surface.
PaintingEffect listSkeletonEffectOf(BuildContext context) =>
    vineSkeletonEffectOf(
      context,
      baseColor: context.vineColors.containerLow,
    );

/// The card's silhouette while its list is still on its way.
///
/// Same media geometry, gap and footer boxes as [DivineListThumbnail], so
/// a gallery column keeps its rows when the placeholders give way to cards,
/// and the same structure inside the media box: the five-slot fan for a
/// video list, the three-tile collage for a people list. Paints as bones
/// under an enclosing [Skeletonizer] with `ignoreContainers` on; the
/// caller owns the shimmer effect and the semantics label for the column.
class DivineListThumbnailSkeleton extends StatelessWidget {
  /// Silhouette of a video list card: the thumbnail fan.
  const DivineListThumbnailSkeleton.videos({super.key})
    : _kind = _ListKind.videos;

  /// Silhouette of a people list card: the avatar collage.
  const DivineListThumbnailSkeleton.people({super.key})
    : _kind = _ListKind.people;

  final _ListKind _kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    // The styles only size the bones; the colours match what the real
    // footer paints so the metrics come from the same styles.
    final titleLine = _scaledLineHeight(
      context,
      VineTheme.titleSmallFont(color: colors.primaryText),
    );
    final descriptionLine = _scaledLineHeight(
      context,
      VineTheme.bodySmallFont(color: colors.secondaryText),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (_kind) {
          _ListKind.videos => _FanFrame(
            slotBuilder: (_) => const _FanSlotBone(),
          ),
          _ListKind.people => _CollageFrame(
            tileBuilder: (slot, seams) => _TileBone(slot: slot, seams: seams),
          ),
        },
        const SizedBox(height: 8),
        _TextBone(lineHeight: titleLine, widthFactor: 0.6),
        _TextBone(lineHeight: descriptionLine, widthFactor: 0.9),
        _TextBone(lineHeight: descriptionLine, widthFactor: 0.7),
      ],
    );
  }
}

/// A fan slot as a bone: the shimmer fills the card shape, the seam stays
/// painted so neighbouring slots read as separate cards.
class _FanSlotBone extends StatelessWidget {
  const _FanSlotBone();

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Skeleton.leaf(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.containerLow,
              borderRadius: BorderRadius.circular(_mediaRadius),
            ),
          ),
        ),
        Skeleton.keep(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(width: _seamWidth, color: colors.surface),
              borderRadius: BorderRadius.circular(_mediaRadius),
            ),
          ),
        ),
      ],
    );
  }
}

/// A collage tile as a bone, with its share of the seams kept painted.
///
/// The card's tiles are square and the frame's clip rounds the collage; a
/// bone is painted by the skeletonizer outside that clip, so each tile
/// rounds the outer corner it owns itself and nothing shows past the
/// outline.
class _TileBone extends StatelessWidget {
  const _TileBone({required this.slot, required this.seams});

  final int slot;
  final Border seams;

  @override
  Widget build(BuildContext context) {
    const corner = Radius.circular(_mediaRadius);
    final corners = switch (slot) {
      0 => const BorderRadius.horizontal(left: corner),
      1 => const BorderRadius.only(topRight: corner),
      _ => const BorderRadius.only(bottomRight: corner),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Skeleton.leaf(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.containerLow,
              borderRadius: corners,
            ),
          ),
        ),
        Skeleton.keep(
          child: DecoratedBox(decoration: BoxDecoration(border: seams)),
        ),
      ],
    );
  }
}

/// One text line's box with a bone inside it, so the placeholder footer is
/// exactly as tall as the real one.
class _TextBone extends StatelessWidget {
  const _TextBone({required this.lineHeight, required this.widthFactor});

  final double lineHeight;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: lineHeight,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Skeleton.leaf(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.containerLow,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
