// ABOUTME: Crossposting prompt under the post-publish confirmation's buttons:
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
/// it sits below View and Share without competing with them.
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
      PostPublishCrosspostPrompt.automatic => DivineInfoCard(
        icon: DivineIconName.arrowsClockwise,
        tone: DivineInfoCardTone.neutral,
        compact: true,
        message: l10n.postPublishCrosspostAutomatic(names),
      ),
      PostPublishCrosspostPrompt.crosspost => _PromptCard(
        message: l10n.postPublishCrosspostSuggest(names),
        actionLabel: l10n.crosspostSubmit,
        onAction: () => tapped(() => onCrosspost(state.connections)),
      ),
      PostPublishCrosspostPrompt.setUp => _PromptCard(
        message: l10n.postPublishCrosspostSetUp(names),
        actionLabel: l10n.crosspostingBenefitConnect(names),
        onAction: () => tapped(onSetUp),
      ),
      PostPublishCrosspostPrompt.reconnect => _PromptCard(
        message: l10n.crosspostReconnectPrompt(names),
        actionLabel: l10n.crosspostReconnect,
        onAction: () => tapped(onReconnect),
      ),
    };
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return DivineInfoCard(
      icon: DivineIconName.arrowsClockwise,
      tone: DivineInfoCardTone.neutral,
      compact: true,
      message: message,
      footer: DivineButton(
        label: actionLabel,
        type: DivineButtonType.secondary,
        size: DivineButtonSize.small,
        expanded: true,
        onPressed: onAction,
      ),
    );
  }
}
