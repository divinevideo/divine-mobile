// ABOUTME: Bottom sheet listing the caption styles the user saved: apply one,
// ABOUTME: save the current custom style, rename, delete, reorder (#7742).

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/saved_caption_styles/saved_caption_styles_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_caption_style.dart';
import 'package:openvine/providers/saved_caption_style_repository_provider.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/caption_style_preview.dart';

/// One preview loop: cue A enters/holds/leaves, then cue B, then repeat —
/// the same loop the preset grid runs.
const _loopMs = 3200;

const _previewWidth = 96.0;
const _previewHeight = 56.0;

/// Shows the saved caption styles sheet; resolves with the style to apply,
/// or `null` when dismissed without choosing one.
///
/// [currentCustomStyle] is what "Save current style" stores. When the track
/// is on a built-in preset there is nothing to save, so the action is
/// hidden and the sheet only offers the styles already saved.
Future<CaptionCustomStyle?> showSavedCaptionStylesSheet(
  BuildContext context, {
  CaptionCustomStyle? currentCustomStyle,
}) {
  return VineBottomSheet.show<CaptionCustomStyle>(
    context: context,
    title: Text(
      context.l10n.videoEditorCaptionsSavedStylesTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    buildScrollBody: (scrollController) => SavedCaptionStylesSheetPage(
      currentCustomStyle: currentCustomStyle,
      scrollController: scrollController,
    ),
  );
}

/// Wires the sheet to the account's saved styles.
///
/// Re-keyed on the repository so an account switch mid-sheet closes the
/// cubit that was reading the previous account's rows.
class SavedCaptionStylesSheetPage extends ConsumerWidget {
  /// Creates the page.
  const SavedCaptionStylesSheetPage({
    this.currentCustomStyle,
    this.scrollController,
    super.key,
  });

  /// The caption track's current custom style, offered for saving.
  final CaptionCustomStyle? currentCustomStyle;

  /// Sheet-provided controller so drag-to-resize keeps working.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(savedCaptionStyleRepositoryProvider);
    return BlocProvider<SavedCaptionStylesCubit>(
      key: ValueKey(repository),
      create: (_) {
        final cubit = SavedCaptionStylesCubit(repository: repository);
        // Fire-and-forget by design: the load reports its outcome through
        // the cubit's status, and the sheet is already on screen.
        unawaited(cubit.load());
        return cubit;
      },
      child: SavedCaptionStylesSheetView(
        currentCustomStyle: currentCustomStyle,
        scrollController: scrollController,
      ),
    );
  }
}

/// The sheet body: the save action (when there is a custom style to save)
/// and the saved styles — tap to apply, drag to reorder, menu to rename or
/// delete.
@visibleForTesting
class SavedCaptionStylesSheetView extends StatefulWidget {
  /// Creates the view.
  const SavedCaptionStylesSheetView({
    this.currentCustomStyle,
    this.scrollController,
    super.key,
  });

  /// The caption track's current custom style, offered for saving.
  final CaptionCustomStyle? currentCustomStyle;

  /// Sheet-provided controller so drag-to-resize keeps working.
  final ScrollController? scrollController;

  @override
  State<SavedCaptionStylesSheetView> createState() =>
      _SavedCaptionStylesSheetViewState();
}

