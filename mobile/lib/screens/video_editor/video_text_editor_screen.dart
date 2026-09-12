import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_font_selector.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_style_bar.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoTextEditorScreen extends StatefulWidget {
  const VideoTextEditorScreen({super.key, this.layer});

  final TextLayer? layer;

  @override
  State<VideoTextEditorScreen> createState() => _VideoTextEditorScreenState();
}

class _VideoTextEditorScreenState extends State<VideoTextEditorScreen> {
  final _textEditorKey = GlobalKey<TextEditorState>();

  @override
  void initState() {
    super.initState();
    Log.info(
      '✏️ Initialized (editing: ${widget.layer != null})',
      name: 'VideoTextEditorScreen',
      category: LogCategory.video,
    );
    _initFromLayer();
  }

  /// Initialize the bloc from layer if editing an existing text layer.
  void _initFromLayer() {
    final layer = widget.layer;
    final bloc = context.read<VideoEditorTextBloc>();

    if (layer == null) {
      Log.debug(
        '✏️ Creating new text layer',
        name: 'VideoTextEditorScreen',
        category: LogCategory.video,
      );
      bloc.add(const VideoEditorTextReset());
      return;
    }

    Log.debug(
      '✏️ Initializing from existing layer: "${layer.text}"',
      name: 'VideoTextEditorScreen',
      category: LogCategory.video,
    );

    // Get the primary color based on the layer's color mode.
    final primaryColor = layer.colorMode == .background
        ? layer.background
        : layer.color;

    final fontIndex = VideoEditorConstants.textFonts.indexWhere(
      (el) => el() == layer.textStyle,
    );

    bloc.add(
      VideoEditorTextInitFromLayer(
        text: layer.text,
        alignment: layer.align,
        color: primaryColor,
        backgroundStyle: layer.colorMode,
        fontSize: _normalizeFontScale(layer.fontScale),
        selectedFontIndex: max(0, fontIndex),
      ),
    );
  }

