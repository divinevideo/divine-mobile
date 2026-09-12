// ABOUTME: Video overlay action that opens the "Help classify this" sheet.
// ABOUTME: Lets a viewer suggest content-warning labels for a video (#4771).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/community_content_label_provider.dart';
import 'package:openvine/widgets/community_suggest/community_suggest_sheet.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Overlay action that opens the community content-warning suggestion sheet.
///
/// Renders nothing until the signer-backed repository and the viewer's pubkey
/// are ready, so it never captures a pre-auth client.
class HelpClassifyActionButton extends ConsumerWidget {
  /// Creates the action button for [video].
  const HelpClassifyActionButton({
    required this.video,
    this.onInteracted,
    super.key,
  });

  /// The video the viewer may suggest content warnings for.
  final VideoEvent video;

  /// Invoked before the sheet opens (e.g. to pause auto-advance).
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reactive read: the flag is user-flippable at runtime via Settings ->
    // Experimental Features, so the button must follow live toggles.
    final flagEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.communityContentWarnings),
    );
    if (!flagEnabled) return const SizedBox.shrink();

    final repository = ref.watch(communityContentLabelRepositoryProvider);
    final myPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    if (repository == null || myPubkey == null || myPubkey.isEmpty) {
      return const SizedBox.shrink();
    }

    return VideoActionButton(
      icon: DivineIconName.sealWarning,
      semanticIdentifier: 'help_classify_button',
      semanticLabel: context.l10n.communitySuggestTitle,
      labelWhenZero: context.l10n.communitySuggestActionLabel,
      onPressed: () {
        onInteracted?.call();
        CommunitySuggestSheet.show(
          context,
          video: video,
          repository: repository,
          myPubkey: myPubkey,
        );
      },
    );
  }
}
