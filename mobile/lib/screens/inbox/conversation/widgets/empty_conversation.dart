// ABOUTME: Empty conversation state showing participant profile card.
// ABOUTME: Matches Figma "new message" component with avatar, name, NIP-05,
// ABOUTME: and "View profile" button.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/moderation_presentation.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Profile card shown when a conversation has no messages yet.
///
/// Displays a large avatar, display name, optional NIP-05 identifier,
/// and a "View profile" button.
class EmptyConversation extends StatelessWidget {
  const EmptyConversation({
    required this.displayName,
    required this.pubkey,
    required this.moderation,
    this.imageUrl,
    this.nip05,
    this.onViewProfile,
    this.mayBeIncomplete = false,
    this.isIdentityResolving = false,
    super.key,
  });

  final String displayName;
  final String pubkey;

  /// How [pubkey] is presented, resolved by the caller together with
  /// [displayName] so the artwork cannot present a key more officially than its
  /// name does (#9963).
  final ModerationPresentation moderation;
  final String? imageUrl;
  final String? nip05;
  final VoidCallback? onViewProfile;

  /// Whether DM history recovery might still owe this thread messages.
  ///
  /// `watchMessages` is a local DB projection, so a thread whose gift wraps
  /// have not arrived or decrypted yet reaches `loaded` with zero rows and is
  /// indistinguishable from a genuinely new conversation. When recovery is in
  /// flight — or stopped short of completing — this card adds a qualifying
  /// line instead of silently asserting the conversation is empty.
  final bool mayBeIncomplete;

  /// Whether the participant avatar and name should use the identity loading
  /// treatment while their profile is being resolved.
  final bool isIdentityResolving;

  @override
  Widget build(BuildContext context) {
    final avatar = dmPeerAvatar(
      isVanished: false,
      moderation: moderation,
      pictureUrl: imageUrl,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
      child: Column(
        children: [
          // Avatar
          Semantics(
            label: isIdentityResolving ? context.l10n.commonLoading : null,
            child: IdentitySkeletonizer(
              isLoading: isIdentityResolving,
              excludeSemantics: true,
              child: UserAvatar(
                imageUrl: avatar.imageUrl,
                name: displayName,
                placeholderSeed: pubkey,
                size: 96,
                contentOverride: avatar.contentOverride,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // User info
          IdentitySkeletonizer(
            isLoading: isIdentityResolving,
            excludeSemantics: true,
            child: Text(
              displayName,
              style: VineTheme.titleLargeFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (nip05 != null && nip05!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              nip05!,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          // View profile button
          _ViewProfileButton(onTap: onViewProfile),
          if (mayBeIncomplete) ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.conversationRestorePausedTitle,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewProfileButton extends StatelessWidget {
  const _ViewProfileButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    if (onTap == null) return const SizedBox.shrink();

    return Semantics(
      // No `label:` — it rides up from the child Text below, so it cannot
      // drift from the rendered string.
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            border: Border.all(
              color: context.vineColors.outlineMuted,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            context.l10n.inboxConversationViewProfileButton,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        ),
      ),
    );
  }
}
