import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/user_not_available_screen.dart';
import 'package:openvine/utils/npub_hex.dart';

/// Router widget that applies blockee-side visibility before showing a profile.
class OtherProfileScreenRouter extends ConsumerWidget {
  const OtherProfileScreenRouter({
    required this.npub,
    super.key,
    this.displayNameHint,
    this.avatarUrlHint,
  });

  final String npub;
  final String? displayNameHint;
  final String? avatarUrlHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(blocklistVersionProvider);
    final targetHex = npubToHexOrNull(npub);

    // If this user has blocked or muted us, show unavailable. Blocks now
    // travel on the kind 10000 mute list (#5462), so gating on the legacy
    // kind 30000 signal alone would miss every block published since.
    if (targetHex != null) {
      final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
      if (blocklistRepository.hasMutedUs(targetHex) ||
          blocklistRepository.hasBlockedUs(targetHex)) {
        return UserNotAvailableScreen(
          onBack: context.safePop,
          userIdHex: targetHex,
        );
      }
    }

    return OtherProfileScreen(
      npub: npub,
      displayNameHint: displayNameHint,
      avatarUrlHint: avatarUrlHint,
    );
  }
}
