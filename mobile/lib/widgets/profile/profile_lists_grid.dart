// ABOUTME: Shows the current user's owned video lists on their profile.
// ABOUTME: Replaces the unreachable global-bookmarks surface with editable lists.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/owned_list_card.dart';

/// Owned video-list surface for the current user's profile.
class ProfileListsGrid extends ConsumerWidget {
  const ProfileListsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(curatedListsStateProvider);

    return listsAsync.when(
      data: (_) {
        final lists =
            ref.read(curatedListsStateProvider.notifier).service?.myLists ??
            const <CuratedList>[];
        return _ProfileListsContent(lists: lists);
      },
      loading: () => const Center(child: BrandedLoadingIndicator(size: 60)),
      error: (_, _) => Center(
        child: Text(
          context.l10n.listErrorLoading,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ProfileListsContent extends StatelessWidget {
  const _ProfileListsContent({required this.lists});

  final List<CuratedList> lists;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DivineButton(
            label: context.l10n.listCreateNewList,
            leadingIcon: DivineIconName.plus,
            expanded: true,
            onPressed: () => context.showVideoPausingDialog<void>(
              builder: (_) => const CreateListDialog(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _BookmarksEntry(),
        if (lists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              context.l10n.profileListsEmpty,
              textAlign: TextAlign.center,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          )
        else
          for (final list in lists) OwnedListCard(curatedList: list),
      ],
    );
  }
}

/// Entry point to the viewer's bookmarks.
///
/// Bookmarks are a NIP-51 kind 10003 list rather than a kind 30005 one, so
/// they can't come through [CuratedListCard] — but they are still one of the
/// viewer's lists, which is why they sit here rather than in a tab of their
/// own. Without this the share sheet's Save action would be write-only.
class _BookmarksEntry extends StatelessWidget {
  const _BookmarksEntry();

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
      label: context.l10n.shareMenuBookmarks,
      child: InkWell(
        onTap: () => context.push(SavedVideosScreen.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            spacing: 12,
            children: [
              // Coloured for the same reason the label is: the asset is a
              // hardcoded white fill, and DivineIcon applies no filter when
              // color is null, so it disappears on the light palette.
              DivineIcon(icon: .bookmarkSimple, color: colors.primaryText),
              Expanded(
                child: Text(
                  context.l10n.shareMenuBookmarks,
                  style: VineTheme.titleSmallFont(color: colors.primaryText),
                ),
              ),
              DivineIcon(icon: .caretRight, color: colors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
