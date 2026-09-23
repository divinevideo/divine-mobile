// ABOUTME: Bottom sheet listing the text-overlay looks the user saved: apply
// ABOUTME: one to the selected text, save its current look, rename, delete,
// ABOUTME: reorder (#7742).

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/saved_title_styles/saved_title_styles_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/saved_title_style.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/providers/saved_title_style_repository_provider.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/saved_style_name_prompt.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/title_style_preview.dart';

/// One preview loop: the text enters, holds, leaves, then repeats.
const _loopMs = 2400;

const _previewWidth = 96.0;
const _previewHeight = 56.0;

/// Shows the saved title styles sheet for a selected text overlay; resolves
/// with the style to apply, or `null` when dismissed without choosing one.
///
/// [currentStyle] is the overlay's own look, which "Save current style"
/// stores. [sampleText] is its text, so every preview shows what that
/// overlay will look like restyled.
Future<TitleStyle?> showSavedTitleStylesSheet(
  BuildContext context, {
  required TitleStyle currentStyle,
  required String sampleText,
}) {
  return VineBottomSheet.show<TitleStyle>(
    context: context,
    title: Text(
      context.l10n.videoEditorCaptionsSavedStylesTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    buildScrollBody: (scrollController) => SavedTitleStylesSheetPage(
      currentStyle: currentStyle,
      sampleText: sampleText,
      scrollController: scrollController,
    ),
  );
}

/// Wires the sheet to the account's saved styles.
///
/// Re-keyed on the repository so an account switch mid-sheet closes the
/// cubit that was reading the previous account's rows.
class SavedTitleStylesSheetPage extends ConsumerWidget {
  /// Creates the page.
  const SavedTitleStylesSheetPage({
    required this.currentStyle,
    required this.sampleText,
    this.scrollController,
    super.key,
  });

  /// The selected text overlay's current look, offered for saving.
  final TitleStyle currentStyle;

  /// The selected text overlay's text, rendered in every preview.
  final String sampleText;

  /// Sheet-provided controller so drag-to-resize keeps working.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(savedTitleStyleRepositoryProvider);
    return BlocProvider<SavedTitleStylesCubit>(
      key: ValueKey(repository),
      create: (_) {
        final cubit = SavedTitleStylesCubit(repository: repository);
        // Fire-and-forget by design: the load reports its outcome through
        // the cubit's status, and the sheet is already on screen.
        unawaited(cubit.load());
        return cubit;
      },
      child: SavedTitleStylesSheetView(
        currentStyle: currentStyle,
        sampleText: sampleText,
        scrollController: scrollController,
      ),
    );
  }
}

/// The sheet body: the save action and the saved styles — tap to apply, drag
/// to reorder, menu to rename or delete.
@visibleForTesting
class SavedTitleStylesSheetView extends StatefulWidget {
  /// Creates the view.
  const SavedTitleStylesSheetView({
    required this.currentStyle,
    required this.sampleText,
    this.scrollController,
    super.key,
  });

  /// The selected text overlay's current look, offered for saving.
  final TitleStyle currentStyle;

  /// The selected text overlay's text, rendered in every preview.
  final String sampleText;

  /// Sheet-provided controller so drag-to-resize keeps working.
  final ScrollController? scrollController;

  @override
  State<SavedTitleStylesSheetView> createState() =>
      _SavedTitleStylesSheetViewState();
}

