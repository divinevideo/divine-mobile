// ABOUTME: Card widget for displaying user lists and curated video lists
// ABOUTME: Shows list metadata with proper dark theme styling

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/user_name.dart';

/// Card for displaying a user list (kind 30000 - people list)
class UserListCard extends StatelessWidget {
  const UserListCard({required this.userList, required this.onTap, super.key});

  final UserList userList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.vineColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DivineIcon(
                    icon: DivineIconName.users,
                    color: context.vineColors.accentPositive,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userList.name,
                          style: TextStyle(
                            color: context.vineColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (userList.description != null) ...[
                          const SizedBox(height: 4),
                          LinkifiedText(
                            text: userList.description!,
                            style: TextStyle(
                              color: context.vineColors.secondaryText,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: context.vineColors.secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.listPersonCount(userList.pubkeys.length),
                style: TextStyle(
                  color: context.vineColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for displaying a curated video list (kind 30005)
class CuratedListCard extends StatelessWidget {
  const CuratedListCard({
    required this.curatedList,
    required this.onTap,
    this.showVisibility = false,
    this.showAuthor = true,
    super.key,
  });

  final CuratedList curatedList;
  final VoidCallback onTap;
  final bool showVisibility;

  /// Whether to credit the list's creator.
  ///
  /// Off for the viewer's own lists: every list they create is stamped with
  /// their pubkey, so the row would credit them to themselves. The curated
  /// list feed screen suppresses its own creator row for the same reason.
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.vineColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.video_library,
                    color: context.vineColors.accentPositive,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          curatedList.name,
                          style: TextStyle(
                            color: context.vineColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (curatedList.description != null) ...[
                          const SizedBox(height: 4),
                          LinkifiedText(
                            text: curatedList.description!,
                            style: TextStyle(
                              color: context.vineColors.secondaryText,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: context.vineColors.secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    context.l10n.listVideoCount(
                      curatedList.videoEventIds.length,
                    ),
                    style: TextStyle(
                      color: context.vineColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  if (curatedList.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: context.vineColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        curatedList.tags.take(3).map((t) => '#$t').join(' '),
                        style: TextStyle(
                          color: context.vineColors.accentPositive,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (showAuthor && curatedList.pubkey != null) ...[
                const SizedBox(height: 8),
                _CuratedListAuthor(pubkey: curatedList.pubkey!),
              ],
              if (showVisibility) ...[
                const SizedBox(height: 8),
                _ListVisibilityBadge(isPublic: curatedList.isPublic),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CuratedListAuthor extends StatelessWidget {
  const _CuratedListAuthor({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.listByAuthorPrefix,
          style: VineTheme.labelSmallFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        Flexible(
          child: UserName.fromPubKey(
            pubkey,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ListVisibilityBadge extends StatelessWidget {
  const _ListVisibilityBadge({required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        DivineIcon(
          icon: isPublic ? DivineIconName.globe : DivineIconName.lockSimple,
          size: 14,
          color: context.vineColors.secondaryText,
        ),
        Text(
          isPublic
              ? context.l10n.listVisibilityPublic
              : context.l10n.listVisibilityPrivate,
          style: VineTheme.labelSmallFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
