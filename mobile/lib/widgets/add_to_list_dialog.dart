// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: Selects an existing list and opens the list info sheet to create one

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/curated_list_initialization_failure.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: DivineCircularProgressIndicator(
            strokeWidth: 2,
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting an existing list to add a video to.
class SelectListDialog extends StatefulWidget {
  const SelectListDialog({required this.video, super.key});
  final VideoEvent video;

  @override
  State<SelectListDialog> createState() => _SelectListDialogState();
}

class _SelectListDialogState extends State<SelectListDialog> {
  ListInfoSheetOutcome? _creationOutcome;

  Future<void> _createList() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final failureMessage = l10n.listVideoNotAdded;
    final outcome = await showListInfoSheet(context, video: widget.video);
    if (!mounted) {
      if ((outcome == ListInfoSheetOutcome.createdWithoutVideo ||
              outcome == ListInfoSheetOutcome.createdWithVideoPendingSync) &&
          messenger.mounted) {
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            outcome == ListInfoSheetOutcome.createdWithVideoPendingSync
                ? l10n.listVideoPendingSync
                : failureMessage,
            error: outcome == ListInfoSheetOutcome.createdWithoutVideo,
          ),
        );
      }
      return;
    }
    setState(() {
      _creationOutcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final listServiceAsync = ref.watch(curatedListsStateProvider);

      return listServiceAsync.when(
        data: (lists) {
          final availableLists = lists.toList();

          final l10n = context.l10n;
          return AlertDialog(
            backgroundColor: context.vineColors.card,
            title: Text(
              l10n.listAddToList,
              style: TextStyle(color: context.vineColors.primaryText),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  if (_creationOutcome ==
                      ListInfoSheetOutcome.createdWithoutVideo)
                    ListInfoFailureMessage(l10n.listVideoNotAdded),
                  if (_creationOutcome ==
                      ListInfoSheetOutcome.createdWithVideoPendingSync)
                    ListInfoFailureMessage(l10n.listVideoPendingSync),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableLists.length,
                      itemBuilder: (context, index) {
                        final list = availableLists[index];
                        final isInList = list.videoEventIds.contains(
                          widget.video.id,
                        );

                        return ListTile(
                          leading: DivineIcon(
                            icon: isInList
                                ? DivineIconName.checkCircle
                                : DivineIconName.playlist,
                            color: isInList
                                ? context.vineColors.accentPositive
                                : context.vineColors.primaryText,
                          ),
                          title: Text(
                            list.name,
                            style: TextStyle(
                              color: context.vineColors.primaryText,
                            ),
                          ),
                          subtitle: Text(
                            '${l10n.listVideoCount(list.videoEventIds.length)} • '
                            '${list.isPublic ? l10n.listVisibilityPublic : l10n.listVisibilityPrivate}',
                            style: TextStyle(
                              color: context.vineColors.secondaryText,
                            ),
                          ),
                          trailing: isInList && list.pendingRepublish
                              ? DivineButton(
                                  label: l10n.listRetrySync,
                                  type: DivineButtonType.link,
                                  onPressed: () => runDetached(
                                    ref
                                        .read(
                                          curatedListsStateProvider.notifier,
                                        )
                                        .service!
                                        .retryListSync(list.id),
                                    'retry list sync',
                                    logName: 'SelectListDialog',
                                    category: LogCategory.ui,
                                  ),
                                )
                              : null,
                          onTap: () => _toggleVideoInList(
                            context,
                            ref
                                .read(curatedListsStateProvider.notifier)
                                .service!,
                            list,
                            isInList,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  runDetached(
                    _createList(),
                    'open list creation sheet',
                    logName: 'SelectListDialog',
                    category: LogCategory.ui,
                  );
                },
                child: Text(l10n.listNewList),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.listDone),
              ),
            ],
          );
        },
        loading: () => const _LoadingIndicator(),
        error: (_, _) => AlertDialog(
          backgroundColor: context.vineColors.card,
          title: Text(context.l10n.listAddToList),
          content: CuratedListInitializationFailure(
            onRetry: () => ref.invalidate(curatedListsStateProvider),
          ),
          actions: [
            DivineButton(
              label: context.l10n.listDone,
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _toggleVideoInList(
    BuildContext context,
    CuratedListService listService,
    CuratedList list,
    bool isCurrentlyInList,
  ) async {
    try {
      bool success;
      if (isCurrentlyInList) {
        success = await listService.removeVideoFromList(
          list.id,
          widget.video.id,
        );
      } else {
        success = await listService.addVideoToList(list.id, widget.video.id);
      }

      if (!context.mounted) return;

      if (success) {
        final message = isCurrentlyInList
            ? context.l10n.listRemovedFrom(list.name)
            : context.l10n.listAddedTo(list.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
          ),
        );
        return;
      }

      // A failed toggle used to render nothing at all, so a private list that
      // had reached the NIP-44 size ceiling silently swallowed every add
      // (#7331). Retrying that case can never succeed, so it gets copy that
      // does not ask the user to try again.
      final atSizeLimit =
          !isCurrentlyInList &&
          CuratedListConverter.wouldExceedPrivateItemLimit(
            list,
            widget.video.id,
          );
      final failureMessage = atSizeLimit
          ? context.l10n.listPrivateFull
          : context.l10n.listUpdateFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
      // A failure shown only in a SnackBar is invisible to screen readers.
      // Announce it, matching the DM oversized-send path this PR added (#7331).
      announceDetached(
        context,
        failureMessage,
        description: 'announce list update failure',
        logName: 'SelectListDialog',
      );
    } catch (e) {
      Log.error(
        'Failed to toggle video in list: $e',
        name: 'SelectListDialog',
        category: LogCategory.ui,
      );
    }
  }
}
