// ABOUTME: Drafts tab widget for the clip library screen
// ABOUTME: Lists saved video drafts with options to post, edit, duplicate, delete

import 'dart:async';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/utils/draft_copy_naming.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying a list of saved drafts.
///
/// Uses [DraftsLibraryBloc] for state management and handles draft actions
/// (post, edit, delete) internally.
class DraftsTab extends ConsumerWidget {
  /// Creates a drafts tab.
  const DraftsTab({required this.showRecordButton, super.key});

  final bool showRecordButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocConsumer<DraftsLibraryBloc, DraftsLibraryState>(
      listenWhen: (previous, current) =>
          current is DraftsLibraryDraftDeleted ||
          current is DraftsLibraryDeleteFailed ||
          current is DraftsLibraryDraftDuplicated ||
          current is DraftsLibraryDuplicateFailed,
      listener: (context, state) {
        final label = switch (state) {
          DraftsLibraryDraftDeleted() =>
            context.l10n.libraryDraftDeletedSnackbar,
          DraftsLibraryDeleteFailed() =>
            context.l10n.libraryDraftDeleteFailedSnackbar,
          DraftsLibraryDraftDuplicated() =>
            context.l10n.libraryDraftDuplicatedSnackbar,
          DraftsLibraryDuplicateFailed() =>
            context.l10n.libraryDraftDuplicateFailedSnackbar,
          _ => null,
        };
        if (label == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VineTheme.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(label: label),
          ),
        );
      },
      builder: (context, state) {
        return switch (state) {
          DraftsLibraryInitial() || DraftsLibraryLoading() => Center(
            child: DivineCircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          ),
          DraftsLibraryError() => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.libraryCouldNotLoadDrafts,
                    textAlign: TextAlign.center,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.libraryOpenErrorDescription,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DivineButton(
                    label: context.l10n.searchTryAgain,
                    type: DivineButtonType.secondary,
                    onPressed: () => context.read<DraftsLibraryBloc>().add(
                      const DraftsLibraryLoadRequested(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraftsLibraryLoaded(:final drafts) ||
          DraftsLibraryDraftDuplicated(:final drafts) ||
          DraftsLibraryDuplicateFailed(:final drafts) ||
          DraftsLibraryDraftDeleted(:final drafts) ||
          DraftsLibraryDeleteFailed(:final drafts) => () {
            if (drafts.isEmpty) {
              return EmptyLibraryState(
                showRecordButton: showRecordButton,
                icon: DivineIconName.pencilSimple,
                title: context.l10n.libraryNoDraftsYetTitle,
                subtitle: context.l10n.libraryNoDraftsYetSubtitle,
              );
            }
            return ListView.builder(
              itemCount: drafts.length,
              itemBuilder: (context, index) {
                final draft = drafts[index];
                return DraftListTile(
                  draft: draft,
                  onTap: () => _openDraft(context, ref, draft),
                  onOpenMore: () => _openDraftOptions(context, ref, draft),
                );
              },
            );
          }(),
        };
      },
    );
  }

  Future<void> _openDraftOptions(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    await VineBottomSheetActionMenu.show(
      context: context,
      title: DraftListTile(draft: draft, enableShrink: true),
      options: [
        if (draft.canPost)
          VineBottomSheetActionData(
            iconPath: DivineIconName.paperPlaneTilt.assetPath,
            label: context.l10n.libraryDraftActionPost,
            onTap: () => _postDraft(context, ref, draft),
          ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.pencilSimple.assetPath,
          label: context.l10n.libraryDraftActionEdit,
          onTap: () => _openDraft(context, ref, draft),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.copySimple.assetPath,
          label: context.l10n.libraryDraftActionDuplicate,
          onTap: () => _duplicateDraft(context, draft),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.trash.assetPath,
          label: context.l10n.libraryDraftActionDelete,
          isDestructive: true,
          onTap: () => _deleteDraft(context, ref, draft),
        ),
      ],
    );
  }

  void _duplicateDraft(BuildContext context, DivineVideoDraft draft) {
    Log.info(
      '📚 Duplicate draft: ${draft.id}',
      name: 'DraftsTab',
      category: LogCategory.video,
    );
    // Untitled drafts stay untitled; a titled draft gets a numbered copy
    // suffix that skips titles already taken, so repeated copies read
    // "Trip (copy 1)", "Trip (copy 2)" rather than stacking "(copy) (copy)".
    final trimmedTitle = draft.title.trim();
    final newTitle = trimmedTitle.isEmpty
        ? null
        : nextDuplicateDraftTitle(
            sourceTitle: trimmedTitle,
            existingTitles: _draftTitles(context),
            format: (base, number) =>
                context.l10n.libraryDraftCopyTitle(base, number),
          );
    context.read<DraftsLibraryBloc>().add(
      DraftsLibraryDuplicateRequested(draft.id, newTitle: newTitle),
    );
  }

  Iterable<String> _draftTitles(BuildContext context) {
    final state = context.read<DraftsLibraryBloc>().state;
    return switch (state) {
      DraftsLibraryLoaded(:final drafts) ||
      DraftsLibraryDraftDuplicated(:final drafts) ||
      DraftsLibraryDuplicateFailed(:final drafts) ||
      DraftsLibraryDraftDeleted(:final drafts) ||
      DraftsLibraryDeleteFailed(:final drafts) => drafts.map((d) => d.title),
      _ => const <String>[],
    };
  }

  Future<void> _postDraft(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    Log.info(
      '📚 Post draft: ${draft.id}',
      name: 'DraftsTab',
      category: LogCategory.video,
    );
    await ref.read(videoPublishProvider.notifier).publishVideo(context, draft);

    // Reload so a published draft leaves the list. BackgroundPublishBloc owns
    // that deletion and runs it after its success state, so a reload racing it
    // can still show the draft until the next one.
    if (context.mounted) {
      context.read<DraftsLibraryBloc>().add(const DraftsLibraryLoadRequested());
    }
  }

  Future<void> _openDraft(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    Log.info(
      '📚 Opening draft: ${draft.id}',
      name: 'DraftsTab',
      category: LogCategory.video,
    );

    await ref
        .read(videoPublishProvider.notifier)
        .clearAll(keepAutosavedDraft: true);

    if (!context.mounted) return;

    await context.push(
      VideoEditorScreen.pathFor(draftId: draft.id, fromLibrary: true),
    );

    await ref
        .read(videoPublishProvider.notifier)
        .clearAll(keepAutosavedDraft: true);

    // Reload drafts after returning
    if (context.mounted) {
      context.read<DraftsLibraryBloc>().add(const DraftsLibraryLoadRequested());
    }
  }

  Future<void> _deleteDraft(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.card,
        title: Text(
          context.l10n.libraryDeleteDraftTitle,
          style: VineTheme.titleSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          context.l10n.libraryDeleteDraftMessage(
            draft.title.isEmpty ? context.l10n.draftUntitled : draft.title,
          ),
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.popModalIfMounted(false),
            child: Text(
              context.l10n.commonCancel,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => dialogContext.popModalIfMounted(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.error,
              foregroundColor: VineTheme.whiteText,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Log.info(
        '📚 Deleting draft: ${draft.id}',
        name: 'DraftsTab',
        category: LogCategory.video,
      );
      context.read<DraftsLibraryBloc>().add(
        DraftsLibraryDeleteRequested(draft.id),
      );
      if (draft.id == VideoEditorConstants.autoSaveId) {
        unawaited(
          ref
              .read(videoPublishProvider.notifier)
              .clearAll(keepAutosavedDraft: true),
        );
      }
    }
  }
}

String _formatDraftSubtitle(BuildContext context, DateTime lastModified) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.yMMMEd(locale).format(lastModified);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(lastModified),
    alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
  );
  return '$date $time';
}

/// List tile widget displaying a single draft.
class DraftListTile extends StatelessWidget {
  /// Creates a draft list tile.
  const DraftListTile({
    required this.draft,
    this.onTap,
    this.onOpenMore,
    this.enableShrink = false,
    super.key,
  });