class _SavedCaptionStylesSheetViewState
    extends State<SavedCaptionStylesSheetView>
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
      // Midway through the first cue is its fully visible hold frame, the
      // same frame the preset grid freezes on.
      _controller.value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent(CaptionCustomStyle style) async {
    final cubit = context.read<SavedCaptionStylesCubit>();
    // The font is the most recognisable part of a look, so its name is the
    // suggestion; one tap keeps it, typing replaces it.
    final name = await showCaptionStyleNamePrompt(
      context,
      title: context.l10n.videoEditorCaptionsSavedStyleSaveTitle,
      confirmLabel: context.l10n.videoEditorCaptionsSavedStyleSaveAction,
      initialName: style.font.localizedDisplayName(context.l10n),
    );
    if (name == null || !mounted) return;
    await cubit.save(name: name, style: style);
  }

  Future<void> _manage(SavedCaptionStyle saved) async {
    final cubit = context.read<SavedCaptionStylesCubit>();
    final choice = await _showManageSheet(context, saved);
    if (choice == null || !mounted) return;

    switch (choice) {
      case _ManageChoice.rename:
        final name = await showCaptionStyleNamePrompt(
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

  void _apply(CaptionCustomStyle style) => Navigator.of(context).pop(style);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = widget.currentCustomStyle;
    return BlocBuilder<SavedCaptionStylesCubit, SavedCaptionStylesState>(
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
            onSaveCurrent: current == null ? null : () => _saveCurrent(current),
            onRetry: context.read<SavedCaptionStylesCubit>().load,
          ),
          itemCount: styles.length,
          onReorderItem: context.read<SavedCaptionStylesCubit>().reorder,
          itemBuilder: (context, index) {
            final saved = styles[index];
            return _SavedStyleRow(
              key: ValueKey(saved.id),
              saved: saved,
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

  final SavedCaptionStylesStatus status;
  final bool hasStyles;

  /// Saves the current custom style; `null` hides the action because the
  /// track is on a built-in preset and there is nothing custom to save.
  final VoidCallback? onSaveCurrent;
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
          if (onSaveCurrent case final onSaveCurrent?)
            DivineButton(
              label: l10n.videoEditorCaptionsSavedStylesSaveCurrent,
              leadingIcon: DivineIconName.bookmarkPlus,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: onSaveCurrent,
            ),
          if (!hasStyles)
            switch (status) {
              SavedCaptionStylesStatus.initial ||
              SavedCaptionStylesStatus.loading => Center(
                child: DivineCircularProgressIndicator(
                  semanticsLabel: l10n.commonLoading,
                ),
              ),
              SavedCaptionStylesStatus.ready => Text(
                l10n.videoEditorCaptionsSavedStylesEmpty,
                style: VineTheme.bodyMediumFont(color: colors.secondaryText),
              ),
              SavedCaptionStylesStatus.failure => _LoadFailure(
                onRetry: onRetry,
              ),
            }
          else if (status == SavedCaptionStylesStatus.failure)
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

/// One saved style: the looping caption preview beside its name, the
/// rename/delete menu, and the drag [handle]. Tapping the row applies it.
class _SavedStyleRow extends StatelessWidget {
  const _SavedStyleRow({
    required this.saved,
    required this.controller,
    required this.onTap,
    required this.onManage,
    required this.handle,
    super.key,
  });

  final SavedCaptionStyle saved;
  final AnimationController controller;
  final VoidCallback onTap;
  final VoidCallback onManage;
  final Widget handle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final style = saved.style.resolve();
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
                            child: AnimatedBuilder(
                              animation: controller,
                              builder: (context, _) => CaptionStylePreview(
                                style: style,
                                loopValue: controller.value,
                                loopMs: _loopMs,
                                width: _previewWidth,
                                height: _previewHeight,
                                fontSizeFactor: 0.5,
                              ),
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
  SavedCaptionStyle saved,
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

/// Asks for a style name; resolves with the entered text, or `null` when the
/// prompt is dismissed. The cubit still sanitizes it.
///
/// Shared with the custom style editor, whose "Save style" action asks the
/// same question.
Future<String?> showCaptionStyleNamePrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String initialName,
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
    body: _StyleNameForm(confirmLabel: confirmLabel, initialName: initialName),
  );
}

/// Confirms deleting [saved], spelling out that styled captions are
/// unaffected.
Future<bool> _confirmDelete(
  BuildContext context,
  SavedCaptionStyle saved,
) async {
  final confirmed = await VineBottomSheetPrompt.show<bool>(
    context: context,
    sticker: DivineStickerName.alert,
    title: context.l10n.videoEditorCaptionsSavedStyleDeleteConfirmTitle(
      saved.name,
    ),
    subtitle: context.l10n.videoEditorCaptionsSavedStyleDeleteConfirmMessage,
    primaryButtonText: context.l10n.commonDelete,
    secondaryButtonText: context.l10n.commonCancel,
    onPrimaryPressed: () => Navigator.of(context).pop(true),
    onSecondaryPressed: () => Navigator.of(context).pop(false),
  );
  return confirmed ?? false;
}

class _StyleNameForm extends StatefulWidget {
  const _StyleNameForm({required this.confirmLabel, required this.initialName});

  final String confirmLabel;
  final String initialName;

  @override
  State<_StyleNameForm> createState() => _StyleNameFormState();
}

class _StyleNameFormState extends State<_StyleNameForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Pre-selected so the suggested name is one keystroke from replaced, and
    // one tap on the button from kept.
    _controller = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (SavedCaptionStyle.sanitizeName(value) == null) return;
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
              key: const Key('saved_caption_style_name_field'),
              controller: _controller,
              labelText: context.l10n.videoEditorCaptionsSavedStyleNameLabel,
              // Sits directly on the sheet surface, so it needs its own fill
              // to have a visible edge at all.
              filled: true,
              primaryWhenFilled: true,
              autofocus: true,
              maxLength: SavedCaptionStyle.maxNameLength,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              onSubmitted: _submit,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSubmit =
                    SavedCaptionStyle.sanitizeName(value.text) != null;
                return DivineButton(
                  expanded: true,
                  label: widget.confirmLabel,
                  onPressed: canSubmit ? () => _submit(_controller.text) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
