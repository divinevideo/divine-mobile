// ABOUTME: Main comment input widget at bottom of comments sheet
// ABOUTME: Text field with send button for posting new top-level comments

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mentions/mention_suggestion.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';

/// Input widget for posting new top-level comments.
///
/// Positioned at the bottom of the comments sheet with keyboard-aware padding.
/// Features:
/// - Background container with rounded corners
/// - Conditional send button (hidden when empty)
/// - Reply indicator positioned at bottom inside container
/// - Multiline support with constraints
class CommentInput extends StatefulWidget {
  const CommentInput({
    required this.controller,
    required this.onSubmit,
    this.onChanged,
    this.replyToDisplayName,
    this.onCancelReply,
    this.isEditing = false,
    this.onCancelEdit,
    this.focusNode,
    this.mentionSuggestions = const [],
    this.onMentionQuery,
    this.onMentionSelected,
    this.onVideoReplyPressed,
    super.key,
  });

  /// Text editing controller for the input field.
  final TextEditingController controller;

  /// Callback when the send button is pressed.
  final VoidCallback onSubmit;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  /// Display name of the user being replied to (null if not a reply).
  final String? replyToDisplayName;

  /// Callback when the cancel reply button is pressed.
  final VoidCallback? onCancelReply;

  /// Whether the input is in edit mode.
  final bool isEditing;

  /// Callback when the cancel edit button is pressed.
  final VoidCallback? onCancelEdit;

  /// Focus node for the text field to allow programmatic focus.
  final FocusNode? focusNode;

  /// Mention suggestions for autocomplete overlay.
  final List<MentionSuggestion> mentionSuggestions;

  /// Callback fired with the query text after '@'.
  final ValueChanged<String>? onMentionQuery;

  /// Callback fired with (hex pubkey, displayName, start, exclusive end) when a
  /// mention is selected.
  final void Function(
    String pubkey,
    String displayName,
    int start,
    int end,
  )?
  onMentionSelected;

