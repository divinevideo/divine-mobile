// ABOUTME: Bottom-sheet widget for searching and managing video hashtags
// ABOUTME: Matches the UserPickerSheet pattern: rounded search field + list rows

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/tags_picker/tags_picker_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Opens the tags picker as a full-screen modal bottom sheet.
///
/// Returns the updated [Set<String>] of tags, or `null` if dismissed.
Future<Set<String>?> showVideoMetadataTagsSelector(
  BuildContext context, {
  required Set<String> initialTags,
}) {
  return VineBottomSheet.show<Set<String>>(
    context: context,
    initialChildSize: 1,
    maxChildSize: 1,
    minChildSize: VineTheme.bottomSheetDismissFloor,
    showDragHandle: false,
    showHeader: false,
    buildScrollBody: (scrollController) => _TagsPickerSheet(
      initialTags: initialTags,
      scrollController: scrollController,
    ),
  );
}

/// Tile widget that shows the current tags and opens the picker sheet on tap.
class VideoMetadataTagsSelector extends ConsumerWidget {
  /// Creates a video metadata tags selector.
  const VideoMetadataTagsSelector({super.key});

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final current = ref.read(videoEditorProvider.select((s) => s.tags));

    final result = await showVideoMetadataTagsSelector(
      context,
      initialTags: current,
    );

    if (result != null && context.mounted) {
      ref.read(videoEditorProvider.notifier).updateMetadata(tags: result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(videoEditorProvider.select((s) => s.tags));

    return VideoMetadataSelectionTile(
      onTap: () => _openSheet(context, ref),
      semanticsLabel: context.l10n.videoMetadataTagsLabel,
      labelText: context.l10n.videoMetadataTagsLabel,
      value: tags.isEmpty ? '' : tags.join(', '),
    );
  }
}

// ─── Sheet ─────────────────────────────────────────────────────────────────

class _TagsPickerSheet extends ConsumerWidget {
  const _TagsPickerSheet({required this.initialTags, this.scrollController});

  final Set<String> initialTags;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the repo so the bloc is recreated if Riverpod ever rebuilds the
    // provider (auth flip, account switch). See state_management.md →
    // "Bridging Riverpod-provided dependencies into BlocProvider".
    final hashtagRepository = ref.watch(hashtagRepositoryProvider);
    return BlocProvider<TagsPickerBloc>(
      key: ValueKey(hashtagRepository),
      create: (_) => TagsPickerBloc(
        hashtagRepository: hashtagRepository,
        initialTags: initialTags,
      ),
      child: _TagsPickerView(scrollController: scrollController),
    );
  }
}

class _TagsPickerView extends StatefulWidget {
  const _TagsPickerView({this.scrollController});

  final ScrollController? scrollController;

  @override
  State<_TagsPickerView> createState() => _TagsPickerViewState();
}

class _TagsPickerViewState extends State<_TagsPickerView> {
  final _searchController = TextEditingController();
  String _previousText = '';
  bool _suppressNextEmptyChange = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    if (_suppressNextEmptyChange && text.isEmpty) {
      _suppressNextEmptyChange = false;
      _previousText = '';
      return;
    }
    _suppressNextEmptyChange = false;
    final previous = _previousText;

    final parsed = parseTagsPickerInput(text: text, previousText: previous);

    // No committable tokens. Two sub-cases:
    //   1. No separator at all (typical typing) — forward as search query.
    //   2. Separator(s) but only empty tokens (e.g. ' ' or ',,,') — clear
    //      the field so we don't leave separator junk visible underneath
    //      an empty-state pane.
    if (parsed.completed.isEmpty) {
      if (parsed.remainder != text) {
        _previousText = parsed.remainder;
        _searchController.value = TextEditingValue(
          text: parsed.remainder,
          selection: TextSelection.collapsed(offset: parsed.remainder.length),
        );
        return;
      }
      _previousText = text;
      context.read<TagsPickerBloc>().add(TagsPickerQueryChanged(text));
      return;
    }

