// ABOUTME: Inline comment composer bar shown at the bottom of the fullscreen
// ABOUTME: video player on Explore / Search / Profile entry points.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Comment composer pinned to the bottom of [PooledFullscreenVideoFeedScreen].
///
/// Tapping the field opens the keyboard so the user can type and post a
/// comment without ever opening the full comments sheet — the goal is "drop
/// a comment without reading the others". On send, the keyboard dismisses
/// and a snackbar confirms the outcome.
///
/// Lives inside the Scaffold body (not [Scaffold.bottomNavigationBar]) so
/// the keyboard can push it up rather than stranding it below the keyboard.
/// The pill grows with the [TextField]'s 1–5-line range — there is no fixed
/// bar height. Visibility is owned by the parent screen, which gates on
/// "active video present" and "user signed in".
class InlineCommentComposerBar extends StatefulWidget {
  const InlineCommentComposerBar({super.key, this.onFocusChanged});

  /// Notifies the parent screen when this composer gains/loses focus, so it
  /// can drive `Scaffold.resizeToAvoidBottomInset` only while THIS field is
  /// focused — the reel must not resize (and jank) for a keyboard owned by a
  /// modal on top (e.g. the share sheet). See [PooledFullscreenVideoFeedScreen].
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<InlineCommentComposerBar> createState() =>
      _InlineCommentComposerBarState();
}