  /// Converts font scale to normalized value (0.0-1.0).
  double _normalizeFontScale(double fontScale) {
    return ((fontScale - VideoEditorConstants.minFontScale) /
            (VideoEditorConstants.maxFontScale -
                VideoEditorConstants.minFontScale))
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: VideoEditorConstants.textEditorBackground),
        ),
        Positioned.fill(
          child: VideoTextEditorScope(
            editorKey: _textEditorKey,
            child: Column(
              children: [
                Expanded(
                  child: _TextEditor(
                    editorKey: _textEditorKey,
                    layer: widget.layer,
                  ),
                ),
                _DismissibleBottomSheet(
                  onDismissed: () {
                    if (mounted) context.pop();
                  },
                  child: _BottomPanel(
                    editorKey: _textEditorKey,
                    onKeyboardClosedWithoutPanel: () {
                      if (mounted) context.pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.editorKey,
    this.onKeyboardClosedWithoutPanel,
  });

  final GlobalKey<TextEditorState> editorKey;
  final VoidCallback? onKeyboardClosedWithoutPanel;

  @override
  Widget build(BuildContext context) {
    final (showFontSelector, showColorPicker, color) = context.select(
      (VideoEditorTextBloc bloc) => (
        bloc.state.showFontSelector,
        bloc.state.showColorPicker,
        bloc.state.color,
      ),
    );

    final showBottomPanel = showFontSelector || showColorPicker;

    return Container(
      decoration: BoxDecoration(
        color: context.vineColors.surface,
        borderRadius: const .vertical(
          top: .circular(VineTheme.bottomSheetBorderRadius),
        ),
      ),
      child: Column(
        children: [
          const VineBottomSheetHeader(),
          const Padding(
            padding: .symmetric(vertical: 16),
            child: VideoEditorTextStyleBar(),
          ),
          Divider(height: 2, color: context.vineColors.surfaceContainer),
          _KeyboardHeightPanel(
            showBottomPanel: showBottomPanel,
            backgroundColor: context.vineColors.surface,
            onKeyboardClosedWithoutPanel: onKeyboardClosedWithoutPanel,
            child: showFontSelector
                ? VideoEditorTextFontSelector(
                    onFontSelected: (textStyle) {
                      editorKey.currentState?.setTextStyle(textStyle);
                    },
                  )
                : VideoEditorColorPickerSheet(
                    selectedColor: color,
                    onColorSelected: (color) {
                      editorKey.currentState?.primaryColor = color;
                      context.read<VideoEditorTextBloc>().add(
                        VideoEditorTextColorSelected(color),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TextEditor extends StatelessWidget {
  const _TextEditor({required this.editorKey, this.layer});

  final GlobalKey<TextEditorState> editorKey;
  final TextLayer? layer;

  /// Maps [TextAlign] to [Alignment] for the input text field position.
  static Alignment _getInputAlignment(TextAlign textAlign) {
    return switch (textAlign) {
      .left || .start => .centerLeft,
      .right || .end => .centerRight,
      _ => .center,
    };
  }

  /// Converts normalized font size (0.0-1.0) to font scale.
  static double _getFontScale(double normalizedValue) {
    return VideoEditorConstants.minFontScale +
        (normalizedValue *
            (VideoEditorConstants.maxFontScale -
                VideoEditorConstants.minFontScale));
  }

  @override
  Widget build(BuildContext context) {
    final (
      alignment,
      fontSize,
      backgroundStyle,
      color,
      selectedFontIndex,
    ) = context.select(
      (VideoEditorTextBloc bloc) => (
        bloc.state.alignment,
        bloc.state.fontSize,
        bloc.state.backgroundStyle,
        bloc.state.color,
        bloc.state.selectedFontIndex,
      ),
    );

    return MediaQuery.removeViewPadding(
      context: context,
      removeBottom: true,
      child: TextEditor(
        key: editorKey,
        layer: layer,
        theme: Theme.of(context),
        heroTag: layer?.id,
        callbacks: ProImageEditorCallbacks(
          textEditorCallbacks: TextEditorCallbacks(
            onChanged: (value) {
              context.read<VideoEditorTextBloc>().add(
                VideoEditorTextContentChanged(value),
              );
            },
            onBackgroundModeChanged: (value) {
              context.read<VideoEditorTextBloc>().add(
                VideoEditorTextBackgroundStyleChanged(value),
              );
            },
            onTextAlignChanged: (value) {
              context.read<VideoEditorTextBloc>().add(
                VideoEditorTextAlignmentChanged(value),
              );
            },
          ),
        ),
        configs: ProImageEditorConfigs(
          i18n: const I18n(textEditor: I18nTextEditor(inputHintText: '')),
          textEditor: TextEditorConfigs(
            style: const TextEditorStyle(
              background: Colors.transparent,
              inputCursorColor: VineTheme.whiteText,
              inputTextFieldPadding: .only(top: 96, left: 16, right: 48),
            ),
            safeArea: const EditorSafeArea.none(),
            enableAutocorrect: false,
            resizeToAvoidBottomInset: false,
            minFontScale: VideoEditorConstants.minFontScale,
            maxFontScale: VideoEditorConstants.maxFontScale,
            initFontScale: _getFontScale(fontSize),
            initialBackgroundColorMode: backgroundStyle,
            initialTextAlign: alignment,
            initialPrimaryColor: color,
            defaultTextStyle:
                VideoEditorConstants.textFonts[selectedFontIndex](),
            inputTextFieldAlign: _getInputAlignment(alignment),
            enableAutoOverflow: false,
            widgets: TextEditorWidgets(
              appBar: (_, _) => null,
              bottomBar: (_, _) => null,
              colorPicker: (_, _, _, _) => null,
              bodyItemsOverlay: (editor, rebuildStream) => [
                ReactiveWidget(
                  stream: rebuildStream,
                  builder: (_) => const VideoEditorTextOverlayControls(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardHeightPanel extends StatefulWidget {
  const _KeyboardHeightPanel({
    required this.showBottomPanel,
    required this.backgroundColor,
    required this.child,
    this.onKeyboardClosedWithoutPanel,
  });

  final bool showBottomPanel;
  final Color backgroundColor;
  final Widget child;
  final VoidCallback? onKeyboardClosedWithoutPanel;

  @override
  State<_KeyboardHeightPanel> createState() => _KeyboardHeightPanelState();
}

class _KeyboardHeightPanelState extends State<_KeyboardHeightPanel>
    with WidgetsBindingObserver {
  /// Threshold to consider keyboard as "open".
  static const double _keyboardThreshold = 100.0;

  /// Stores the last known keyboard height for smooth transitions.
  double _lastKeyboardHeight = 0.0;

  /// Previous bottom inset to detect keyboard state changes.
  double _lastInset = 0.0;

  /// Tracks if we already triggered the pop callback.
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;

    // Keyboard opened → close font selector / color picker panels
    if (_lastInset < _keyboardThreshold && bottomInset > _keyboardThreshold) {
      context.read<VideoEditorTextBloc>().add(
        const VideoEditorTextClosePanels(),
      );
    }

    if (_lastInset > _keyboardThreshold &&
        bottomInset < _keyboardThreshold &&
        !widget.showBottomPanel) {
      _schedulePopIfNeeded();
    }

    _lastInset = bottomInset;
  }

  /// Schedules a pop callback with delay if not already popped.
  void _schedulePopIfNeeded() {
    if (_hasPopped) return;
    _hasPopped = true;
    // Only pop if this screen is still the current route (prevents double-pop
    // when pop() was already called elsewhere, e.g., by a button)
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      widget.onKeyboardClosedWithoutPanel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final isKeyboardVisible = keyboardHeight > _keyboardThreshold;

    if (isKeyboardVisible && keyboardHeight > _lastKeyboardHeight) {
      _lastKeyboardHeight = keyboardHeight;
    }

    final effectiveHeight = max(_lastKeyboardHeight, bottomPadding);

    Widget content;
    if (widget.showBottomPanel) {
      // Panel visible → panel determines its own height
      content = widget.child;
    } else {
      content = SizedBox(height: effectiveHeight, width: double.infinity);
    }

    return ColoredBox(
      color: widget.backgroundColor,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        curve: Curves.easeInOut,
        child: Material(type: .transparency, child: content),
      ),
    );
  }
}

/// Wraps a child in a vertical drag gesture that slides the sheet down
/// and calls [onDismissed] when the user drags past the threshold or
/// flings downward.
class _DismissibleBottomSheet extends StatefulWidget {
  const _DismissibleBottomSheet({
    required this.child,
    required this.onDismissed,
  });

  final Widget child;
  final VoidCallback onDismissed;

  @override
  State<_DismissibleBottomSheet> createState() =>
      _DismissibleBottomSheetState();
}

class _DismissibleBottomSheetState extends State<_DismissibleBottomSheet> {
  /// Distance the user must drag down to dismiss.
  static const double _dismissThreshold = 80.0;

  /// Fling velocity (px/s) that triggers instant dismiss.
  static const double _flingVelocity = 700.0;

  double _dragOffset = 0.0;
  bool _dismissed = false;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissed) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissed) return;

    if (_dragOffset > _dismissThreshold ||
        (details.primaryVelocity != null &&
            details.primaryVelocity! > _flingVelocity)) {
      _dismissed = true;
      widget.onDismissed();
    } else {
      setState(() => _dragOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedContainer(
        duration: _dragOffset == 0.0
            ? const Duration(milliseconds: 200)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: widget.child,
      ),
    );
  }
}
