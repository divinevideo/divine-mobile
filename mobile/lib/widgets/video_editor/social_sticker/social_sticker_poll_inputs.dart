// ABOUTME: Where a creator sets up a poll, quiz or slider sticker: its question,
// ABOUTME: its answers and a quiz's right one, or the emoji a slider rates with.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:openvine/widgets/whole_word_button_text_scale.dart';
import 'package:poll_repository/poll_repository.dart' show Poll;

/// The question a poll, quiz or slider asks.
class _QuestionField extends StatefulWidget {
  const _QuestionField({required this.autofocus, this.onNext});

  final bool autofocus;

  /// Moves on to the field after the question; without, the keyboard's key
  /// is a Done.
  final VoidCallback? onNext;

  @override
  State<_QuestionField> createState() => _QuestionFieldState();
}

class _QuestionFieldState extends State<_QuestionField> {
  late final _controller = TextEditingController(
    text: context.read<SocialStickerCubit>().state.data.pollQuestion ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: DivineTextField(
        controller: _controller,
        filled: true,
        autofocus: widget.autofocus,
        labelText: context.l10n.videoEditorSocialStickerPollQuestionHint,
        // One line: the sticker's label puts each answer on a line of its own.
        maxLines: 1,
        maxLength: SocialStickerData.maxPollQuestionLength,
        textInputAction: widget.onNext == null ? .done : .next,
        onEditingComplete: widget.onNext,
        onChanged: context.read<SocialStickerCubit>().pollQuestionChanged,
      ),
    );
  }
}

/// A poll's or a quiz's question and its two to four answers, which can be
/// added and removed; a quiz marks its right answer beside it.
class SocialStickerPollFields extends StatefulWidget {
  const SocialStickerPollFields({this.autofocus = false, super.key});

  final bool autofocus;

  @override
  State<SocialStickerPollFields> createState() =>
      _SocialStickerPollFieldsState();
}

class _SocialStickerPollFieldsState extends State<SocialStickerPollFields> {
  /// One per answer, kept in step with the cubit's answers.
  late final List<TextEditingController> _controllers = [
    for (final answer
        in context.read<SocialStickerCubit>().state.data.pollOptions)
      TextEditingController(text: answer),
  ];

  /// One per answer, so the keyboard's Next goes from one answer field to
  /// the next rather than to the buttons beside them.
  late final List<FocusNode> _focusNodes = [
    for (final _ in _controllers) FocusNode(),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _add() {
    final cubit = context.read<SocialStickerCubit>();
    if (cubit.state.data.pollOptions.length >= Poll.maxOptions) return;
    final node = FocusNode();
    setState(() {
      _controllers.add(TextEditingController());
      _focusNodes.add(node);
    });
    cubit.pollOptionAdded();
    node.requestFocus();
  }

  void _remove(int index) {
    final cubit = context.read<SocialStickerCubit>();
    if (cubit.state.data.pollOptions.length <= Poll.minOptions) return;
    setState(() {
      _controllers.removeAt(index).dispose();
      _focusNodes.removeAt(index).dispose();
    });
    cubit.pollOptionRemoved(index);
  }

  @override
  Widget build(BuildContext context) {
    final (kind, quizAnswer) = context.select(
      (SocialStickerCubit cubit) =>
          (cubit.state.data.kind, cubit.state.data.quizAnswer),
    );
    final l10n = context.l10n;
    final cubit = context.read<SocialStickerCubit>();
    final isQuiz = kind == SocialStickerKind.quiz;
    final labels = [
      for (var index = 0; index < _controllers.length; index++)
        l10n.videoEditorSocialStickerPollOptionHint('${index + 1}'),
    ];
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        _QuestionField(
          autofocus: widget.autofocus,
          onNext: _focusNodes.first.requestFocus,
        ),
        for (final (index, controller) in _controllers.indexed)
          Padding(
            // Keyed by the controller, so removing an answer above does not
            // hand this one's text to another field.
            key: ObjectKey(controller),
            padding: const .symmetric(horizontal: 16),
            child: _AnswerRow(
              labels: labels,
              field: DivineTextField(
                // Keep the input connection when the responsive layout
                // moves this field between a Row and a Column.
                key: GlobalObjectKey(controller),
                controller: controller,
                focusNode: _focusNodes[index],
                filled: true,
                labelText: labels[index],
                maxLines: 1,
                maxLength: SocialStickerData.maxPollOptionLength,
                textInputAction: index == _controllers.length - 1
                    ? .done
                    : .next,
                onEditingComplete: index == _controllers.length - 1
                    ? null
                    : _focusNodes[index + 1].requestFocus,
                onChanged: (text) => cubit.pollOptionChanged(index, text),
              ),
              leading: isQuiz
                  ? DivineIconButton(
                      icon: .check,
                      type: quizAnswer == index
                          ? DivineIconButtonType.primary
                          : DivineIconButtonType.ghostSecondary,
                      size: DivineIconButtonSize.small,
                      showShadow: false,
                      semanticLabel: l10n.videoEditorSocialStickerQuizMarkRight(
                        '${index + 1}',
                      ),
                      semanticToggled: quizAnswer == index,
                      onPressed: () => cubit.quizAnswerPicked(index),
                    )
                  : null,
              trailing: _controllers.length > Poll.minOptions
                  ? DivineIconButton(
                      icon: .x,
                      type: DivineIconButtonType.ghostSecondary,
                      size: DivineIconButtonSize.small,
                      showShadow: false,
                      semanticLabel: l10n
                          .videoEditorSocialStickerPollRemoveOption(
                            '${index + 1}',
                          ),
                      onPressed: () => _remove(index),
                    )
                  : null,
            ),
          ),
        if (_controllers.length < Poll.maxOptions)
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: WholeWordButtonTextScale(
              label: l10n.videoEditorSocialStickerPollAddOption,
              hasLeadingIcon: true,
              child: DivineButton(
                label: l10n.videoEditorSocialStickerPollAddOption,
                type: DivineButtonType.secondary,
                leadingIcon: .plus,
                expanded: true,
                maxLines: 2,
                onPressed: _add,
              ),
            ),
          ),
        StickerSheetNote(
          text: isQuiz
              ? l10n.videoEditorSocialStickerQuizNote
              : l10n.videoEditorSocialStickerPollNote,
        ),
      ],
    );
  }
}