    context.read<TagsPickerBloc>().add(TagsPickerTagsAdded(parsed.completed));
    _previousText = parsed.remainder;
    _searchController.value = TextEditingValue(
      text: parsed.remainder,
      selection: TextSelection.collapsed(offset: parsed.remainder.length),
    );
    // Listener re-fires with the cleaned text. The cleaned text never
    // contains a separator, so the re-entry hits the `completed.isEmpty`
    // branch above and dispatches at most one `TagsPickerQueryChanged` —
    // no unbounded recursion.
  }

  void _addTag(String raw) {
    context.read<TagsPickerBloc>().add(TagsPickerTagsAdded([raw]));
    context.read<TagsPickerBloc>().add(const TagsPickerSearchCleared());
    _previousText = '';
    _searchController.clear();
  }

  void _addSuggestionTag(String raw) {
    context.read<TagsPickerBloc>().add(TagsPickerSuggestionSelected(raw));
    _previousText = '';
    _suppressNextEmptyChange = true;
    _searchController.clear();
  }

  void _removeTag(String tag) {
    context.read<TagsPickerBloc>().add(TagsPickerTagRemoved(tag));
  }

  static const _searchInputBorderRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    final hintText = context.l10n.videoMetadataTagsPickerSearchHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VineBottomSheetHeader(
          showDivider: false,
          leadingAction: DivineIconButton(
            icon: .x,
            type: .secondary,
            size: .small,
            semanticLabel:
                context.l10n.videoMetadataTagsPickerCancelSemanticLabel,
            onPressed: context.pop,
          ),
          title: Text(
            context.l10n.videoMetadataTags,
            style: VineTheme.titleMediumFont(color: context.vineColors.onNav),
          ),
          trailingAction: DivineIconButton(
            icon: .check,
            size: .small,
            semanticLabel:
                context.l10n.videoMetadataTagsPickerConfirmSemanticLabel,
            onPressed: () => context.pop(
              Set<String>.unmodifiable(
                context.read<TagsPickerBloc>().state.selectedTags,
              ),
            ),
          ),
        ),

        // Search field — same style as UserPickerSheet
        Semantics(
          textField: true,
          label: hintText,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(_searchInputBorderRadius),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.done,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9 ,]')),
              ],
              onSubmitted: _addTag,
              cursorColor: context.vineColors.accentPositive,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: DivineIcon(
                    icon: DivineIconName.search,
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_searchInputBorderRadius),
                  borderSide: BorderSide(
                    color: context.vineColors.accentPositive,
                    width: 2,
                  ),
                ),
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        BlocSelector<TagsPickerBloc, TagsPickerState, Set<String>>(
          selector: (s) => s.selectedTags,
          builder: (context, selectedTags) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: selectedTags.isNotEmpty
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 128),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _SelectedTagsChipRow(
                              tags: selectedTags.toList()..sort(),
                              onRemove: _removeTag,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (selectedTags.isNotEmpty)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.vineColors.outlineDisabled,
                  ),
              ],
            );
          },
        ),

        BlocSelector<TagsPickerBloc, TagsPickerState, bool>(
          selector: (s) => s.status == TagsPickerStatus.searching,
          builder: (context, isLoading) {
            return AnimatedOpacity(
              opacity: isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: DivineLinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: context.vineColors.accentPositive,
                minHeight: 2,
              ),
            );
          },
        ),

        Expanded(
          child: BlocBuilder<TagsPickerBloc, TagsPickerState>(
            builder: (context, state) {
              if (state.query.isEmpty) {
                if (state.selectedTags.isEmpty) {
                  return const _EmptyState();
                }
                return const SizedBox.shrink();
              }

              final sanitized = state.sanitizedQuery;
              final resultTags = [
                if (state.canAddQuery) sanitized,
                ...state.suggestions.where(
                  (s) => s.toLowerCase() != sanitized.toLowerCase(),
                ),
              ];

              if (resultTags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      context.l10n.videoMetadataTagsPickerNoResults,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                controller: widget.scrollController,
                padding: EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in resultTags)
                      _SuggestionChip(
                        key: ValueKey(tag),
                        label: tag,
                        onTap: () => _addSuggestionTag(tag),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}

/// Chip for a search-result hashtag — tap to add it to the selection.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.videoMetadataTagsPickerAddTag(label),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: DivineIcon(
                  icon: .plus,
                  size: 16,
                  color: context.vineColors.accentPositive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: .center,
        spacing: 16,
        children: [
          DivineIcon(
            icon: .search,
            size: 40,
            color: context.vineColors.onSurfaceMuted,
          ),
          Text(
            context.l10n.videoMetadataTagsPickerEmptyHint,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SelectedTagsChipRow extends StatelessWidget {
  const _SelectedTagsChipRow({required this.tags, required this.onRemove});

  final List<String> tags;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tag in tags)
            _TagChip(
              key: ValueKey(tag),
              label: tag,
              onRemove: () => onRemove(tag),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatefulWidget {
  const _TagChip({required this.label, required this.onRemove, super.key});

  final String label;
  final VoidCallback onRemove;

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = curved;
    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRemove() async {
    if (_isRemoving) return;
    _isRemoving = true;
    await _controller.reverse();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    widget.label,
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.videoMetadataDeleteTagHint(widget.label),
                child: GestureDetector(
                  onTap: _handleRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: DivineIcon(
                      icon: .x,
                      size: 16,
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
