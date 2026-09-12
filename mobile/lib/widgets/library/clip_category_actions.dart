// ABOUTME: Bottom sheets for creating, renaming, and assigning clip categories.
// ABOUTME: Returns the user's choice; dispatching events is the caller's job.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_category.dart';

/// Where the user wants the selected clips filed.
sealed class ClipCategoryMoveChoice {
  const ClipCategoryMoveChoice();
}

/// File the clips under an existing category.
final class ClipCategoryMoveToExisting extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToExisting(this.categoryId);

  /// The target category.
  final String categoryId;
}

/// Take the clips out of whatever category they are in.
final class ClipCategoryMoveToNone extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToNone();
}

/// Create a category first, then file the clips into it.
final class ClipCategoryMoveToNew extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToNew();
}

/// Archive the clips instead of filing them.
final class ClipCategoryMoveToArchive extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToArchive();
}

/// Bring archived clips back into the library's default view.
final class ClipCategoryMoveToUnarchive extends ClipCategoryMoveChoice {
  const ClipCategoryMoveToUnarchive();
}

/// What the user picked in the category management sheet.
enum ClipCategoryManageChoice { rename, delete }

/// What the user answered when asked what archiving should do to the clips'
/// category.
enum ClipArchiveCategoryChoice {
  /// Archive the clips and leave them filed where they are, so they stay
  /// visible under their category.
  keep,

  /// Archive the clips and take them out of their category, leaving the
  /// archive as the only place they show up.
  remove,
}

/// Which archive action the move sheet offers for the current selection.
enum ClipCategoryArchiveOption {
  /// The selection is in the working set and can be archived out of it.
  archive,

  /// The selection is already archived and can be brought back.
  unarchive,
}

/// Bottom sheets backing the library's category management.
///
/// The `run*` flows chain the sheets and dispatch the resulting events, so
/// the chip row's long-press and the toolbar's actions behave identically
/// without either owning a copy of the sequence.
abstract final class ClipCategoryActions {
  /// Asks for a name and creates a category, optionally filing [clipIds]
  /// into it right away.
  static Future<void> runCreateFlow({
    required BuildContext context,
    required ClipsLibraryBloc bloc,
    Set<String> clipIds = const {},
  }) async {
    final name = await showNamePrompt(
      context: context,
      title: context.l10n.libraryCategoryCreateTitle,
      confirmLabel: context.l10n.libraryCategoryCreateAction,
    );
    if (name == null) return;
    bloc.add(ClipsLibraryCategoryCreated(name, clipIds: clipIds));
  }

