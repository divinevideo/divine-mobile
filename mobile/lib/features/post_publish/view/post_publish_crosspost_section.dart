// ABOUTME: Crossposting prompt above the post-publish confirmation's buttons:
// ABOUTME: crosspost this video, set crossposting up, reconnect, or a note.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/features/post_publish/cubit/post_publish_crosspost_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

/// Renders the [PostPublishCrosspostCubit]'s prompt.
///
/// Deliberately recessive — a neutral card with a small secondary button — so
/// it keeps View and Share as the primary actions.
class PostPublishCrosspostSection extends StatelessWidget {
  const PostPublishCrosspostSection({
    required this.onCrosspost,
    required this.onSetUp,
    required this.onReconnect,
    super.key,
  });

  /// Opens the crosspost flow for the just-published video, offering
  /// [connections].
  final ValueChanged<List<CrosspostingConnection>> onCrosspost;

  /// Opens crossposting setup.
  final VoidCallback onSetUp;

  /// Opens crossposting setup to reconnect a lapsed platform.
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PostPublishCrosspostCubit>().state;
    final l10n = context.l10n;
    final names = state.platforms
        .map((platform) => platform.displayName)
        .join(', ');

    void tapped(VoidCallback action) {
      unawaited(context.read<PostPublishCrosspostCubit>().recordTap());
      action();
    }

    return switch (state.prompt) {
      PostPublishCrosspostPrompt.loading ||
      PostPublishCrosspostPrompt.none => const SizedBox.shrink(),
      PostPublishCrosspostPrompt.automatic => _PromptCard(
        message: l10n.postPublishCrosspostAutomatic(names),
      ),
      PostPublishCrosspostPrompt.crosspost => _PromptCard(
        message: l10n.postPublishCrosspostSuggest(names),
        action: (
          label: l10n.crosspostSubmit,
          onPressed: () => tapped(() => onCrosspost(state.connections)),
        ),
      ),
      PostPublishCrosspostPrompt.setUp => _PromptCard(
        message: l10n.postPublishCrosspostSetUp(names),
        action: (
          label: l10n.crosspostingBenefitConnect(names),
          onPressed: () => tapped(onSetUp),
        ),
      ),
      PostPublishCrosspostPrompt.reconnect => _PromptCard(
        message: state.platforms
            .map(
              (platform) => l10n.crosspostReconnectPrompt(platform.displayName),
            )
            .join('\n'),
        action: (
          label: l10n.crosspostReconnect,
          onPressed: () => tapped(onReconnect),
        ),
      ),
    };
  }
}

/// The card every prompt renders, so the automatic note and the calls to
/// action keep one look.
class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.message, this.action});

  final String message;

  /// The call to action; null for the automatic note, which asks nothing.
  final ({String label, VoidCallback onPressed})? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: DivineInfoCard(
        icon: DivineIconName.arrowsClockwise,
        tone: DivineInfoCardTone.neutral,
        compact: true,
        message: message,
        footer: action == null
            ? null
            : DivineButton(
                label: action.label,
                type: DivineButtonType.secondary,
                size: DivineButtonSize.small,
                expanded: true,
                onPressed: action.onPressed,
              ),
      ),
    );
  }
}
