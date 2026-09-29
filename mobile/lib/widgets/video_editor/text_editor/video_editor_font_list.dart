// ABOUTME: Scrollable list of the editor fonts grouped under category headers,
// ABOUTME: with pinned category chips that jump to a section; shared by both
// ABOUTME: font pickers.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/editor_text_fonts.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';

/// The editor fonts grouped by [EditorFontCategory], as [editorFontSections]
/// orders them, each rendered in its own face, under a pinned row of category
/// chips that jumps straight to a section.
///
/// A pick is reported through [onSelected] as the font's index into
/// [VideoEditorConstants.textFonts], so the grouping never reaches what saved
/// captions and title styles persist.
class VideoEditorFontList extends StatefulWidget {
  /// Creates the grouped font list.
  const VideoEditorFontList({
    required this.selectedIndex,
    required this.onSelected,
    this.controller,
    super.key,
  });

  /// Index into [VideoEditorConstants.textFonts] of the font shown as picked.
  final int selectedIndex;

  /// Called with the picked font's index into
  /// [VideoEditorConstants.textFonts].
  final ValueChanged<int> onSelected;

  /// Scroll controller of the font list, for a host that drives the scrolling
  /// such as a bottom sheet. The list owns one when this is null.
  final ScrollController? controller;

  @override
  State<VideoEditorFontList> createState() => _VideoEditorFontListState();
}

class _VideoEditorFontListState extends State<VideoEditorFontList> {
  ScrollController? _ownController;
  final _chipsController = ScrollController();
  final List<GlobalKey> _chipKeys = [
    for (final _ in editorFontSections) GlobalKey(),
  ];

  /// Index into [editorFontSections] of the highlighted chip.
  int _activeSection = 0;

  /// Whether scrolling moves the highlight. A chip tap stops it until the user
  /// scrolls again, because a jump to one of the last sections is clamped at
  /// the end of the list and would otherwise highlight an earlier section.
  bool _followScroll = true;

  late _FontListMetrics _metrics;

  ScrollController get _controller =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(VideoEditorFontList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onScroll);
      _controller.addListener(_onScroll);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metrics = _FontListMetrics(
      MediaQuery.textScalerOf(context),
      // The style DivineSectionHeader renders the category name in.
      headerStyle: VineTheme.labelMediumFont(
        color: context.vineColors.accentBrand,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _ownController?.dispose();
    _chipsController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_followScroll || !_controller.hasClients) return;
    final position = _controller.position;
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    _setActiveSection(
      atEnd
          ? editorFontSections.length - 1
          : _metrics.sectionAt(position.pixels),
    );
  }

  void _jumpToSection(int section) {
    _followScroll = false;
    if (_controller.hasClients) {
      final position = _controller.position;
      _controller.jumpTo(
        min(_metrics.sectionOffsets[section], position.maxScrollExtent),
      );
    }
    _setActiveSection(section);
  }

  void _setActiveSection(int section) {
    if (section == _activeSection) return;
    setState(() => _activeSection = section);
    _revealChip(section);
  }

