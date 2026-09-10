// ABOUTME: Card widget for displaying people list (kind 30000) search results.
// ABOUTME: Shows an avatar collage with member count badge,
// ABOUTME: plus title and description below. Designed for 2-column grid layout.

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Number of avatar slots to display in the collage.
const _avatarSlotCount = 4;

/// Corner radius for the collage container.
const _collageRadius = 16.0;

/// Border width around each avatar.
const _avatarBorder = 2.0;

/// Search card for a people list (kind 30000).
///
/// Shows a 2×2 avatar collage with a member count badge,
/// plus title and description below. Designed for 2-column grid layout.
class PeopleListSearchCard extends StatelessWidget {
  const PeopleListSearchCard({
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
      button: true,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AvatarCollage(
              pubkeys: userList.pubkeys,
              memberCount: userList.pubkeys.length,
            ),
            const SizedBox(height: 8),
            _ListTitle(title: userList.name),
            if (userList.description != null &&
                userList.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              _ListDescription(description: userList.description!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle({required this.title});

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

class _ListDescription extends StatelessWidget {
  const _ListDescription({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return LinkifiedText(
      text: description,
      style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 2×2 grid of avatar thumbnails with a member count badge.
///
/// Renders up to [_avatarSlotCount] avatars. Slots without a resolved
/// avatar URL show a coloured placeholder.
class _AvatarCollage extends StatelessWidget {
  const _AvatarCollage({required this.pubkeys, required this.memberCount});

  final List<String> pubkeys;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSize = constraints.maxWidth;
          final cellSize = (totalSize - _avatarBorder) / 2;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.containerLow,
              borderRadius: BorderRadius.circular(_collageRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_collageRadius),
              child: Stack(
                children: [
                  // 2×2 grid of avatar cells
                  for (int i = 0; i < _avatarSlotCount; i++)
                    Positioned(
                      left: (i % 2) * (cellSize + _avatarBorder),
                      top: (i ~/ 2) * (cellSize + _avatarBorder),
                      width: cellSize,
                      height: cellSize,
                      child: _AvatarCell(
                        pubkey: i < pubkeys.length ? pubkeys[i] : null,
                        tone:
                            UserAvatarPlaceholderTone.values[(i + 1) %
                                UserAvatarPlaceholderTone.values.length],
                      ),
                    ),
                  // Member count badge
                  Positioned(
                    left: 8,
                    bottom: 9,
                    child: _MemberCountBadge(count: memberCount),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A single avatar cell in the collage.
class _AvatarCell extends StatelessWidget {
  const _AvatarCell({required this.tone, this.pubkey});

  final UserAvatarPlaceholderTone tone;
  final String? pubkey;

  @override
  Widget build(BuildContext context) {
    // We only have pubkeys here, not resolved picture URLs.
    // The avatar widget handles placeholder rendering when imageUrl is null.
    return UserAvatar(
      name: pubkey,
      size: double.infinity,
      placeholderTone: tone,
    );
  }
}

class _MemberCountBadge extends StatelessWidget {
  const _MemberCountBadge({required this.count});

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
              const DivineIcon(
                icon: DivineIconName.user,
                color: VineTheme.primaryText,
                size: 16,
              ),
              Text(
                CountFormatter.formatCompact(count),
                style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