  /// The draft to display.
  final DivineVideoDraft draft;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when more options button is tapped.
  final VoidCallback? onOpenMore;

  /// Whether to enable compact mode for bottom sheet usage.
  final bool enableShrink;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = draft.coverThumbnailPath;
    final isAutosaveDraft = draft.id == VideoEditorConstants.autoSaveId;

    return ListTile(
      onTap: onTap,
      minTileHeight: enableShrink ? null : 72,
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        enableShrink ? 0 : 16,
        0,
        10,
        0,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: ShapeDecoration(
          color: context.vineColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        foregroundDecoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: context.vineColors.disabled),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: thumbnailPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ClipThumbnailImage(
                  path: thumbnailPath,
                  fit: BoxFit.cover,
                  placeholder: DivineIcon(
                    icon: DivineIconName.filmSlate,
                    color: context.vineColors.secondaryText,
                    size: 20,
                  ),
                ),
              )
            : DivineIcon(
                icon: DivineIconName.filmSlate,
                color: context.vineColors.secondaryText,
                size: 20,
              ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              draft.title.isEmpty ? context.l10n.draftUntitled : draft.title,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAutosaveDraft) ...[
            const SizedBox(width: 8),
            _DraftStatusBadge(label: context.l10n.libraryDraftInProgressBadge),
          ],
        ],
      ),
      subtitle: Text(
        _formatDraftSubtitle(context, draft.lastModified),
        style: VineTheme.bodySmallFont(color: context.vineColors.primaryText),
      ),
      trailing: onOpenMore == null
          ? null
          : IconButton(
              onPressed: onOpenMore,
              icon: DivineIcon(
                icon: DivineIconName.dotsThreeVertical,
                color: context.vineColors.onSurface,
                size: 28,
              ),
            ),
    );
  }
}

class _DraftStatusBadge extends StatelessWidget {
  const _DraftStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.vineColors.accentPositive.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: VineTheme.labelSmallFont(
            color: context.vineColors.accentPositive,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