class _SavedTitleStylesSheetViewState extends State<SavedTitleStylesSheetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _loopMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = TitleStylePreview.holdValue;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent() async {
    final cubit = context.read<SavedTitleStylesCubit>();
    final style = widget.currentStyle;
    // The font is the most recognisable part of a look, so its name is the
    // suggestion; one tap keeps it, typing replaces it.
    final name = await showSavedStyleNamePrompt(
      context,
      title: context.l10n.videoEditorCaptionsSavedStyleSaveTitle,
      confirmLabel: context.l10n.videoEditorCaptionsSavedStyleSaveAction,
      initialName: style.font.localizedDisplayName(context.l10n),
    );
    if (name == null || !mounted) return;
    await cubit.save(name: name, style: style);
  }

  Future<void> _manage(SavedTitleStyle saved) async {
    final cubit = context.read<SavedTitleStylesCubit>();
    final choice = await _showManageSheet(context, saved);
    if (choice == null || !mounted) return;

    switch (choice) {
      case _ManageChoice.rename:
        final name = await showSavedStyleNamePrompt(
          context,
          title: context.l10n.videoEditorCaptionsSavedStyleRenameTitle,
          confirmLabel: context.l10n.videoEditorCaptionsSavedStyleRenameAction,
          initialName: saved.name,
        );
        if (name == null || !mounted) return;
        await cubit.rename(id: saved.id, name: name);
      case _ManageChoice.delete:
        final confirmed = await _confirmDelete(context, saved);
        if (!confirmed || !mounted) return;
        await cubit.delete(saved.id);
    }
  }

  void _apply(TitleStyle style) => Navigator.of(context).pop(style);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<SavedTitleStylesCubit, SavedTitleStylesState>(
      builder: (context, state) {
        final styles = state.styles;
        return ReorderableListView.builder(
          scrollController: widget.scrollController,
          buildDefaultDragHandles: false,
          padding: EdgeInsets.only(
            bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          header: _SheetHeader(
            status: state.status,
            hasStyles: styles.isNotEmpty,
            onSaveCurrent: _saveCurrent,
            onRetry: context.read<SavedTitleStylesCubit>().load,
          ),
          itemCount: styles.length,
          onReorderItem: context.read<SavedTitleStylesCubit>().reorder,
          itemBuilder: (context, index) {
            final saved = styles[index];
            return _SavedStyleRow(
              key: ValueKey(saved.id),
              saved: saved,
              sampleText: widget.sampleText,
              controller: _controller,
              onTap: () => _apply(saved.style),
              onManage: () => _manage(saved),
              handle: ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: l10n.videoEditorCaptionsSavedStyleReorderSemanticLabel(
                    saved.name,
                  ),
                  // A painted box, so the whole 48dp target takes the pointer
                  // even before the icon asset has decoded.
                  child: ColoredBox(
                    color: VineTheme.transparent,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: DivineIcon(
                          icon: DivineIconName.list,
                          color: context.vineColors.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The save action, and the loading, failure or empty note that stands in
/// for the list while it has no rows to show.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.status,
    required this.hasStyles,
    required this.onSaveCurrent,
    required this.onRetry,
  });

  final SavedTitleStylesStatus status;
  final bool hasStyles;
  final VoidCallback onSaveCurrent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          DivineButton(
            label: l10n.videoEditorCaptionsSavedStylesSaveCurrent,
            leadingIcon: DivineIconName.bookmarkPlus,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: onSaveCurrent,
          ),
          if (!hasStyles)
            switch (status) {
              SavedTitleStylesStatus.initial ||
              SavedTitleStylesStatus.loading => Center(
                child: DivineCircularProgressIndicator(
                  semanticsLabel: l10n.commonLoading,
                ),
              ),
              SavedTitleStylesStatus.ready => Text(
                l10n.videoEditorTitleSavedStylesEmpty,
                style: VineTheme.bodyMediumFont(color: colors.secondaryText),
              ),
              SavedTitleStylesStatus.failure => _LoadFailure(onRetry: onRetry),
            }
          else if (status == SavedTitleStylesStatus.failure)
            _LoadFailure(onRetry: onRetry),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            l10n.videoEditorCaptionsSavedStylesLoadFailed,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
        DivineButton(
          label: l10n.commonRetry,
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// One saved style: the looping preview of [sampleText] in it beside its
/// name, the rename/delete menu, and the drag [handle]. Tapping the row
/// applies it.
class _SavedStyleRow extends StatelessWidget {
  const _SavedStyleRow({
    required this.saved,
    required this.sampleText,
    required this.controller,
    required this.onTap,
    required this.onManage,
    required this.handle,
    super.key,
  });

  final SavedTitleStyle saved;
  final String sampleText;
  final AnimationController controller;
  final VoidCallback onTap;
  final VoidCallback onManage;
  final Widget handle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    // The drag proxy is painted in the overlay, outside the sheet's Material,
    // so the row brings its own for the ink.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            // One button node for the preview and the name; the preview and
            // the visible label are excluded so the name is announced once.
            child: MergeSemantics(
              child: Semantics(
                button: true,
                label: l10n.videoEditorCaptionsSavedStyleApplySemanticLabel(
                  saved.name,
                ),
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ExcludeSemantics(
                            child: TitleStylePreview(
                              style: saved.style,
                              text: sampleText,
                              loop: controller,
                              loopMs: _loopMs,
                              width: _previewWidth,
                              height: _previewHeight,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Text(
                              saved.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: VineTheme.bodyMediumFont(
                                color: colors.primaryText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DivineIconButton(
                  icon: DivineIconName.dotsThreeVertical,
                  type: DivineIconButtonType.ghostSecondary,
                  size: DivineIconButtonSize.small,
                  semanticLabel: l10n
                      .videoEditorCaptionsSavedStyleOptionsSemanticLabel(
                        saved.name,
                      ),
                  onPressed: onManage,
                ),
                handle,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the user picked in a saved style's menu.
enum _ManageChoice { rename, delete }

Future<_ManageChoice?> _showManageSheet(
  BuildContext context,
  SavedTitleStyle saved,
) async {
  _ManageChoice? choice;
  await VineBottomSheetActionMenu.show(
    context: context,
    title: Text(
      saved.name,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    options: [
      VineBottomSheetActionData(
        iconPath: DivineIconName.pencilSimple.assetPath,
        label: context.l10n.videoEditorCaptionsSavedStyleRenameAction,
        onTap: () => choice = _ManageChoice.rename,
      ),
      VineBottomSheetActionData(
        iconPath: DivineIconName.trash.assetPath,
        label: context.l10n.commonDelete,
        isDestructive: true,
        onTap: () => choice = _ManageChoice.delete,
      ),
    ],
  );
  return choice;
}

/// Confirms deleting [saved], spelling out that text already styled with it
/// is unaffected.
Future<bool> _confirmDelete(BuildContext context, SavedTitleStyle saved) async {
  final navigator = Navigator.of(context);
  final confirmed = await VineBottomSheetPrompt.show<bool>(
    context: context,
    sticker: DivineStickerName.alert,
    title: context.l10n.videoEditorCaptionsSavedStyleDeleteConfirmTitle(
      saved.name,
    ),
    subtitle: context.l10n.videoEditorTitleSavedStyleDeleteConfirmMessage,
    primaryButtonText: context.l10n.commonDelete,
    secondaryButtonText: context.l10n.commonCancel,
    onPrimaryPressed: () => navigator.pop(true),
    onSecondaryPressed: () => navigator.pop(false),
  );
  return confirmed ?? false;
}
