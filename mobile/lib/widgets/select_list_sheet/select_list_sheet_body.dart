// ABOUTME: The list picker's rows, one per list the viewer can put the video
// ABOUTME: in, with the failure line above them; and its pinned create button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/list_picker_create_button.dart';
import 'package:openvine/widgets/list_picker_row.dart';

/// The picker's body; needs a [SelectListCubit] above it.
///
/// Closes the sheet once the picks are saved. [scrollController] is the
/// sheet's, so dragging the rows moves the sheet.
class SelectListSheetBody extends StatelessWidget {
  /// Creates the body.
  const SelectListSheetBody({required this.scrollController, super.key});

  /// The sheet's scroll controller.
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SelectListCubit, SelectListState>(
      listenWhen: (previous, current) => !previous.canClose && current.canClose,
      listener: (context, _) => context.popModalIfMounted(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SaveFailedMessage(),
          Expanded(child: _ListRows(scrollController: scrollController)),
        ],
      ),
    );
  }
}

class _SaveFailedMessage extends StatelessWidget {
  const _SaveFailedMessage();

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (SelectListCubit cubit) => cubit.state.status,
    );
    return switch (status) {
      SelectListStatus.failure => ListInfoFailureMessage(
        context.l10n.listUpdateFailed,
      ),
      SelectListStatus.failureListFull => ListInfoFailureMessage(
        context.l10n.listPrivateFull,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ListRows extends ConsumerWidget {
  const _ListRows({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = context.select((SelectListCubit cubit) => cubit.state.lists);
    if (lists.isEmpty) return const _EmptyHint();
    // The resolver only supplies thumbnails and lags behind the service: a
    // list it has not reached yet renders its fan with placeholder cards,
    // shimmering until its first pass lands.
    final hydrated = ref.watch(myListsWithThumbnailsProvider).value;
    final thumbnailsById = {
      for (final list in hydrated ?? const <CuratedList>[])
        if (list.thumbnailUrls.isNotEmpty) list.id: list.thumbnailUrls,
    };
    // The sheet's own surface sits above the modal's Material, so the rows
    // need a transparent one of their own for their ink to show.
    return Material(
      type: MaterialType.transparency,
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: lists.length,
        itemBuilder: (context, index) {
          final list = lists[index];
          return _ListRow(
            list: list,
            thumbnailUrls: thumbnailsById[list.id] ?? const [],
            thumbnailsPending: hydrated == null,
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        context.l10n.profileListsEmpty,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.list,
    required this.thumbnailUrls,
    required this.thumbnailsPending,
  });

  final CuratedList list;

  /// The list's resolved video thumbnails, in fan order.
  final List<String> thumbnailUrls;

  /// Whether the resolver has yet to return for the viewer's lists.
  final bool thumbnailsPending;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSelected = context.select(
      (SelectListCubit cubit) => cubit.state.isSelected(list.id),
    );
    final isSaving = context.select(
      (SelectListCubit cubit) => cubit.state.isSaving,
    );
    final visibility = list.isPublic
        ? l10n.listVisibilityPublic
        : l10n.listVisibilityPrivate;
    return ListPickerRow(
      media: DivineListMedia.videos(
        thumbnailUrls: thumbnailUrls,
        videoCount: list.videoEventIds.length,
        pending: thumbnailsPending,
        showCount: false,
      ),
      title: list.name,
      meta: '${l10n.listVideoCount(list.videoEventIds.length)} • $visibility',
      isSelected: isSelected,
      onTap: isSaving
          ? null
          : () => context.read<SelectListCubit>().toggled(list.id),
    );
  }
}

/// The "Create New List" button pinned under the rows; needs a
/// [SelectListCubit] above it.
class SelectListCreateButton extends StatelessWidget {
  /// Creates the button for the picker opened on [video].
  const SelectListCreateButton({required this.video, super.key});

  /// The video the created list starts with.
  final VideoEvent video;

  Future<void> _create(BuildContext context) async {
    // Read before the await: the button may be gone when the sheet closes.
    final cubit = context.read<SelectListCubit>();
    final outcome = await showListInfoSheet(context, video: video);
    if (outcome == ListInfoSheetOutcome.createdWithoutVideo) {
      cubit.createdListRefusedVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (SelectListCubit cubit) => cubit.state.isSaving,
    );
    return ListPickerCreateButton(
      onPressed: isSaving
          ? null
          : () => runDetached(
              _create(context),
              'open list creation sheet',
              logName: 'SelectListSheet',
              category: LogCategory.ui,
            ),
    );
  }
}
