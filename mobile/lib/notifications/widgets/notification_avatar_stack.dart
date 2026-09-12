// ABOUTME: Overlapping rounded-square avatar stack for grouped notifications.
// ABOUTME: Shows 1-3 actor avatars with optional overflow count indicator.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Renders 1-3 overlapping rounded-square avatars for grouped notifications.
///
/// When [overflowCount] is greater than zero, a "+N" tile is appended after
/// the last avatar.
class NotificationAvatarStack extends StatelessWidget {
  const NotificationAvatarStack({
    required this.actors,
    this.overflowCount,
    super.key,
  });

  /// The actors whose avatars to display (max 3 are shown).
  final List<ActorInfo> actors;

  /// Number of additional actors beyond those displayed.
  final int? overflowCount;

  static const double _tileSize = NotificationConstants.avatarSize;
  static const double _tileRadius = NotificationConstants.avatarCornerRadius;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final displayActors = actors.take(3).toList();
    final showOverflow = (overflowCount ?? 0) > 0;
    final itemCount = displayActors.length + (showOverflow ? 1 : 0);
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }
    final totalWidth = _tileSize + (_tileSize - _overlap) * (itemCount - 1);

    // The parent row owns the semantic label for the avatar group; the
    // individual tiles are decorative and would otherwise produce one
    // duplicate "<name> avatar" announcement per actor.
    return ExcludeSemantics(
      child: SizedBox(
        width: totalWidth,
        height: _tileSize,
        child: Stack(
          children: [
            for (var i = 0; i < displayActors.length; i++)
              Positioned(
                left: (_tileSize - _overlap) * i,
                child: _AvatarTile(actor: displayActors[i]),
              ),
            if (showOverflow)
              Positioned(
                left: (_tileSize - _overlap) * displayActors.length,
                child: _OverflowTile(count: overflowCount!),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.actor});

  final ActorInfo actor;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: actor.pictureUrl,
      name: actor.displayName,
      placeholderSeed: actor.pubkey,
      size: NotificationAvatarStack._tileSize,
      cornerRadius: NotificationAvatarStack._tileRadius,
    );
  }
}

class _OverflowTile extends StatelessWidget {
  const _OverflowTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NotificationAvatarStack._tileSize,
      height: NotificationAvatarStack._tileSize,
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(
          NotificationAvatarStack._tileRadius,
        ),
        border: Border.all(
          color: context.vineColors.disabled,
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: VineTheme.labelSmallFont(
          color: context.vineColors.secondaryText,
        ),
      ),
    );
  }
}
