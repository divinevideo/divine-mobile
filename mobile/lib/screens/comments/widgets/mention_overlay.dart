// ABOUTME: Autocomplete overlay for @mentions in comment input
// ABOUTME: Shows user suggestions from comment participants

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

@immutable
class MentionNip05Claim {
  const MentionNip05Claim({required this.pubkey, required this.nip05});

  final String pubkey;
  final String nip05;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentionNip05Claim &&
          runtimeType == other.runtimeType &&
          pubkey == other.pubkey &&
          nip05 == other.nip05;

  @override
  int get hashCode => Object.hash(pubkey, nip05);
}

// Riverpod's family builder preserves its full generic type when inferred.
// ignore: specify_nonobvious_property_types
final mentionNip05VerificationProvider =
    FutureProvider.family<Nip05VerificationStatus, MentionNip05Claim>((
      ref,
      claim,
    ) {
      final service = ref.watch(nip05VerificationServiceProvider);
      return service.getVerificationStatus(claim.pubkey, claim.nip05);
    });

/// Overlay widget showing mention suggestions above the comment input.
class MentionOverlay extends ConsumerWidget {
  const MentionOverlay({
    required this.suggestions,
    required this.onSelect,
    super.key,
  });

  /// List of mention suggestions to display.
  final List<MentionSuggestion> suggestions;

  /// Callback when a suggestion is selected. Returns (hex pubkey, displayName).
  final void Function(String pubkey, String displayName) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            return _MentionSuggestionItem(
              suggestion: suggestions[index],
              onTap: () {
                final suggestion = suggestions[index];
                final npub = NostrKeyUtils.encodePubKey(suggestion.pubkey);
                // Use displayName from BLoC search results, fall back to
                // cached profile lookup, then npub as last resort
                final cachedProfile = ref
                    .read(userProfileReactiveProvider(suggestion.pubkey))
                    .value;
                // Sanitized rather than swapped for bestDisplayName: that
                // getter substitutes a generated name for a profile with no
                // name at all, which would shadow the npub fallback below.
                final resolvedName =
                    suggestion.displayName ??
                    cachedProfile?.displayName ??
                    cachedProfile?.name;
                final displayName = resolvedName == null
                    ? npub
                    : UserProfile.sanitizeDisplayName(resolvedName);
                onSelect(suggestion.pubkey, displayName);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MentionSuggestionItem extends ConsumerWidget {
  const _MentionSuggestionItem({required this.suggestion, required this.onTap});

  final MentionSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(suggestion.pubkey))
        .value;

    final rawDisplayName =
        suggestion.displayName ?? profile?.displayName ?? profile?.name;
    final displayName = rawDisplayName == null
        ? null
        : UserProfile.sanitizeDisplayName(rawDisplayName);
    final picture = suggestion.picture ?? profile?.picture;
    final rawNip05 = suggestion.nip05 ?? profile?.nip05;
    final displayNip05 = _displayNip05(rawNip05);
    final verificationStatus = rawNip05 != null && rawNip05.isNotEmpty
        ? ref
              .watch(
                mentionNip05VerificationProvider(
                  MentionNip05Claim(pubkey: suggestion.pubkey, nip05: rawNip05),
                ),
              )
              .whenOrNull(data: (status) => status)
        : null;
    final npub = NostrKeyUtils.encodePubKey(suggestion.pubkey);
    final identifier =
        verificationStatus == Nip05VerificationStatus.verified &&
            displayNip05 != null
        ? displayNip05
        : npub;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 10,
          children: [
            UserAvatar(
              size: 32,
              imageUrl: picture,
              name: displayName,
              placeholderSeed: suggestion.pubkey,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName != null)
                    Text(
                      displayName,
                      style: VineTheme.labelLargeFont(
                        color: context.vineColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    identifier,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // UI truncation only
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors [UserProfile.shortDisplayNip05], including its sanitization: the
/// result is rendered directly, and `nip05` is an unverified kind-0 field.
String? _displayNip05(String? nip05) {
  if (nip05 == null || nip05.isEmpty) return null;
  if (nip05.startsWith('_@')) {
    final stripped = nip05.substring(1);
    final match = RegExp(
      r'^@([a-z0-9\-_.]+)\.divine\.video$',
    ).firstMatch(stripped);
    return UserProfile.sanitizeDisplayName(
      match != null ? '@${match.group(1)}' : stripped,
    );
  }

  if (nip05.endsWith('@divine.video') || nip05.endsWith('@openvine.co')) {
    return '@${UserProfile.sanitizeDisplayName(nip05.split('@')[0])}';
  }

  return UserProfile.sanitizeDisplayName(nip05);
}
