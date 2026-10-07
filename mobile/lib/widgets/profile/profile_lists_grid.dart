// ABOUTME: Own-profile list management with independent people and video sections.
// ABOUTME: Retains bookmarks and explicit creation choices during loading and failures.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/list_card.dart';
import 'package:openvine/widgets/owned_list_card.dart';

/// Independently loaded people and video lists owned by the profile viewer.
class ProfileListsGrid extends ConsumerWidget {
  const ProfileListsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        if (peopleEnabled) const _PeopleListsSection(),
        _SectionHeading(title: context.l10n.exploreVideoLists),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DivineButton(
            label: context.l10n.listNewVideoList,
            leadingIcon: DivineIconName.plus,
            expanded: true,
            onPressed: () => context.showVideoPausingDialog<void>(
              builder: (_) => const CreateListDialog(),
            ),
          ),
        ),
        const _BookmarksEntry(),
        const _VideoListsSection(),
      ],
    );
  }
}

class _PeopleListsSection extends StatelessWidget {
  const _PeopleListsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PeopleListsBloc, PeopleListsState>(
      builder: (context, state) {
        if (!state.enabled || state.activeOwnerPubkey == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeading(title: context.l10n.explorePeopleLists),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DivineButton(
                label: context.l10n.listNewPeopleList,
                leadingIcon: DivineIconName.plus,
                expanded: true,
                onPressed: () => context.push(CreatePeopleListPage.path),
              ),
            ),
            for (final list in state.lists)
              UserListCard(
                userList: list,
                onTap: () => context.push(
                  '/people-lists/${Uri.encodeComponent(list.id)}',
                ),
              ),
            if (state.ownerReadStatus == PeopleListsOwnerReadStatus.failed)
              _ListReadFailure(
                onRetry: () => context.read<PeopleListsBloc>().add(
                  const PeopleListsOwnerSyncRequested(),
                ),
              )
            else if (!state.listsKnown)
              const _ListLoading()
            else if (state.lists.isEmpty)
              _ListMessage(text: context.l10n.peopleListsEmptySubtitle),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _VideoListsSection extends ConsumerWidget {
  const _VideoListsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(curatedListsStateProvider);
    return listsAsync.when(
      data: (_) {
        final lists =
            ref.read(curatedListsStateProvider.notifier).service?.myLists ??
            const <CuratedList>[];
        if (lists.isEmpty) {
          return _ListMessage(text: context.l10n.profileListsEmpty);
        }
        return Column(
          children: [
            for (final list in lists) OwnedListCard(curatedList: list),
          ],
        );
      },
      loading: () => const _ListLoading(),
      error: (_, _) => _ListReadFailure(
        onRetry: () => ref.invalidate(curatedListsStateProvider),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Text(
      title,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
  );
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: BrandedLoadingIndicator(size: 40)),
  );
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: VineTheme.bodyMediumFont(color: context.vineColors.secondaryText),
    ),
  );
}

class _ListReadFailure extends StatelessWidget {
  const _ListReadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ListMessage(text: context.l10n.listErrorLoading),
      DivineButton(
        label: context.l10n.peopleListsAddPeopleRetry,
        onPressed: onRetry,
      ),
    ],
  );
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
