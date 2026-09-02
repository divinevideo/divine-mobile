// ABOUTME: Card widget for a NIP-51 kind 30000 people list in discovery grids.
// ABOUTME: Shows a member-avatar collage with a count badge, plus title and
// ABOUTME: description below. Designed for 2-column grid layout.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/list_card_parts.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Media collage aspect ratio (from Figma 177:120, same as the video card).
const double _mediaAspectRatio = 177 / 120;

/// Corner radius of the collage block.
const _mediaRadius = 16.0;

/// Border width separating collage tiles.
const _tileBorder = 2.0;

/// Fraction of the collage width taken by the large left tile.
///
/// From Figma: the right column starts at 66.1% of the media width.
const _largeTileFraction = 0.661;

/// Placeholder accents for members without a profile picture, matching the
/// design's colored generic-avatar tiles. Brand accents, not surface tokens:
/// the tile is media, identical in both appearances.
const List<Color> _placeholderTones = [
  VineTheme.accentLime,
  VineTheme.accentViolet,
  VineTheme.accentOrange,
  VineTheme.accentPink,
];

/// Discovery card for a people list (kind 30000).
///
/// Shows up to three member avatars in a one-large-two-small collage with a
/// member-count badge, plus title and description below. Members without a
/// picture render as an accent tile with a generic avatar glyph.
class PeopleListCard extends StatelessWidget {
  const PeopleListCard({
    required this.userList,
    required this.onTap,
    super.key,
  });

  final UserList userList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: userList.name,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MemberCollage(
              memberPubkeys: userList.pubkeys,
              memberCount: userList.pubkeys.length,
            ),
            const SizedBox(height: 8),
            ListCardTitle(title: userList.name),
            if (userList.description case final description?
                when description.isNotEmpty) ...[
              const SizedBox(height: 2),
              ListCardDescription(description: description),
            ],
          ],
        ),
      ),
    );
  }
}

/// One large tile left, two stacked tiles right, badge bottom-left.
class _MemberCollage extends StatelessWidget {
  const _MemberCollage({
    required this.memberPubkeys,
    required this.memberCount,
  });

  final List<String> memberPubkeys;
  final int memberCount;

  String? _pubkeyAt(int index) =>
      index < memberPubkeys.length ? memberPubkeys[index] : null;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mediaAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_mediaRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                Expanded(
                  flex: (_largeTileFraction * 1000).round(),
                  child: _MemberTile(pubkey: _pubkeyAt(0), toneIndex: 0),
                ),
                Expanded(
                  flex: ((1 - _largeTileFraction) * 1000).round(),
                  child: Column(
                    children: [
                      Expanded(
                        child: _MemberTile(pubkey: _pubkeyAt(1), toneIndex: 1),
                      ),
                      Expanded(
                        child: _MemberTile(pubkey: _pubkeyAt(2), toneIndex: 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 9,
              child: ListCardBadge(
                icon: DivineIconName.users,
                count: memberCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One collage tile: the member's profile picture, or an accent placeholder
/// with a generic avatar glyph when the profile has none (or no member fills
/// this slot).
class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.pubkey, required this.toneIndex});

  final String? pubkey;
  final int toneIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pictureUrl = switch (pubkey) {
      final pubkey? =>
        ref.watch(fetchUserProfileProvider(pubkey)).value?.picture,
      null => null,
    };

    final tile = pictureUrl == null || pictureUrl.isEmpty
        ? ColoredBox(
            color: _placeholderTones[toneIndex % _placeholderTones.length],
            child: const Center(
              child: DivineIcon(
                icon: DivineIconName.user,
                color: VineTheme.whiteText,
                size: 28,
              ),
            ),
          )
        : VineCachedImage(imageUrl: pictureUrl);

    // The 2px surface-container-high seams between tiles match the video
    // card's bordered fan.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          width: _tileBorder,
          color: context.vineColors.surfaceContainerHigh,
        ),
      ),
      child: tile,
    );
  }
}
