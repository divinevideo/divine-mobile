// ABOUTME: A Lists-inspired community badge card with artwork and people previews.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/config/badge_issuers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/dead_image_hosts.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

/// Width-to-height ratio of badge artwork in the community gallery.
const double badgeArtworkAspectRatio = 177 / 120;

/// A single accessible target opening the badge's people and videos.
class BadgeCommunityCard extends ConsumerWidget {
  const BadgeCommunityCard({
    required this.definition,
    required this.onTap,
    this.memberPubkeys = const [],
    super.key,
  });

  final Nip58BadgeDefinition definition;
  final VoidCallback onTap;
  final List<String> memberPubkeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuer = definition.event.pubkey;
    final isOfficial = issuer == kDivineBadgeIssuerPubkey;
    final l10n = context.l10n;
    final suppliedName = definition.name;
    final identifier = sanitizeUtf16(definition.dTag);
    final name = suppliedName != null && suppliedName.trim().isNotEmpty
        ? suppliedName
        : identifier.trim().isNotEmpty
        ? identifier
        : context.l10n.profileBadgeFallbackSemanticLabel;
    final issuerProfile = ref.watch(userProfileReactiveProvider(issuer)).value;
    final issuerName =
        issuerProfile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(issuer);
    final members = [
      for (final pubkey in memberPubkeys.take(
        BadgeRepository.holderPreviewLimit,
      ))
        if (!ref.watch(profileVanishedProvider(pubkey))) pubkey,
    ];
    final image = [
      definition.imageUrl,
      ...definition.thumbnails,
    ].whereType<String>().where(isUsableNetworkImageUrl).firstOrNull;
    final fallback = _BadgeMonogram(name: name);
    return Semantics(
      // The issuer goes in the label: Android reads a value before the label.
      label: isOfficial
          ? l10n.badgeDiscoveryOfficialCardLabel(
              name,
              issuerName,
              l10n.badgeOfficialLabel,
            )
          : l10n.badgeDiscoveryCardLabel(name, issuerName),
      hint: definition.description,
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: badgeArtworkAspectRatio,
                  child: ColoredBox(
                    color: context.vineColors.surfaceContainerHigh,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image == null)
                          fallback
                        else
                          LayoutBuilder(
                            builder: (context, constraints) => VineCachedImage(
                              imageUrl: image,
                              fit: BoxFit.contain,
                              resizePolicy: ResizeImagePolicy.fit,
                              memCacheWidth:
                                  (constraints.maxWidth *
                                          MediaQuery.devicePixelRatioOf(
                                            context,
                                          ))
                                      .ceil()
                                      .clamp(1, 1024),
                              memCacheHeight:
                                  (constraints.maxHeight *
                                          MediaQuery.devicePixelRatioOf(
                                            context,
                                          ))
                                      .ceil()
                                      .clamp(1, 1024),
                              placeholder: (_, _) => fallback,
                              errorWidget: (_, _, _) => fallback,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                            ),
                          ),
                        if (members.isNotEmpty)
                          PositionedDirectional(
                            end: 8,
                            bottom: 8,
                            child: Row(
                              spacing: 4,
                              children: [
                                for (final pubkey in members)
                                  _MemberFace(pubkey: pubkey),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.titleSmallFont(
                  color: context.vineColors.onSurface,
                ),
              ),
              if (definition.description case final description?
                  when description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                spacing: 6,
                children: [
                  UserAvatar(
                    size: 20,
                    imageUrl: issuerProfile?.picture,
                    name: issuerName,
                    placeholderSeed: issuer,
                  ),
                  Expanded(
                    child: Text(
                      issuerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (isOfficial)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.badgeOfficialLabel,
                    style: VineTheme.labelSmallFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeMonogram extends StatelessWidget {
  const _BadgeMonogram({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: .48,
      heightFactor: .7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(color: context.vineColors.outline),
        ),
        child: Center(
          child: Text(
            name.trim().characters.firstOrNull?.toUpperCase() ?? '',
            style: VineTheme.headlineLargeFont(
              color: context.vineColors.onSurface,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MemberFace extends ConsumerWidget {
  const _MemberFace({required this.pubkey});
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    return UserAvatar(
      size: 28,
      imageUrl: profile?.picture,
      name: profile?.bestDisplayName,
      placeholderSeed: pubkey,
    );
  }
}
