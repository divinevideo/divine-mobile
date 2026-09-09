// ABOUTME: Horizontal slider showing top classic Viners (most loops)
// ABOUTME: Displays circular avatars with names, tappable to view profile

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

/// Horizontal slider displaying top classic Viners sorted by loop count.
///
/// Shows circular avatars with display names. Tapping navigates to profile.
class ClassicVinersSlider extends ConsumerWidget {
  const ClassicVinersSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vinersAsync = ref.watch(topClassicVinersProvider);

    return Container(
      padding: const EdgeInsets.only(top: 16),
      color: context.vineColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.star,
                  color: context.vineColors.accentPositive,
                  size: DivineIcon.scaleSize(context, 20),
                ),
                Text(
                  context.l10n.classicVinersTitle,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: vinersAsync.when(
              data: (viners) {
                if (viners.isEmpty) {
                  return const _VinersLoadingPlaceholder();
                }
                return _VinerAvatarList(viners: viners);
              },
              loading: () => const _VinersLoadingPlaceholder(),
              error: (_, _) => const _VinersLoadingPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder shown while Viners are loading.
class _VinersLoadingPlaceholder extends StatelessWidget {
  const _VinersLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.vineColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: context.vineColors.card,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal scrollable list of Viner avatars.
class _VinerAvatarList extends StatelessWidget {
  const _VinerAvatarList({required this.viners});

  final List<ClassicViner> viners;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.classicVinersRow,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: viners.length,
        itemBuilder: (context, index) {
          final viner = viners[index];
          return _VinerAvatar(viner: viner);
        },
      ),
    );
  }
}

/// Individual Viner avatar with name and loop count.
class _VinerAvatar extends ConsumerWidget {
  const _VinerAvatar({required this.viner});

  final ClassicViner viner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use authorName from classic Vine data, clean up social media prefixes
    final rawName =
        viner.authorName ?? UserProfile.defaultDisplayNameFor(viner.pubkey);
    final displayName = _cleanDisplayName(rawName);

    // Get avatar URL: try REST API first, then fallback to Nostr profile
    final profile = ref.watch(userProfileReactiveProvider(viner.pubkey)).value;
    final avatarUrl = viner.authorAvatar ?? profile?.picture;

    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Semantics(
        label: context.l10n.classicVinersViewProfileSemanticLabel(displayName),
        button: true,
        child: GestureDetector(
          onTap: () => _onTap(context, avatarUrl),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with rounded square
                SizedBox(
                  width: 56,
                  height: 56,
                  child: UserAvatar(
                    imageUrl: avatarUrl,
                    name: displayName,
                    placeholderSeed: viner.pubkey,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 4),
                // Display name from classic Vine data
                SizedBox(
                  width: 70,
                  child: Text(
                    displayName,
                    style: VineTheme.titleTinyFont(
                      color: context.vineColors.primaryText,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clean up social media prefixes from display names.
  ///
  /// Strips prefixes like "IG:", "instagram:", "@ig", "@instagram", etc.
  /// so users see the actual username instead of platform references.
  String _cleanDisplayName(String name) {
    var cleaned = name.trim();

    // Patterns to remove (case-insensitive)
    final prefixes = [
      RegExp(r'^IG:\s*', caseSensitive: false),
      RegExp(r'^instagram:\s*', caseSensitive: false),
      RegExp(r'^@ig\s+', caseSensitive: false),
      RegExp(r'^@instagram\s+', caseSensitive: false),
      RegExp(r'^ig:\s*', caseSensitive: false),
      RegExp(r'^twitter:\s*', caseSensitive: false),
      RegExp(r'^@twitter\s+', caseSensitive: false),
      RegExp(r'^tw:\s*', caseSensitive: false),
      RegExp(r'^snapchat:\s*', caseSensitive: false),
      RegExp(r'^sc:\s*', caseSensitive: false),
      RegExp(r'^tiktok:\s*', caseSensitive: false),
      RegExp(r'^tt:\s*', caseSensitive: false),
      RegExp(r'^yt:\s*', caseSensitive: false),
      RegExp(r'^youtube:\s*', caseSensitive: false),
    ];

    for (final prefix in prefixes) {
      cleaned = cleaned.replaceFirst(prefix, '');
    }

    // Also strip leading @ if the whole name is just @username
    if (cleaned.startsWith('@') && !cleaned.substring(1).contains('@')) {
      cleaned = cleaned.substring(1);
    }

    return cleaned.trim();
  }

  Future<void> _onTap(BuildContext context, String? avatarUrl) async {
    // Get current user's hex for normalization if needed
    final identifier = viner.pubkey;
    final container = ProviderScope.containerOf(context, listen: false);
    final authService = container.read(authServiceProvider);
    final currentUserHex = authService.currentPublicKeyHex;

    // Normalize any format (npub/nprofile/hex) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't push
      Log.warning(
        '⚠️ Invalid public identifier: $identifier',
        name: 'ClassicVinersSlider',
        category: LogCategory.ui,
      );
      return;
    }

    // Handle 'me' special case - redirect to own profile tab instead
    if (identifier == 'me') {
      return context.go(
        buildRoute(RouteContext(type: RouteType.profile, npub: npub)),
      );
    }

    // Pass profile hints via extra for users without Kind 0 profiles
    // Use avatarUrl which includes Nostr profile fallback
    final extra = <String, String?>{};
    final authorName = viner.authorName;

    if (authorName != null) extra['displayName'] = authorName;
    if (avatarUrl != null) extra['avatarUrl'] = avatarUrl;

    await context.push(
      OtherProfileScreen.pathForNpub(npub),
      extra: extra.isEmpty ? null : extra,
    );
  }
}