  /// Runs the rename/delete flow for [category].
  static Future<void> runManageFlow({
    required BuildContext context,
    required ClipsLibraryBloc bloc,
    required ClipCategory category,
  }) async {
    final choice = await showManageSheet(context: context, category: category);
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case ClipCategoryManageChoice.rename:
        final name = await showNamePrompt(
          context: context,
          title: context.l10n.libraryCategoryRenameTitle,
          confirmLabel: context.l10n.libraryCategoryRenameAction,
          initialName: category.name,
        );
        if (name == null) return;
        bloc.add(
          ClipsLibraryCategoryRenamed(categoryId: category.id, name: name),
        );
      case ClipCategoryManageChoice.delete:
        final confirmed = await confirmDelete(
          context: context,
          category: category,
        );
        if (!confirmed) return;
        bloc.add(ClipsLibraryCategoryDeleted(category.id));
    }
  }

  /// Asks where to file [clipIds] and dispatches the move.
  static Future<void> runMoveFlow({
    required BuildContext context,
    required ClipsLibraryBloc bloc,
    required Set<String> clipIds,
  }) async {
    if (clipIds.isEmpty) return;

    final state = bloc.state;
    final selected = [
      for (final clip in state.clips)
        if (clipIds.contains(clip.id)) clip,
    ];
    // Offer the current category as preselected only when the whole
    // selection already shares one; a mixed selection has no current value.
    final currentCategoryIds = {for (final clip in selected) clip.categoryId};
    // Archiving an already-archived clip is a no-op, and the Archive view is
    // otherwise a dead end — there is no other way back out of it.
    final archiveOption =
        selected.isNotEmpty && selected.every((c) => c.archivedAt != null)
        ? ClipCategoryArchiveOption.unarchive
        : ClipCategoryArchiveOption.archive;
    final choice = await showMoveSheet(
      context: context,
      categories: state.categories,
      currentCategoryId: currentCategoryIds.length == 1
          ? currentCategoryIds.first
          : null,
      archiveOption: archiveOption,
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case ClipCategoryMoveToNew():
        await runCreateFlow(context: context, bloc: bloc, clipIds: clipIds);
      case ClipCategoryMoveToArchive():
        // Archiving no longer empties a category, so a filed clip has two
        // plausible destinations and the user picks which one they meant.
        final filedCategoryIds = {
          for (final clip in selected) ?clip.categoryId,
        };
        var clearCategory = false;
        if (filedCategoryIds.isNotEmpty) {
          final categoryChoice = await showArchiveCategoryPrompt(
            context: context,
            categoryCount: filedCategoryIds.length,
            categoryName: filedCategoryIds.length == 1
                ? _categoryName(state.categories, filedCategoryIds.first)
                : null,
          );
          // Dismissing the question cancels the archive rather than picking
          // for the user — either answer moves clips out of a view they are
          // looking at.
          if (categoryChoice == null) return;
          clearCategory = categoryChoice == ClipArchiveCategoryChoice.remove;
        }
        bloc.add(
          ClipsLibraryClipsArchiveChanged(
            clipIds: clipIds,
            archived: true,
            clearCategory: clearCategory,
          ),
        );
      case ClipCategoryMoveToUnarchive():
        bloc.add(
          ClipsLibraryClipsArchiveChanged(clipIds: clipIds, archived: false),
        );
      case ClipCategoryMoveToNone():
        bloc.add(
          ClipsLibraryClipsMovedToCategory(clipIds: clipIds, categoryId: null),
        );
      case ClipCategoryMoveToExisting(:final categoryId):
        bloc.add(
          ClipsLibraryClipsMovedToCategory(
            clipIds: clipIds,
            categoryId: categoryId,
          ),
        );
    }
  }

  /// Name of the category [categoryId], or `null` when it no longer exists.
  static String? _categoryName(
    List<ClipCategory> categories,
    String categoryId,
  ) {
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return null;
  }

  /// Asks whether archiving should leave the clips filed under their
  /// category or take them out of it.
  ///
  /// [categoryCount] is how many distinct categories the selection spans,
  /// not how many clips it holds: the sheet asks about the destination, and
  /// three clips filed under one category are still one category to keep
  /// them in. [categoryName] names that category when there is only one;
  /// pass `null` for a selection spanning several, which drops the name
  /// from the wording.
  ///
  /// Returns null when the sheet is dismissed without an answer.
  static Future<ClipArchiveCategoryChoice?> showArchiveCategoryPrompt({
    required BuildContext context,
    required int categoryCount,
    String? categoryName,
  }) async {
    final l10n = context.l10n;
    ClipArchiveCategoryChoice? choice;
    await VineBottomSheetActionMenu.show(
      context: context,
      title: Text(
        l10n.libraryArchiveKeepCategoryTitle(categoryCount),
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.folderOpen.assetPath,
          label: categoryName == null
              ? l10n.libraryArchiveKeepCategoryActionMixed
              : l10n.libraryArchiveKeepCategoryAction(categoryName),
          onTap: () => choice = ClipArchiveCategoryChoice.keep,
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.prohibit.assetPath,
          label: categoryName == null
              ? l10n.libraryArchiveRemoveCategoryActionMixed
              : l10n.libraryArchiveRemoveCategoryAction(categoryName),
          onTap: () => choice = ClipArchiveCategoryChoice.remove,
        ),
      ],
    );
    return choice;
  }

  /// Sentinel option values for the move sheet. Category ids are UUIDs, so
  /// these cannot collide with a real one.
  static const _noneValue = '__no_category__';
  static const _newValue = '__new_category__';
  static const _archiveValue = '__archive__';
  static const _unarchiveValue = '__unarchive__';

  /// Asks where to file the selected clips.
  ///
  /// [archiveOption] decides which of the two archive actions the sheet
  /// offers; a selection that is already archived gets the way back out
  /// rather than a no-op re-archive.
  ///
  /// Returns null when the sheet is dismissed without a choice.
  static Future<ClipCategoryMoveChoice?> showMoveSheet({
    required BuildContext context,
    required List<ClipCategory> categories,
    String? currentCategoryId,
    ClipCategoryArchiveOption archiveOption = ClipCategoryArchiveOption.archive,
  }) async {
    final l10n = context.l10n;
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      title: Text(
        l10n.libraryCategoryMoveTitle,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      selectedValue: currentCategoryId ?? _noneValue,
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.libraryCategoryMoveNone,
          value: _noneValue,
          leadingIcon: DivineIconName.prohibit,
        ),
        for (final category in categories)
          VineBottomSheetSelectionOptionData(
            label: category.name,
            value: category.id,
            leadingIcon: DivineIconName.folderOpen,
          ),
        VineBottomSheetSelectionOptionData(
          label: l10n.libraryCategoryMoveNewCategory,
          value: _newValue,
          leadingIcon: DivineIconName.plus,
        ),
        switch (archiveOption) {
          ClipCategoryArchiveOption.archive =>
            VineBottomSheetSelectionOptionData(
              label: l10n.libraryArchiveAction,
              value: _archiveValue,
              leadingIcon: DivineIconName.stackSimple,
            ),
          ClipCategoryArchiveOption.unarchive =>
            VineBottomSheetSelectionOptionData(
              label: l10n.libraryUnarchiveAction,
              value: _unarchiveValue,
              leadingIcon: DivineIconName.stackSimple,
            ),
        },
      ],
    );

    return switch (selected) {
      null => null,
      _noneValue => const ClipCategoryMoveToNone(),
      _newValue => const ClipCategoryMoveToNew(),
      _archiveValue => const ClipCategoryMoveToArchive(),
      _unarchiveValue => const ClipCategoryMoveToUnarchive(),
      final String id => ClipCategoryMoveToExisting(id),
    };
  }

  /// Asks whether to rename or delete [category].
  ///
  /// Returns null when the sheet is dismissed without a choice.
  static Future<ClipCategoryManageChoice?> showManageSheet({
    required BuildContext context,
    required ClipCategory category,
  }) async {
    ClipCategoryManageChoice? choice;
    await VineBottomSheetActionMenu.show(
      context: context,
      title: Text(
        category.name,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.pencilSimple.assetPath,
          label: context.l10n.libraryCategoryRenameAction,
          onTap: () => choice = ClipCategoryManageChoice.rename,
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.trash.assetPath,
          label: context.l10n.libraryCategoryDeleteAction,
          isDestructive: true,
          onTap: () => choice = ClipCategoryManageChoice.delete,
        ),
      ],
    );
    return choice;
  }

  /// Asks for a category name.
  ///
  /// Returns the entered text, or null when the sheet is dismissed. The
  /// caller still passes the text through [ClipCategory.sanitizeName] via the
  /// bloc, which rejects blank input.
  static Future<String?> showNamePrompt({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    String? initialName,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      expanded: false,
      isScrollControlled: true,
      title: Text(
        title,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      body: _CategoryNameForm(
        confirmLabel: confirmLabel,
        initialName: initialName,
      ),
    );
  }

  /// Confirms deleting [category], spelling out that its clips survive.
  static Future<bool> confirmDelete({
    required BuildContext context,
    required ClipCategory category,
  }) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryCategoryDeleteConfirmTitle(category.name),
      subtitle: context.l10n.libraryCategoryDeleteConfirmMessage,
      primaryButtonText: context.l10n.commonDelete,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    return confirmed ?? false;
  }
}

class _CategoryNameForm extends StatefulWidget {
  const _CategoryNameForm({required this.confirmLabel, this.initialName});

  final String confirmLabel;
  final String? initialName;

  @override
  State<_CategoryNameForm> createState() => _CategoryNameFormState();
}

class _CategoryNameFormState extends State<_CategoryNameForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (ClipCategory.sanitizeName(value) == null) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return VineKeyboardAwareFooter(
      includeSafeArea: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            DivineTextField(
              key: const Key('clip_category_name_field'),
              controller: _controller,
              labelText: context.l10n.libraryCategoryNameLabel,
              // Sits directly on the sheet surface, so it needs its own fill
              // to have a visible edge at all.
              filled: true,
              primaryWhenFilled: true,
              autofocus: true,
              maxLength: ClipCategory.maxNameLength,
              textInputAction: TextInputAction.done,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              onSubmitted: _submit,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSubmit = ClipCategory.sanitizeName(value.text) != null;
                return DivineButton(
                  expanded: true,
                  label: widget.confirmLabel,
                  onPressed: canSubmit ? () => _submit(value.text) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
