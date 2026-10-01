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
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Edge of a row's list thumbnail (Figma 14085:129140).
const double _thumbnailSize = 40;

/// Corner radius of a row's list thumbnail.
const double _thumbnailRadius = 16;

/// Edge of the check that marks a picked row, and of the space an unpicked
/// row keeps for it so the titles line up.
const double _checkSize = 24;

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
    // The resolver only supplies thumbnails and lags behind the service, so
    // a list it has not reached yet renders with the placeholder.
    final thumbnailById = {
      for (final list
          in ref.watch(myListsWithThumbnailsProvider).value ??
              const <CuratedList>[])
        if (list.thumbnailUrls.firstOrNull case final url? when url.isNotEmpty)
          list.id: url,
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
          return _ListRow(list: list, thumbnailUrl: thumbnailById[list.id]);
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
  const _ListRow({required this.list, required this.thumbnailUrl});

  final CuratedList list;

  /// The list's first resolved video thumbnail, if any.
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
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
    final subtitle =
        '${l10n.listVideoCount(list.videoEventIds.length)} • '
        '$visibility';

    return Semantics(
      checked: isSelected,
      child: InkWell(
        onTap: isSaving
            ? null
            : () => context.read<SelectListCubit>().toggled(list.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineDisabled)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              spacing: 16,
              children: [
                _ListThumbnail(url: thumbnailUrl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VineTheme.titleMediumFont(
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VineTheme.bodyMediumFont(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: DivineIcon.scaleSize(context, _checkSize),
                  child: isSelected
                      ? DivineIcon(
                          icon: DivineIconName.check,
                          color: colors.accentPositive,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListThumbnail extends StatelessWidget {
  const _ListThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final size = DivineIcon.scaleSize(context, _thumbnailSize);
    final radius = BorderRadius.circular(_thumbnailRadius);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.disabled),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: switch (url) {
              final url? => VineCachedImage(
                imageUrl: url,
                width: size,
                height: size,
              ),
              null => ColoredBox(
                color: colors.surfaceContainer,
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.playlist,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// The "Create New List" button pinned under the rows; needs a
/// [SelectListCubit] above it.
///
/// Goes in the sheet's bottom slot, which keeps it below the rows at every
/// height the sheet is dragged to and clear of the home indicator.
class SelectListCreateButton extends StatelessWidget {
  /// Creates the button for the picker opened on [video].
  const SelectListCreateButton({required this.video, super.key});

  /// The video the created list starts with.
  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select(
      (SelectListCubit cubit) => cubit.state.isSaving,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DivineButton(
        label: context.l10n.listCreateNewList,
        type: DivineButtonType.secondary,
        leadingIcon: DivineIconName.plus,
        expanded: true,
        onPressed: isSaving
            ? null
            : () => runDetached(
                showListInfoSheet(context, video: video),
                'open list creation sheet',
                logName: 'SelectListSheet',
                category: LogCategory.ui,
              ),
      ),
    );
  }
}
