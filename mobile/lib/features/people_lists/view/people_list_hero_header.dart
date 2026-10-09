// ABOUTME: Hero block of a people list: title, member, video and loop totals,
// ABOUTME: the description, and a preview of the members who post the most.

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/people_lists/view/people_list_member_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/vanished_account_identity.dart';

/// How many members the hero piles up before "View all".
const kPeopleListPreviewMembers = 5;

/// How far each piled avatar sits behind the one before it.
const _previewOverlap = 8.0;

/// The block scrolled with a people list's video grid: name, the stats line,
/// the description and the members preview that opens the full roster.
class PeopleListHeroHeader extends StatelessWidget {
  const PeopleListHeroHeader({
    required this.name,
    required this.memberCount,
    required this.previewPubkeys,
    required this.onViewAll,
    this.description,
    this.totalVideos,
    this.totalLoops,
    super.key,
  });

  final String name;
  final int memberCount;

  /// Members to pile up, best-ranked first, without the ones hidden from
  /// the viewer; only the first [kPeopleListPreviewMembers] are drawn. Empty
  /// drops the members row.
  final List<String> previewPubkeys;

  final VoidCallback onViewAll;
  final String? description;

  /// Totals across the members with stats; `null` hides the figure.
  final int? totalVideos;
  final double? totalLoops;

  @override
  Widget build(BuildContext context) {
    final description = this.description?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            header: true,
            child: Text(
              name,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
          _StatsLine(
            memberCount: memberCount,
            totalVideos: totalVideos,
            totalLoops: totalLoops,
          ),
          if (description != null && description.isNotEmpty)
            Text(
              description,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          // Keyed on who the viewer can see, not the count: a list whose
          // members are all hidden would otherwise lead to an empty roster.
          if (previewPubkeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PeopleListMembersPreview(
                pubkeys: previewPubkeys
                    .take(kPeopleListPreviewMembers)
                    .toList(),
                onViewAll: onViewAll,
              ),
            ),
        ],
      ),
    );
  }
}

/// "33 members ∙ 88 videos ∙ 89.4B loops", dropping the figures that are
/// not known, with the separators dimmed like the design.
class _StatsLine extends StatelessWidget {
  const _StatsLine({
    required this.memberCount,
    required this.totalVideos,
    required this.totalLoops,
  });

  final int memberCount;
  final int? totalVideos;
  final double? totalLoops;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalVideos = this.totalVideos;
    final totalLoops = this.totalLoops?.round();
    final figures = [
      l10n.listMemberCount(memberCount),
      if (totalVideos != null) l10n.listVideoCount(totalVideos),
      if (totalLoops != null)
        l10n.listLoopsCount(
          totalLoops,
          CountFormatter.formatCompact(totalLoops),
        ),
    ];
    return Text.rich(
      TextSpan(
        style: VineTheme.labelLargeFont(color: context.vineColors.primaryText),
        children: [
          for (var i = 0; i < figures.length; i++) ...[
            if (i > 0)
              TextSpan(
                text: l10n.listStatsSeparator,
                style: VineTheme.labelLargeFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            TextSpan(text: figures[i]),
          ],
        ],
      ),
    );
  }
}

/// The piled avatars of the members who post the most, and the "View all"
/// affordance beside them. The whole row is one tap target for the roster.
class PeopleListMembersPreview extends StatelessWidget {
  const PeopleListMembersPreview({
    required this.pubkeys,
    required this.onViewAll,
    super.key,
  });

  final List<String> pubkeys;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.peopleListsViewAllMembers,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onViewAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              ExcludeSemantics(child: _AvatarPile(pubkeys: pubkeys)),
              const SizedBox(width: 8),
              Expanded(
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.peopleListsViewAllMembers,
                          style: VineTheme.titleMediumFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                      ),
                      DivineIcon(
                        icon: DivineIconName.caretRight,
                        color: context.vineColors.primaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPile extends StatelessWidget {
  const _AvatarPile({required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context) {
    if (pubkeys.isEmpty) {
      return const SizedBox(height: kPeopleListMemberAvatarSize);
    }
    const step = kPeopleListMemberAvatarSize - _previewOverlap;
    return SizedBox(
      height: kPeopleListMemberAvatarSize,
      width: kPeopleListMemberAvatarSize + step * (pubkeys.length - 1),
      child: Stack(
        children: [
          // Painted last to first so the best-ranked member tops the pile.
          for (var i = pubkeys.length - 1; i >= 0; i--)
            PositionedDirectional(
              start: step * i,
              child: _PreviewAvatar(pubkey: pubkeys[i]),
            ),
        ],
      ),
    );
  }
}

class _PreviewAvatar extends ConsumerWidget {
  const _PreviewAvatar({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picture = ref
        .watch(userProfileReactiveProvider(pubkey))
        .value
        ?.picture;
    return PeopleListMemberAvatar(
      pubkey: pubkey,
      pictureUrl: vanishedAccountPictureUrl(
        isVanished: ref.watch(profileVanishedProvider(pubkey)),
        pictureUrl: picture,
      ),
    );
  }
}
