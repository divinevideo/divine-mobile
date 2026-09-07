// ABOUTME: Shared autocomplete overlay for @mentions in text inputs
// ABOUTME: Shows account suggestions and their verified identifiers

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/mentions/mention_suggestion.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

@immutable
/// Overlay widget showing mention suggestions near a text input.
class MentionOverlay extends ConsumerWidget {
  const MentionOverlay({
    required this.suggestions,
    required this.onSelect,
    this.canSelect,
    super.key,
  });

  /// List of mention suggestions to display.
  final List<MentionSuggestion> suggestions;

  /// Optional predicate used to disable suggestions that cannot be inserted.
  final bool Function(String displayName)? canSelect;

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
              canSelect: canSelect,
              onSelect: (displayName) =>
                  onSelect(suggestions[index].pubkey, displayName),
            );
          },
        ),
      ),
    );
  }
}

class _MentionSuggestionItem extends ConsumerWidget {
  const _MentionSuggestionItem({
    required this.suggestion,
    required this.onSelect,
    this.canSelect,
  });

  final MentionSuggestion suggestion;
  final void Function(String displayName) onSelect;
  final bool Function(String displayName)? canSelect;

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
    // Sanitized rather than swapped for bestDisplayName: that getter
    // substitutes a generated name for a profile with no name at all, which
    // would shadow the npub fallback.
    final selectionName = rawDisplayName == null
        ? npub
        : UserProfile.sanitizeDisplayName(rawDisplayName);
    final enabled = canSelect?.call(selectionName) ?? true;

    return InkWell(
      onTap: enabled ? () => onSelect(selectionName) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
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
