// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: Selects an existing list and opens the list info sheet to create one

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curated_list_editor_session_provider.dart';
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
class SelectListDialog extends ConsumerStatefulWidget {
  const SelectListDialog({required this.video, super.key});
  final VideoEvent video;

  @override
  ConsumerState<SelectListDialog> createState() => _SelectListDialogState();
}

class _SelectListDialogState extends ConsumerState<SelectListDialog> {
  ListInfoSheetOutcome? _creationOutcome;
  final _syncingListIds = <String>{};
  final _failedSyncListIds = <String>{};
  late final CuratedListEditorSession _session;
  late final String? _openingOwner;

  @override
  void initState() {
    super.initState();
    _session = ref.read(curatedListEditorSessionProvider);
    _openingOwner = _session.currentOwnerPubkey;
  }

  bool get _isSessionCurrent =>
      _openingOwner != null &&
      _openingOwner.isNotEmpty &&
      _session.currentOwnerPubkey == _openingOwner;

  Future<void> _createList() async {
    if (!_isSessionCurrent) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final failureMessage = l10n.listVideoNotAdded;
    final outcome = await showListInfoSheet(context, video: widget.video);
    if (!_isSessionCurrent) return;
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
  Widget build(BuildContext context) {
    final listServiceAsync = ref.watch(curatedListsStateProvider);

    return listServiceAsync.when(
      data: (lists) {
        final availableLists = lists.toList();

        final l10n = context.l10n;
        final pendingLists = {
          for (final list in availableLists)
            if (list.hasPendingPermissionRecovery ||
                list.pendingPlaintextEventIds.isNotEmpty ||
                (list.pendingRepublish &&
                    list.videoEventIds.contains(widget.video.id)))
              list.id,
        };
        final syncFailed = availableLists.any(
          (list) =>
              _failedSyncListIds.contains(list.id) &&
              pendingLists.contains(list.id) &&
              !list.hasPendingPermissionRecovery,
        );
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
                if (availableLists.any(
                  (list) =>
                      list.hasPendingPermissionRecovery ||
                      list.pendingPlaintextEventIds.isNotEmpty,
                ))
                  ListInfoRecoveryPendingMessage(
                    permissionRecoveryPending: availableLists.any(
                      (list) => list.hasPendingPermissionRecovery,
                    ),
                  )
                else if (pendingLists.isNotEmpty)
                  const ListInfoPendingSyncMessage(),
                if (syncFailed) ListInfoFailureMessage(l10n.listUpdateFailed),
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
                          '${list.publicationTarget.isPublic ? l10n.listVisibilityPublic : l10n.listVisibilityPrivate}',
                          style: TextStyle(
                            color: context.vineColors.secondaryText,
                          ),
                        ),
                        trailing: pendingLists.contains(list.id)
                            ? _syncingListIds.contains(list.id)
                                  ? const SizedBox(
                                      width: 40,
                                      child: _LoadingIndicator(),
                                    )
                                  : DivineButton(
                                      label: l10n.listRetrySync,
                                      type: DivineButtonType.link,
                                      onPressed: () => runDetached(
                                        _retrySync(list),
                                        'retry list sync',
                                        logName: 'SelectListDialog',
                                        category: LogCategory.ui,
                                      ),
                                    )
                            : null,
                        onTap:
                            _syncingListIds.contains(list.id) ||
                                list.hasPendingPermissionRecovery
                            ? null
                            : () => _toggleVideoInList(
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
  }

  Future<void> _retrySync(CuratedList list) async {
    if (!_isSessionCurrent || _syncingListIds.contains(list.id)) return;
    final service = ref.read(curatedListsStateProvider.notifier).service;
    if (service == null) return;
    setState(() {
      _syncingListIds.add(list.id);
      _failedSyncListIds.remove(list.id);
    });
    var synced = false;
    try {
      synced = await service.retryListSync(list.id);
    } catch (error, stackTrace) {
      Log.error(
        'Could not confirm list sync',
        name: 'SelectListDialog',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted || !_isSessionCurrent) return;
    setState(() {
      _syncingListIds.remove(list.id);
      if (!synced) _failedSyncListIds.add(list.id);
    });
  }

  Future<void> _toggleVideoInList(
    BuildContext context,
    CuratedListService listService,
    CuratedList list,
    bool isCurrentlyInList,
  ) async {
    if (!_isSessionCurrent) return;
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

      if (!context.mounted || !_isSessionCurrent) return;

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
