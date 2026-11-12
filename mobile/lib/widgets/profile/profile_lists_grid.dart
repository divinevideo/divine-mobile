// ABOUTME: Own-profile Lists tab: one create button over a two-column gallery
// ABOUTME: that mixes video and people lists, newest first.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/curated_list_initialization_failure.dart';
import 'package:openvine/widgets/curated_list_recovery_read_only_notice.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/profile/profile_list_entries.dart';

/// The profile viewer's own video and people lists in one gallery.
class ProfileListsGrid extends StatelessWidget {
  const ProfileListsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: const [_CreateListHeader(), _ListsGallery()],
    );
  }
}

enum _NewListType { video, people }

class _CreateListHeader extends ConsumerWidget {
  const _CreateListHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the read-only notice follows the service after a reload.
    ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final videoReadOnly = service?.recoveryNeedsRepair ?? false;
    final peopleAvailable = context.select(
      (PeopleListsBloc bloc) => bloc.state.activeOwnerPubkey != null,
    );
    final types = [
      if (!videoReadOnly) _NewListType.video,
      if (peopleAvailable) _NewListType.people,
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (videoReadOnly) const CuratedListRecoveryReadOnlyNotice(),
          DivineButton(
            label: context.l10n.listCreateNewList,
            leadingIcon: DivineIconName.plus,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: types.isEmpty
                ? null
                : () => runDetached(
                    _createList(context, types),
                    'open list creation',
                    logName: 'ProfileListsGrid',
                    category: LogCategory.ui,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createList(
    BuildContext context,
    List<_NewListType> types,
  ) async {
    final type = types.length == 1 ? types.single : await _pickType(context);
    if (type == null || !context.mounted) return;
    switch (type) {
      case _NewListType.video:
        await showListInfoSheet(context);
      case _NewListType.people:
        await const CreatePeopleListRouteData().push<void>(context);
    }
  }

  Future<_NewListType?> _pickType(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await context.showVideoPausingSelectionMenu(
      title: Text(l10n.listTypeSheetTitle),
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.listTypeVideoList,
          value: _NewListType.video.name,
          leadingIcon: DivineIconName.play,
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.listTypePeopleList,
          value: _NewListType.people.name,
          leadingIcon: DivineIconName.users,
        ),
      ],
    );
    return _NewListType.values.asNameMap()[picked];
  }
}

enum _SourceStatus { loading, ready, failed }

/// Cards from whichever source has loaded, with each source's own loading
/// and failure state below them.
class _ListsGallery extends ConsumerWidget {
  const _ListsGallery();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final videoStatus = listsAsync.when(
      data: (_) => _SourceStatus.ready,
      loading: () => _SourceStatus.loading,
      error: (_, _) => _SourceStatus.failed,
    );
    final ownLists = videoStatus == _SourceStatus.ready
        ? service?.myLists ?? const <CuratedList>[]
        : const <CuratedList>[];
    var thumbnailsPending = false;
    var videoLists = ownLists;
    if (ownLists.isNotEmpty) {
      // Retained previews belong to a prior account/policy until the
      // current hydration has completed successfully.
      final hydration = ref.watch(myListsWithThumbnailsProvider);
      final hydrated = switch (hydration) {
        AsyncData(isLoading: false, :final value) => value,
        _ => null,
      };
      videoLists = _withResolvedThumbnails(ownLists, hydrated);
      thumbnailsPending = hydration.isLoading;
    }

    final people = context.watch<PeopleListsBloc>().state;
    final peopleAvailable = people.activeOwnerPubkey != null;
    final peopleFailed =
        peopleAvailable &&
        people.ownerReadStatus == PeopleListsOwnerReadStatus.failed;
    final peopleLoading =
        peopleAvailable && !peopleFailed && !people.listsKnown;
    final peopleLists = peopleAvailable ? people.lists : const <UserList>[];

    final entries = mergeProfileLists(
      videoLists: videoLists,
      peopleLists: peopleLists,
    );
    final videoFailed = videoStatus == _SourceStatus.failed;
    final loading = videoStatus == _SourceStatus.loading || peopleLoading;
    final isEmpty =
        entries.isEmpty && !loading && !videoFailed && !peopleFailed;
    // The people owner read fails whenever one relay is slow to settle, even
    // though the lists came back; under a full gallery its error reads as if
    // every card failed, so it shows only when there is nothing to show.
    // While a source is still loading there may yet be something to show.
    final showsPeopleReadFailure = peopleFailed && entries.isEmpty && !loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isNotEmpty)
          _ListsGrid(entries: entries, thumbnailsPending: thumbnailsPending),
        if (loading) const _ListLoading(),
        if (videoFailed)
          CuratedListInitializationFailure(
            onRetry: () => ref.invalidate(curatedListsStateProvider),
          ),
        if (showsPeopleReadFailure)
          _ListReadFailure(
            onRetry: () => context.read<PeopleListsBloc>().add(
              const PeopleListsOwnerSyncRequested(),
            ),
          ),
        if (isEmpty) _ListMessage(text: context.l10n.profileListsEmpty),
      ],
    );
  }
}

/// [ownLists] with thumbnails filled in from [hydrated] where the resolver
/// has caught up.
///
/// Lists it has not reached yet keep their placeholder fan rather than
/// dropping out of the gallery.
List<CuratedList> _withResolvedThumbnails(
  List<CuratedList> ownLists,
  List<CuratedList>? hydrated,
) {
  final thumbnailsById = <String, List<String>>{
    for (final list in hydrated ?? const <CuratedList>[])
      if (list.thumbnailUrls.isNotEmpty)
        list.authorScopedId: list.thumbnailUrls,
  };
  return [
    for (final list in ownLists)
      // Stored thumbnails have not passed the current policy/owner hydration.
      list.copyWith(
        thumbnailUrls: thumbnailsById[list.authorScopedId] ?? const [],
      ),
  ];
}

/// Two columns, filled row by row; cards in a row align to the top because
/// a description can make one card taller than its neighbour.
class _ListsGrid extends StatelessWidget {
  const _ListsGrid({required this.entries, required this.thumbnailsPending});

  final List<ProfileListEntry> entries;
  final bool thumbnailsPending;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          for (var i = 0; i < entries.length; i += 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Expanded(
                  child: _ListCard(
                    entry: entries[i],
                    thumbnailsPending: thumbnailsPending,
                  ),
                ),
                Expanded(
                  child: i + 1 < entries.length
                      ? _ListCard(
                          entry: entries[i + 1],
                          thumbnailsPending: thumbnailsPending,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.entry, required this.thumbnailsPending});

  final ProfileListEntry entry;
  final bool thumbnailsPending;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      ProfileVideoListEntry(:final list) => DivineListThumbnail.videos(
        // Lists are created, deleted and re-hydrated in place, so cards
        // shift slots; the key keeps each card's image state with its list.
        key: ValueKey(list.authorScopedId),
        curatedList: list,
        thumbnailsPending: thumbnailsPending,
        onTap: () => runDetached(
          CuratedListFeedRouteData(
            listId: list.id,
            $extra: CuratedListRouteExtra(listName: list.name),
          ).push<void>(context),
          'open owned list',
          logName: 'ProfileListsGrid',
          category: LogCategory.ui,
        ),
      ),
      ProfilePeopleListEntry(:final list) => DivineListThumbnail.people(
        key: ValueKey(list.id),
        userList: list,
        onTap: () => runDetached(
          PeopleListRouteData(listId: list.id).push<void>(context),
          'open owned people list',
          logName: 'ProfileListsGrid',
          category: LogCategory.ui,
        ),
      ),
    };
  }
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