/// An answer's [field] between a quiz's check, [leading], and the button
/// that removes the answer, [trailing], each when there is one.
///
/// With large text a field's label would be cut beside the buttons, so they
/// move to a row under the field, which then takes the full width. Every
/// answer does so once one of the [labels] would be cut, so they line up.
class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.labels,
    required this.field,
    this.leading,
    this.trailing,
  });

  /// The gap between the field and a button.
  static const double _gap = 8;

  /// How wide a small [DivineIconButton] is, before text scaling.
  static const double _buttonSize = 48;

  /// The labels of every answer's field.
  final List<String> labels;
  final Widget field;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final trailing = this.trailing;
    // A row even without buttons, so the field keeps its state as a remove
    // button comes and goes.
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = [?leading, ?trailing].length;
        final buttonsWidth =
            buttons * (DivineIcon.scaleSize(context, _buttonSize) + _gap);
        final fieldWidth = constraints.maxWidth - buttonsWidth;
        final fitsBeside =
            buttons == 0 ||
            labels.every(
              (label) => stickerFieldWidthFor(context, label) <= fieldWidth,
            );
        if (fitsBeside) {
          return Row(
            spacing: _gap,
            children: [
              ?leading,
              Expanded(child: field),
              ?trailing,
            ],
          );
        }
        // Close under their field's counter and clear of the next answer,
        // so they read as this answer's.
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            field,
            Padding(
              padding: const .only(bottom: _gap),
              child: Row(children: [?leading, const Spacer(), ?trailing]),
            ),
          ],
        );
      },
    );
  }
}

/// A slider's question and the emoji viewers drag along it.
class SocialStickerSliderFields extends StatelessWidget {
  const SocialStickerSliderFields({this.autofocus = false, super.key});

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final emoji = context.select(
      (SocialStickerCubit cubit) => cubit.state.data.sliderEmoji,
    );
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        _QuestionField(autofocus: autofocus),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: .horizontal,
            padding: const .symmetric(horizontal: 16),
            itemCount: SocialStickerData.sliderEmojis.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final choice = SocialStickerData.sliderEmojis[index];
              return SizedBox.square(
                dimension: 64,
                child: StickerChoiceTile(
                  semanticLabel: choice,
                  selected: choice == emoji,
                  onTap: () => context
                      .read<SocialStickerCubit>()
                      .sliderEmojiPicked(choice),
                  child: Text(
                    choice,
                    style: VineTheme.titleLargeFont(
                      color: context.vineColors.primaryText,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              );
            },
          ),
        ),
        StickerSheetNote(text: context.l10n.videoEditorSocialStickerSliderNote),
      ],
    );
  }
}