class _InlineCommentComposerBarState extends State<InlineCommentComposerBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  /// Snapshot of the field's text taken at submit-time so the
  /// [BlocListener] can restore it if the cubit emits `failure`.
  /// Mirrors `CommentComposerBloc._emitSubmitRollback`'s rollback of
  /// `mainInputText` on publish error — without it the optimistic clear
  /// permanently loses the draft when the network call fails. Empty
  /// string means "nothing pending"; [_handleSubmit] early-returns on
  /// empty input so the field can only ever hold a real, non-empty draft.
  String _pendingDraft = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSubmit() {
    final video = context.read<FullscreenFeedBloc>().state.currentVideo;
    if (video == null) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    // Optimistic UX: clear the field and drop the keyboard immediately so
    // the user moves on while the publish lands in the background. The
    // cubit owns the snackbar via the BlocListener wired below, which
    // also restores [_pendingDraft] into the field on failure.
    _pendingDraft = text;
    context.read<InlineCommentComposerCubit>().submit(
      video: video,
      content: text,
    );
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InlineCommentComposerCubit, InlineCommentComposerState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          (curr.status == InlineCommentComposerStatus.submitted ||
              curr.status == InlineCommentComposerStatus.failure),
      listener: (context, state) {
        final draft = _pendingDraft;
        _pendingDraft = '';

        // Restore the typed draft when the publish fails so the user
        // can retry without retyping. The `controller.text.isEmpty`
        // guard prevents clobbering any text the user already started
        // typing after the optimistic clear.
        if (state.status == InlineCommentComposerStatus.failure &&
            draft.isNotEmpty &&
            _controller.text.isEmpty) {
          _controller.text = draft;
          _controller.selection = TextSelection.collapsed(
            offset: draft.length,
          );
          _focusNode.requestFocus();
        }

        final message = state.status == InlineCommentComposerStatus.submitted
            ? context.l10n.videoOverlayCommentPostedSnackbar
            : context.l10n.videoOverlayCommentPostFailedSnackbar;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        context.read<InlineCommentComposerCubit>().acknowledge();
      },
      child: ColoredBox(
        color: context.vineColors.surface,
        // Manually compute the bottom inset instead of using SafeArea
        // because the bar lives inside the Scaffold body (so it can ride
        // above the keyboard). When the keyboard is up, viewInsets.bottom
        // grows by the keyboard height while viewPadding.bottom stays at
        // the device's home-indicator size — leaving a SafeArea-driven
        // gap of empty surface color above the keyboard. Clamping to
        // `max(0, viewPadding - viewInsets)` collapses the inset to 0 in
        // that case so the input pill sits flush against the keyboard.
        child: Padding(
          padding: EdgeInsets.only(
            bottom: math.max(
              0,
              MediaQuery.viewPaddingOf(context).bottom -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
          // Outer pill spacing mirrors the comments-sheet `CommentInput`
          // (`start: 16, end: 16, top: 16, bottom: 8`) so the inline
          // composer's vertical rhythm — and its 1-to-5-line growth —
          // matches exactly. The bar's intrinsic height is no longer
          // fixed: the pill inside grows with the text field's
          // `minLines: 1, maxLines: 5` and the surrounding Column resizes
          // accordingly.
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: _ComposerField(
              controller: _controller,
              focusNode: _focusNode,
              hasText: _hasText,
              onSubmit: _handleSubmit,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped text field that fills the bar content area.
///
/// The send button appears only when [hasText] is true so an empty bar
/// shows just the "Add comment…" hint — matching the Figma spec
/// (node 15222:192143).
class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // Pill geometry mirrors `CommentInput` in the comments-sheet
    // composer at `lib/screens/comments/widgets/comment_input.dart`:
    // a 20-radius DecoratedBox with `minHeight: 48`, a Row aligned to
    // [CrossAxisAlignment.end] so the send button stays anchored at
    // the bottom of the pill as the text field grows multi-line, and
    // a TextField with `TextInputType.multiline` + `minLines: 1,
    // maxLines: 5` so long comments wrap up to five lines inside the
    // pill instead of being clipped to a single line.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.iconButton,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                // 12 / 12 vertical padding around a 24-line-height
                // text field gives the pill an exact 48 px single-line
                // height (12 + 24 + 12), matching Figma node
                // 15222:192139. The pill grows past 48 when the field
                // wraps onto a second line via `minLines: 1,
                // maxLines: 5` below.
                padding: const EdgeInsetsDirectional.only(
                  start: 16,
                  end: 8,
                  top: 12,
                  bottom: 12,
                ),
                child: Semantics(
                  identifier: 'inline_comment_composer_field',
                  textField: true,
                  label: context.l10n.videoOverlayCommentBarSemanticLabel,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSubmit(),
                    // Tap anywhere outside the field (the video, the
                    // action column, the app bar) dismisses the
                    // keyboard — matches the DM ConversationView
                    // convention.
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    // Raw TextFields leave spell check off unless a config is
                    // passed; matches the comments-sheet composer.
                    spellCheckConfiguration:
                        DivineTextField.defaultSpellCheckConfiguration,
                    cursorColor: VineTheme.tabIndicatorGreen,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.primaryText,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.videoOverlayCommentBarHint,
                      hintStyle: VineTheme.bodyLargeFont(
                        color: context.vineColors.onSurfaceMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
              ),
            ),
            if (hasText) _SendButton(onPressed: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `bottom: 4` floats the button 4 px above the pill's bottom
      // edge so it stays anchored to the bottom-right corner with a
      // consistent inset when the pill grows multi-line (matches
      // `_SendButton` in the comments-sheet composer).
      padding: const EdgeInsetsDirectional.only(end: 4, bottom: 4),
      child: Semantics(
        identifier: 'inline_comment_composer_send_button',
        button: true,
        label: context.l10n.videoOverlayCommentBarSendLabel,
        child: SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            // Spec: Figma node 2018:29838 ("primary"). Native size is
            // 48 with 20 radius / 32 icon / 8 padding. The composition
            // at node 14368:75902 scales it to a 40 px slot at
            // 40 / 48 = 0.833 × — radius becomes 16.667, icon becomes
            // 26.667. The 20 / 48 = 41.7 % radius ratio is a heavily
            // rounded rectangle, not a circle (a circle would need
            // 50 %). Background is `primary/primary` (#27C58B =
            // [VineTheme.primary]). Two stacked sub-pixel drop shadows
            // give a faint elevation cue against the pill.
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(16.667),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0.333, 0.333),
                  blurRadius: 0.25,
                ),
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0.833, 0.833),
                  blurRadius: 0.417,
                ),
              ],
            ),
            child: IconButton(
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              icon: const DivineIcon(
                icon: DivineIconName.arrowUp,
                // The Figma vector at node 2018:29838 fills with
                // `primary/on-primary` (#003824 = dark green), the
                // M3-convention contrast color on a primary surface —
                // NOT white. Tested against the rendered Figma asset.
                color: VineTheme.onPrimaryButton,
                size: 26.667,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
