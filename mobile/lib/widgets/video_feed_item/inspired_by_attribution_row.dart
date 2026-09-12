// ABOUTME: Inspired-by attribution row widget for displaying inspiration credit
// ABOUTME: on video feed items. Shows "Inspired by @DisplayName" with tap
// ABOUTME: navigation to the inspiring creator's profile.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:unified_logger/unified_logger.dart';

/// A tappable row showing inspired-by attribution on a video feed item.
///
/// Displays "Inspired by @DisplayName" when a video references another
/// creator's work via an `a` tag (NIP-33 addressable event) or an npub
/// reference in the content.
///
/// Tapping navigates to the inspiring creator's profile.
/// Shows nothing if the video has no inspired-by attribution.
class InspiredByAttributionRow extends ConsumerWidget {
  /// Creates an InspiredByAttributionRow.
  ///
  /// [video] must have [VideoEvent.hasInspiredBy] return true for this
  /// widget to display anything.
  const InspiredByAttributionRow({
    required this.video,
    required this.isActive,
    super.key,
  });

  /// The video event to display inspired-by attribution for.
  final VideoEvent video;

  /// Whether this video feed item is currently active (visible/playing).
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasInspiredBy) {
      return const SizedBox.shrink();
    }

    final creatorPubkeys = _resolveCreatorPubkeys();
    if (creatorPubkeys.isEmpty) {
      return const SizedBox.shrink();
    }

    return _InspiredByContent(
      creatorPubkeys: creatorPubkeys,
      isActive: isActive,
    );
  }

  /// Resolve creator pubkeys from explicit inspired-by metadata and factual
  /// clip credits without hiding either source of attribution.
  List<String> _resolveCreatorPubkeys() {
    final pubkeys = <String>[];
    final seen = <String>{};

    void addPubkey(String pubkey) {
      final trimmed = pubkey.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        pubkeys.add(trimmed);
      }
    }

    if (video.inspiredByVideo != null) {
      addPubkey(video.inspiredByVideo!.creatorPubkey);
    }
    if (video.inspiredByNpub != null) {
      try {
        addPubkey(NostrKeyUtils.decode(video.inspiredByNpub!));
      } catch (e) {
        Log.warning(
          'Failed to decode inspiredByNpub '
          '${pubkeyForLogs(video.inspiredByNpub)}: $e',
          name: 'InspiredByAttributionRow',
          category: LogCategory.ui,
        );
      }
    }
    // Every creator credited by an inspired-by p-tag. The content line names
    // only the first, so without these the second and later picks would be
    // published and notified but never shown.
    video.inspiredByPubkeys.forEach(addPubkey);
    for (final credit in video.clipSourceCredits) {
      addPubkey(credit.authorPubkey);
    }
    return pubkeys;
  }
}

/// The actual content showing inspired-by attribution.
class _InspiredByContent extends ConsumerWidget {
  const _InspiredByContent({
    required this.creatorPubkeys,
    required this.isActive,
  });

  final List<String> creatorPubkeys;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorPubkey = creatorPubkeys.first;
    final creatorProfile = ref
        .watch(userProfileReactiveProvider(creatorPubkey))
        .value;

    final creatorName =
        creatorProfile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(creatorPubkey);
    // The extra-creator count is part of the localized sentence rather than
    // concatenated onto the name, so a translator can place it — appending it
    // in Dart puts it on the wrong side in RTL locales.
    final extraCreatorCount = creatorPubkeys.length - 1;
    final attribution = extraCreatorCount == 0
        ? context.l10n.videoInspiredByAttribution(creatorName)
        : context.l10n.videoInspiredByAttributionMultiple(
            creatorName,
            extraCreatorCount,
          );
    final semanticLabel = extraCreatorCount == 0
        ? context.l10n.inspiredByAttributionSemanticLabel(creatorName)
        : context.l10n.inspiredByAttributionMultipleSemanticLabel(
            creatorName,
            extraCreatorCount,
          );

    return GestureDetector(
      onTap: () => _navigateToCreatorProfile(context),
      child: Semantics(
        identifier: 'inspired_by_attribution_row',
        button: true,
        label: semanticLabel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DivineIcon(
                icon: DivineIconName.sparkle,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  attribution,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const DivineIcon(
                icon: DivineIconName.caretRight,
                size: 14,
                color: VineTheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreatorProfile(BuildContext context) {
    final creatorPubkey = creatorPubkeys.first;
    Log.info(
      'Navigating to inspired-by creator profile: ${pubkeyForLogs(creatorPubkey)}',
      name: 'InspiredByAttributionRow',
      category: LogCategory.ui,
    );

    final npub = normalizeToNpub(creatorPubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}
