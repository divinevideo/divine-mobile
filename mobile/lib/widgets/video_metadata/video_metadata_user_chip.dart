// ABOUTME: Reusable chip widget for displaying user info in video metadata
// ABOUTME: Shows avatar, display name with optional remove button
// ABOUTME: Used by collaborators and inspired-by inputs

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// A chip displaying a user's avatar and name, with an optional remove button.
///
/// Supports both hex pubkeys and npub formats. Automatically fetches the
/// user profile for display.
class VideoMetadataUserChip extends ConsumerWidget {
  /// Creates a user chip with a hex pubkey.
  const VideoMetadataUserChip.fromPubkey({
    required String pubkey,
    this.onRemove,
    this.isLoading = false,
    this.removeLabel,
    super.key,
  }) : _pubkey = pubkey,
       _npub = null;

  /// Creates a user chip with an npub (converts to hex internally).
  const VideoMetadataUserChip.fromNpub({
    required String npub,
    this.onRemove,
    this.isLoading = false,
    this.removeLabel,
    super.key,
  }) : _npub = npub,
       _pubkey = null;

  final String? _pubkey;
  final String? _npub;

  /// Callback when the remove button is tapped. If null, no remove button
  /// is shown.
  final VoidCallback? onRemove;

  /// Whether this chip is in a loading/pending state.
  final bool isLoading;

  /// Accessibility label for the remove button.
  final String? removeLabel;

  String get _hexPubkey {
    if (_pubkey != null) return _pubkey;
    return NostrKeyUtils.decode(_npub!);
  }

  /// Fallback display text when profile is not loaded.
  String get _fallbackDisplay {
    // For npub, show truncated npub (UI truncation via ellipsis handles this)
    if (_npub != null) return _npub;
    // For hex pubkey, show full pubkey (UI truncation handles display)
    return _pubkey!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(_hexPubkey));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0B2A20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          UserAvatar(
            imageUrl: profileAsync.value?.picture,
            name: profileAsync.value?.bestDisplayName,
            size: 24,
          ),
          Flexible(
            child: Text(
              profileAsync.value?.bestDisplayName ?? _fallbackDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.titleSmallFont(color: VineTheme.whiteText),
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: DivineCircularProgressIndicator(
                strokeWidth: 2,
                color: context.vineColors.onSurfaceMuted,
              ),
            )
          else if (onRemove != null)
            Semantics(
              label:
                  removeLabel ?? context.l10n.videoMetadataRemoveSemanticLabel,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: SvgPicture.asset(
                    DivineIconName.x.assetPath,
                    colorFilter: ColorFilter.mode(
                      context.vineColors.onSurfaceMuted,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
