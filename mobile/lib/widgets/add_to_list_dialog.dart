// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: SelectListDialog and CreateListDialog for curated video lists

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
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
class SelectListDialog extends StatelessWidget {
  const SelectListDialog({required this.video, super.key});
  final VideoEvent video;

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
              child: ListView.builder(
                itemCount: availableLists.length,
                itemBuilder: (context, index) {
                  final list = availableLists[index];
                  final isInList = list.videoEventIds.contains(video.id);

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
                      style: TextStyle(color: context.vineColors.primaryText),
                    ),
                    subtitle: Text(
                      '${l10n.listVideoCount(list.videoEventIds.length)} • '
                      '${list.isPublic ? l10n.listVisibilityPublic : l10n.listVisibilityPrivate}',
                      style: TextStyle(color: context.vineColors.secondaryText),
                    ),
                    onTap: () => _toggleVideoInList(
                      context,
                      ref.read(curatedListsStateProvider.notifier).service!,
                      list,
                      isInList,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => CreateListDialog(video: video),
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
        error: (_, _) => Center(child: Text(context.l10n.listErrorLoading)),
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
        success = await listService.removeVideoFromList(list.id, video.id);
      } else {
        success = await listService.addVideoToList(list.id, video.id);
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
          CuratedListConverter.wouldExceedPrivateItemLimit(list, video.id);
      final failureMessage = atSizeLimit
          ? context.l10n.listPrivateFull
          : context.l10n.listUpdateFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
      // A failure shown only in a SnackBar is invisible to screen readers.
      // Announce it, matching the DM oversized-send path this PR added (#7331).
      SemanticsService.sendAnnouncement(
        View.of(context),
        failureMessage,
        Directionality.of(context),
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

/// Dialog for creating a new curated list, optionally adding [video] to it.
///
/// Like [SelectListDialog] this is always presented with `showDialog` and is
/// never registered as a `go_router` route, so every dismissal here goes
/// through [Navigator] — the navigator that owns the dialog route — rather
/// than `context.pop`.
class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({this.video, this.existingList, super.key});
  final VideoEvent? video;
  final CuratedList? existingList;

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublic = true;

  bool get _isEditing => widget.existingList != null;

  @override
  void initState() {
    super.initState();
    final list = widget.existingList;
    if (list == null) return;
    _nameController.text = list.name;
    _descriptionController.text = list.description ?? '';
    _isPublic = list.isPublic;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.vineColors.card,
      title: Text(
        _isEditing ? l10n.listEditTitle : l10n.listCreateNewList,
        style: TextStyle(color: context.vineColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enableInteractiveSelection: true,
            style: TextStyle(color: context.vineColors.primaryText),
            decoration: InputDecoration(
              labelText: l10n.listNameLabel,
              labelStyle: TextStyle(color: context.vineColors.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            enableInteractiveSelection: true,
            style: TextStyle(color: context.vineColors.primaryText),
            decoration: InputDecoration(
              labelText: l10n.listDescriptionLabel,
              labelStyle: TextStyle(color: context.vineColors.secondaryText),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              l10n.listPublicList,
              style: TextStyle(color: context.vineColors.primaryText),
            ),
            subtitle: Text(
              _isPublic
                  ? l10n.listPublicListSubtitle
                  : l10n.listPrivateListSubtitle,
              style: TextStyle(color: context.vineColors.secondaryText),
            ),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.listCancel),
        ),
        TextButton(
          onPressed: _saveList,
          child: Text(_isEditing ? l10n.listSave : l10n.listCreate),
        ),
      ],
    );
  }

  Future<void> _saveList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final listService = ref.read(curatedListsStateProvider.notifier).service;
      final existingList = widget.existingList;
      if (existingList != null) {
        final visibilityChanged = existingList.isPublic != _isPublic;
        if (visibilityChanged &&
            !await _confirmVisibilityChange(existingList.isPublic)) {
          return;
        }
        if (!mounted) return;
        if (listService == null) {
          _showSaveFailed();
          return;
        }

        final updateFuture = listService.updateList(
          listId: existingList.id,
          name: name,
          description: _descriptionController.text.trim(),
          isPublic: _isPublic,
        );

        // Visibility is the one field updateList holds back until a relay
        // accepts the change, so a rejection means the switch the user flipped
        // did not take. Wait for the answer and keep the editor open on
        // failure, so that flip survives a retry.
        if (visibilityChanged) {
          final updated = await updateFuture;
          if (!mounted) return;
          if (updated) {
            Navigator.of(context).pop();
          } else {
            _showSaveFailed();
          }
          return;
        }

        // Name and description are already stored locally before updateList
        // awaits the relay, so nothing the user typed is riding on the answer.
        // Close now rather than let a slow relay make the save look
        // unresponsive; the messenger and message have to be resolved first
        // because the pop can unmount this State.
        final messenger = ScaffoldMessenger.of(context);
        final failureMessage = context.l10n.listUpdateFailed;
        Navigator.of(context).pop();

        if (!await updateFuture && messenger.mounted) {
          _showSaveFailedDetached(messenger, failureMessage);
        }
        return;
      }

      // The generated ID is only known once createList returns, so the create
      // path cannot dismiss early the way the edit path does.
      final newList = await listService?.createList(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
      );

      if (!mounted) return;

      // createList catches its own exceptions and returns null; without
      // feedback here the dialog used to sit open doing nothing.
      if (newList == null) {
        _showSaveFailed();
        return;
      }

      final video = widget.video;
      if (video != null) {
        await listService?.addVideoToList(newList.id, video.id);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Log.error(
        'Failed to create list: $e',
        name: 'CreateListDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        _showSaveFailed();
      }
    }
  }

  Future<bool> _confirmVisibilityChange(bool wasPublic) async {
    final confirmed = await context.showVideoPausingDialog<bool>(
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.card,
        title: Text(
          wasPublic
              ? context.l10n.listMakePrivateTitle
              : context.l10n.listMakePublicTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          wasPublic
              ? context.l10n.listMakePrivateWarning
              : context.l10n.listMakePublicWarning,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        actions: [
          DivineButton(
            label: context.l10n.commonCancel,
            type: DivineButtonType.link,
            onPressed: () => dialogContext.popModalIfMounted(false),
          ),
          DivineButton(
            label: context.l10n.listContinue,
            type: DivineButtonType.link,
            onPressed: () => dialogContext.popModalIfMounted(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Reports a failure while this dialog is still on screen.
  void _showSaveFailed() => _showSaveFailedDetached(
    ScaffoldMessenger.of(context),
    _isEditing ? context.l10n.listUpdateFailed : context.l10n.listCreateFailed,
  );

  /// Reports a failure once the dialog may already be gone.
  ///
  /// Both arguments must be resolved before the async gap: after the pop this
  /// State can be unmounted, so neither the messenger nor the message can be
  /// recovered from [context].
  void _showSaveFailedDetached(
    ScaffoldMessengerState messenger,
    String message,
  ) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