  /// Callback fired when the user wants to record a video comment.
  final VoidCallback? onVideoReplyPressed;

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  bool _hasText = false;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_syncHasText);
    _attachFocusNode(widget.focusNode);
  }

  @override
  void didUpdateWidget(CommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncHasText);
      widget.controller.addListener(_syncHasText);
      _syncHasText();
    }

    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncHasText);
    _detachFocusNode();
    super.dispose();
  }

  // TextField.onChanged does not fire for programmatic controller writes, and
  // the comments sheet clears the composer that way after a post. Tracking the
  // controller directly keeps the trailing slot honest: without it the send
  // button stays parked over an empty field and the video-reply button never
  // comes back.
  void _syncHasText() {
    if (!mounted) return;
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() {
      _hasText = hasText;
    });
  }

  void _attachFocusNode(FocusNode? focusNode) {
    // CommentInput can either own its own FocusNode or mirror one supplied by
    // the parent comments screen. Tracking ownership lets us show focus-driven
    // UI without disposing a node we do not own.
    _ownsFocusNode = focusNode == null;
    _focusNode = focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleTextChanged(String text) {
    // `_hasText` is kept in step by the controller listener; this handler
    // only owns the mention query and the outward callback.
    _detectMentionQuery(text);

    widget.onChanged?.call(text);
  }

  void _detectMentionQuery(String text) {
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    // Find the last @ before cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      // Check there's no space between @ and cursor (query is continuous)
      final query = textBeforeCursor.substring(atIndex + 1);
      if (!query.contains(' ') && !query.contains('\n')) {
        widget.onMentionQuery?.call(query);
        return;
      }
    }

    // No active mention query
    widget.onMentionQuery?.call('');
  }

  void _handleMentionSelected(String pubkey, String displayName) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex < 0) return;

    // Replace @query with @displayName (human-readable). The BLoC keeps the
    // selected hex pubkey and canonicalizes the text on submit.
    final mention = '@$displayName ';
    final newText =
        text.substring(0, atIndex) + mention + text.substring(cursorPos);
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: atIndex + mention.length,
    );

    widget.onMentionSelected?.call(
      pubkey,
      displayName,
      atIndex,
      atIndex + mention.length - 1,
    );
    widget.onChanged?.call(newText);
  }

  @override
  Widget build(BuildContext context) {
    final isReplying = widget.replyToDisplayName != null;
    final isEditing = widget.isEditing;
    final showKeyboardDismiss = _focusNode.hasFocus;

    return TextFieldTapRegion(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mention overlay (shows above input when suggestions available)
          if (widget.mentionSuggestions.isNotEmpty)
            MentionOverlay(
              suggestions: widget.mentionSuggestions,
              onSelect: _handleMentionSelected,
            ),
          // Input container
          Container(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              top: 16,
              bottom: 8,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: context.vineColors.iconButton,
                borderRadius: BorderRadius.circular(20),
              ),
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: fixedRowTextScaleLimit,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _CommentTextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              isReplying: isReplying,
                              isEditing: isEditing,
                              onSubmitted: widget.onSubmit,
                              onChanged: _handleTextChanged,
                            ),
                          ),
                          if (isEditing)
                            _EditIndicator(onCancel: widget.onCancelEdit!)
                          else if (isReplying)
                            _ReplyIndicator(
                              displayName: widget.replyToDisplayName!,
                              onCancel: widget.onCancelReply!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onVideoReplyPressed != null ||
                      showKeyboardDismiss ||
                      _hasText) ...[
                    const SizedBox(width: 8),
                    if (!_hasText && widget.onVideoReplyPressed != null)
                      _VideoReplyButton(
                        onPressed: widget.onVideoReplyPressed!,
                      ),
                    if (!_hasText &&
                        widget.onVideoReplyPressed != null &&
                        showKeyboardDismiss)
                      const SizedBox(width: 4),
                    // Keep an explicit in-field dismiss affordance visible while
                    // the keyboard is up so the send button does not become the
                    // only actionable control on compact screens.
                    if (showKeyboardDismiss)
                      _KeyboardDismissButton(onPressed: _focusNode.unfocus),
                    if (showKeyboardDismiss && _hasText)
                      const SizedBox(width: 4),
                    if (_hasText) _SendButton(onSubmit: widget.onSubmit),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoReplyButton extends StatelessWidget {
  const _VideoReplyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'record_video_comment_button',
      button: true,
      label: context.l10n.commentsRecordVideoButtonLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          child: Container(
            width: DivineIcon.scaleSize(context, 40),
            height: DivineIcon.scaleSize(context, 40),
            margin: const EdgeInsets.only(bottom: 4),
            // The camera asset is 29x18, so `contain` sizes it off its height
            // and it renders 35px wide inside the 40px circle. The padding
            // caps that width; without it the glyph sits 2px from the edge.
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: context.vineColors.containerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              icon: DivineIcon(
                icon: DivineIconName.videoCamera,
                color: context.vineColors.primaryText,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field for entering comment text.
class _CommentTextField extends StatelessWidget {
  const _CommentTextField({
    required this.controller,
    required this.isReplying,
    required this.onSubmitted,
    required this.onChanged,
    this.isEditing = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isReplying;
  final bool isEditing;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = isEditing
        ? context.l10n.commentsInputSemanticLabelEdit
        : isReplying
        ? context.l10n.commentsInputSemanticLabelReply
        : context.l10n.commentsInputSemanticLabel;
    final semanticHint = isEditing
        ? context.l10n.commentsInputSemanticHintEdit
        : isReplying
        ? context.l10n.commentsInputSemanticHintReply
        : context.l10n.commentsInputSemanticHint;
    final hintText = isEditing
        ? context.l10n.commentsInputHintEdit
        : context.l10n.commentsInputHint;
    // Top-level comments keep Enter-to-send for quick posting, while reply/edit
    // flows stay multiline so users can compose longer text in-place.
    final isComposingMultiline = isReplying || isEditing;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, bottom: 14, top: 14),
      child: Semantics(
        identifier: 'comment_text_field',
        textField: true,
        label: semanticLabel,
        hint: semanticHint,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: TextInputType.multiline,
          textInputAction: isComposingMultiline
              ? TextInputAction.newline
              : TextInputAction.send,
          onSubmitted: isComposingMultiline ? null : (_) => onSubmitted(),
          enableInteractiveSelection: true,
          // The pill styling needs a raw TextField, which leaves spell check
          // off unless a config is passed — DivineTextField applies this same
          // one by default.
          spellCheckConfiguration:
              DivineTextField.defaultSpellCheckConfiguration,
          style: VineTheme.bodyLargeFont(color: context.vineColors.onSurface),
          cursorColor: VineTheme.tabIndicatorGreen,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          maxLines: 5,
          minLines: 1,
        ),
      ),
    );
  }
}

class _KeyboardDismissButton extends StatelessWidget {
  const _KeyboardDismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'hide_comment_keyboard_button',
      button: true,
      // This label is localized because the control is newly introduced in
      // this PR rather than inherited legacy copy.
      label: context.l10n.commentHideKeyboard,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: context.vineColors.containerLow,
          borderRadius: BorderRadius.circular(17),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          // Use the design-system icon set for new UI so the bottom-sheet input
          // stays visually consistent with the rest of Divine.
          icon: DivineIcon(
            icon: DivineIconName.caretDown,
            color: context.vineColors.primaryText,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Send button that appears when text is entered.
///
/// Stays visually as a sendable up-arrow at all times. Comment posting is
/// optimistic at the BLoC layer (see `CommentComposerBloc._onSubmitted` —
/// emits `ComposerOutboxInsertPlaceholder` before awaiting `postComment`):
/// the comment lands in the list before the network call, so this button
/// has no in-flight state to surface — matching WhatsApp/Telegram-style
/// instant-send affordance.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'send_comment_button',
      button: true,
      label: context.l10n.videoOverlayCommentBarSendLabel,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsetsDirectional.only(end: 4, bottom: 4),
        decoration: BoxDecoration(
          color: VineTheme.tabIndicatorGreen,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: VineTheme.backgroundColor.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0.5, 0.5),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onSubmit,
          padding: EdgeInsets.zero,
          icon: const DivineIcon(
            icon: DivineIconName.arrowUp,
            color: VineTheme.primaryText,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Edit indicator showing the comment is being edited.
class _EditIndicator extends StatelessWidget {
  const _EditIndicator({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCancel,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          bottom: 8,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                context.l10n.commentsInputEditingLabel,
                style: VineTheme.bodySmallFont(
                  color: VineTheme.tabIndicatorGreen,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              child: const DivineIcon(
                icon: DivineIconName.x,
                size: 16,
                color: VineTheme.tabIndicatorGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reply indicator showing who is being replied to.
class _ReplyIndicator extends StatelessWidget {
  const _ReplyIndicator({required this.displayName, required this.onCancel});

  final String displayName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCancel,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          bottom: 8,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '${context.l10n.commentReplyToPrefix} $displayName',
                style: VineTheme.bodySmallFont(
                  color: VineTheme.tabIndicatorGreen,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              child: const DivineIcon(
                icon: DivineIconName.x,
                size: 16,
                color: VineTheme.tabIndicatorGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