  /// Scrolls the chip row, and only the chip row, until [section]'s chip is
  /// centred.
  void _revealChip(int section) {
    final chip = _chipKeys[section].currentContext?.findRenderObject();
    if (chip == null || !_chipsController.hasClients) return;
    final position = _chipsController.position;
    final target = RenderAbstractViewport.of(chip)
        .getOffsetToReveal(chip, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _chipsController.jumpTo(target);
    } else {
      _chipsController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryChips(
          controller: _chipsController,
          chipKeys: _chipKeys,
          activeSection: _activeSection,
          onSelected: _jumpToSection,
        ),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                _followScroll = true;
              }
              return false;
            },
            child: ListView.builder(
              controller: _controller,
              padding: .only(bottom: MediaQuery.viewPaddingOf(context).bottom),
              itemCount: _rows.length,
              itemExtentBuilder: (index, _) => switch (_rows[index]) {
                _HeaderRow() => _metrics.headerExtent,
                _FontRow() => _metrics.fontRowExtent,
              },
              itemBuilder: (context, index) => switch (_rows[index]) {
                _HeaderRow(:final category) => _CategoryHeader(
                  category: category,
                ),
                _FontRow(:final fontIndex) => _FontListItem(
                  font: VideoEditorConstants.textFonts[fontIndex],
                  isSelected: fontIndex == widget.selectedIndex,
                  onTap: () => widget.onSelected(fontIndex),
                ),
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Font size of the preview each font row renders its name in.
const double _fontPreviewSize = 24;

/// Row heights, and the scroll offset each section starts at.
///
/// Rows have a fixed extent so a chip can jump to a section that has not been
/// built yet: the list builds lazily, and a row's natural height depends on the
/// metrics of the font it previews. The extents scale with the system text
/// size, so a larger text setting still fits.
class _FontListMetrics {
  factory _FontListMetrics(
    TextScaler textScaler, {
    required TextStyle headerStyle,
  }) {
    final headerExtent =
        textScaler.scale(headerStyle.fontSize!) * (headerStyle.height ?? 1.2) +
        _headerPadding.vertical;
    final fontRowExtent = textScaler.scale(_fontPreviewSize) * 1.6 + 24;
    final sectionOffsets = <double>[];
    var offset = 0.0;
    for (final section in editorFontSections) {
      sectionOffsets.add(offset);
      offset += headerExtent + section.fontIndices.length * fontRowExtent;
    }
    return _FontListMetrics._(headerExtent, fontRowExtent, sectionOffsets);
  }

  const _FontListMetrics._(
    this.headerExtent,
    this.fontRowExtent,
    this.sectionOffsets,
  );

  static const _headerPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

  final double headerExtent;
  final double fontRowExtent;

  /// Scroll offset of each section's header, index-aligned with
  /// [editorFontSections].
  final List<double> sectionOffsets;

  /// Index of the section showing at the top of the list at [offset].
  int sectionAt(double offset) {
    var section = 0;
    for (var i = 0; i < sectionOffsets.length; i++) {
      if (sectionOffsets[i] <= offset + 1) section = i;
    }
    return section;
  }
}

/// [editorFontSections] flattened into the rows the list builds lazily.
final List<_Row> _rows = [
  for (final section in editorFontSections) ...[
    _HeaderRow(section.category),
    for (final fontIndex in section.fontIndices) _FontRow(fontIndex),
  ],
];

sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.category);

  final EditorFontCategory category;
}

class _FontRow extends _Row {
  const _FontRow(this.fontIndex);

  final int fontIndex;
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.controller,
    required this.chipKeys,
    required this.activeSection,
    required this.onSelected,
  });

  final ScrollController controller;
  final List<GlobalKey> chipKeys;
  final int activeSection;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          for (final (index, section) in editorFontSections.indexed)
            Semantics(
              key: chipKeys[index],
              selected: index == activeSection,
              child: DivineButton(
                label: section.category.localizedName(l10n),
                type: index == activeSection
                    ? DivineButtonType.secondary
                    : DivineButtonType.ghostSecondary,
                size: DivineButtonSize.tiny,
                onPressed: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final EditorFontCategory category;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Align(
        alignment: .bottomLeft,
        child: DivineSectionHeader(
          category.localizedName(context.l10n),
          padding: _FontListMetrics._headerPadding,
        ),
      ),
    );
  }
}

class _FontListItem extends StatelessWidget {
  const _FontListItem({
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  final TextFont font;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.videoEditorFontSemanticLabel,
      value: font.localizedDisplayName(l10n),
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const .symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  font.localizedDisplayName(l10n),
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: font(
                    fontSize: _fontPreviewSize,
                    color: isSelected
                        ? context.vineColors.primaryText
                        : context.vineColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (isSelected)
                DivineIcon(
                  icon: DivineIconName.check,
                  color: context.vineColors.accentPositive,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
