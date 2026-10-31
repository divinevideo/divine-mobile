// ABOUTME: Full-screen answer to a question sticker: the creator and what they
// ABOUTME: ask, the viewer's answer, and the button that sends it privately.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/question_answer/question_answer_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/question_answer_target.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Where a viewer answers the question sticker [target] names, in a private
/// message to the video's creator.
class QuestionAnswerScreen extends ConsumerWidget {
  const QuestionAnswerScreen({required this.target, super.key});

  /// The route's name.
  static const routeName = 'question-answer';

  /// The route's path.
  static const String path = RoutePaths.questionAnswer;

  final QuestionAnswerTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    return BlocProvider(
      // Another account sends from its own messages.
      key: ValueKey(dmRepository),
      create: (_) =>
          QuestionAnswerCubit(dmRepository: dmRepository, target: target),
      child: QuestionAnswerView(target: target),
    );
  }
}

/// The answer as the viewer writes it.
class QuestionAnswerView extends ConsumerStatefulWidget {
  @visibleForTesting
  const QuestionAnswerView({required this.target, super.key});

  final QuestionAnswerTarget target;

  @override
  ConsumerState<QuestionAnswerView> createState() => _QuestionAnswerViewState();
}

class _QuestionAnswerViewState extends ConsumerState<QuestionAnswerView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() => context.read<QuestionAnswerCubit>().submit(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final pubkey = widget.target.creatorPubkey;
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final name =
        profile?.bestDisplayName ?? UserProfile.generatedNameFor(pubkey);
    return BlocListener<QuestionAnswerCubit, QuestionAnswerState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final message = switch (state.status) {
          QuestionAnswerStatus.sent => l10n.videoStickerQuestionAnswerSent,
          QuestionAnswerStatus.tooLong =>
            l10n.videoStickerQuestionAnswerTooLong,
          QuestionAnswerStatus.failed => l10n.videoStickerQuestionAnswerFailed,
          _ => null,
        };
        if (message != null) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(DivineSnackbarContainer.snackBar(message));
        }
        // Opened from a link, there is no feed beneath to go back to.
        if (state.status == QuestionAnswerStatus.sent) context.safePop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: DiVineAppBar(
          title: l10n.videoStickerQuestionAnswerTitle,
          showBackButton: true,
          onBackPressed: () => context.safePop(),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const .all(16),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    spacing: 16,
                    children: [
                      Row(
                        spacing: 12,
                        children: [
                          UserAvatar(
                            imageUrl: profile?.picture,
                            name: name,
                            size: 40,
                            placeholderSeed: pubkey,
                          ),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: VineTheme.titleMediumFont(
                                color: colors.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const .all(20),
                          child: Text(
                            widget.target.question,
                            textAlign: .center,
                            style: VineTheme.titleLargeFont(
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                      ),
                      DivineTextField(
                        controller: _controller,
                        filled: true,
                        autofocus: true,
                        labelText: l10n.videoStickerQuestionAnswerFieldLabel,
                        maxLength: QuestionAnswerCubit.maxAnswerLength,
                        minLines: 3,
                        maxLines: 6,
                        keyboardType: .multiline,
                        textInputAction: .newline,
                        onChanged: (_) => setState(() {}),
                      ),
                      Text(
                        l10n.videoStickerQuestionAnswerPrivacyNote(name),
                        style: VineTheme.bodySmallFont(
                          color: colors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const .all(16),
                child: _SendButton(
                  canSend: _controller.text.trim().isNotEmpty,
                  onSend: _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sends the answer, once there is one, and shows while it is on its way.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.canSend, required this.onSend});

  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isSending = context.select(
      (QuestionAnswerCubit cubit) =>
          cubit.state.status == QuestionAnswerStatus.sending,
    );
    return DivineButton(
      label: context.l10n.videoStickerQuestionAnswerSend,
      expanded: true,
      isLoading: isSending,
      onPressed: canSend && !isSending ? onSend : null,
    );
  }
}
