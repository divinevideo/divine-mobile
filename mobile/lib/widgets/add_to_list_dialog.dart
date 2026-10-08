// ABOUTME: Dialogs for adding videos to curated lists
// ABOUTME: SelectListDialog and CreateListDialog for curated video lists

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/curated_list_initialization_failure.dart';
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
                  runDetached(
                    showDialog<void>(
                      context: context,
                      builder: (_) => CreateListDialog(video: video),
                    ),
                    'open list creation dialog',
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

/// Dialog for creating a new curated list, optionally adding [video] to it.
///
/// Existing callers retain the dialog presentation; [CreateListDialog.sheet]
/// supplies the same form and save contract inside a [VineBottomSheet]. Both
/// are modal routes, so dismissal uses the owning [Navigator].
class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({this.video, this.existingList, super.key})
    : _isSheet = false;

  /// Creation form for a sanctioned [VineBottomSheet] presentation.
  const CreateListDialog.sheet({this.video, super.key})
    : existingList = null,
      _isSheet = true;

  final VideoEvent? video;
  final CuratedList? existingList;
  final bool _isSheet;

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublic = true;
  String? _saveError;

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
    final title = _isEditing ? l10n.listEditTitle : l10n.listCreateNewList;
    final fields = _CreateListFields(
      nameController: _nameController,
      descriptionController: _descriptionController,
      isPublic: _isPublic,
      onVisibilityChanged: (value) => setState(() => _isPublic = value),
    );
    final actions = [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.listCancel),
      ),
      TextButton(
        onPressed: _saveList,
        child: Text(_isEditing ? l10n.listSave : l10n.listCreate),
      ),
    ];

    if (widget._isSheet) {
      return Material(
        color: context.vineColors.surface,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      fields,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saveError case final message?) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          message,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 8,
                      overflowSpacing: 8,
                      children: actions,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dialogContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        fields,
        if (_saveError case final message?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onErrorContainer,
              ),
            ),
          ),
        ],
      ],
    );
    return AlertDialog(
      backgroundColor: context.vineColors.card,
      title: Text(
        title,
        style: TextStyle(color: context.vineColors.primaryText),
      ),
      content: _isEditing
          ? SingleChildScrollView(child: dialogContent)
          : dialogContent,
      actions: actions,
    );
  }

  Future<void> _saveList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_saveError != null) {
      setState(() => _saveError = null);
    }

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

        final updateFuture = listService.updateListWithResult(
          listId: existingList.id,
          name: name,
          description: _descriptionController.text.trim(),
          isPublic: _isPublic,
        );

        // Visibility changes keep the editor open until relay acceptance.
        if (visibilityChanged) {
          final updated = await updateFuture;
          if (!mounted) return;
          if (updated.succeeded) {
            Navigator.of(context).pop();
          } else {
            _showSaveFailed(
              rejectionMessage:
                  updated.rejection ==
                      CuratedListUpdateRejection.privateListFull
                  ? context.l10n.listPrivateConversionTooLarge
                  : null,
            );
          }
          return;
        }

        // Name and description are already stored locally before the update
        // awaits the relay, so nothing the user typed is riding on the answer.
        // Close now rather than let a slow relay make the save look
        // unresponsive; the messenger and message have to be resolved first
        // because the pop can unmount this State.
        final messenger = ScaffoldMessenger.of(context);
        final failureMessage = context.l10n.listUpdateFailed;
        Navigator.of(context).pop();

        if (!(await updateFuture).succeeded && messenger.mounted) {
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

  /// Keeps sheet and specific rejection feedback visible inside the modal.
  void _showSaveFailed({String? rejectionMessage}) {
    final message =
        rejectionMessage ??
        (_isEditing
            ? context.l10n.listUpdateFailed
            : context.l10n.listCreateFailed);
    if (widget._isSheet || rejectionMessage != null) {
      setState(() => _saveError = message);
      return;
    }
    _showSaveFailedDetached(ScaffoldMessenger.of(context), message);
  }

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

/// Shared fields keep the creation dialog and sheet on one edit contract.
class _CreateListFields extends StatelessWidget {
  const _CreateListFields({
    required this.nameController,
    required this.descriptionController,
    required this.isPublic,
    required this.onVisibilityChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isPublic;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          enableInteractiveSelection: true,
          style: TextStyle(color: context.vineColors.primaryText),
          decoration: InputDecoration(
            labelText: l10n.listNameLabel,
            labelStyle: TextStyle(color: context.vineColors.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descriptionController,
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
            isPublic
                ? l10n.listPublicListSubtitle
                : l10n.listPrivateListSubtitle,
            style: TextStyle(color: context.vineColors.secondaryText),
          ),
          value: isPublic,
          onChanged: onVisibilityChanged,
        ),
      ],
    );
  }
}
