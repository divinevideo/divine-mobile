// ABOUTME: Reusable rounded-square avatar with shared Figma-matched geometry
// ABOUTME: Supports network images, local image providers, and generated accent placeholders

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/blocs/avatar_svg/avatar_svg_cubit.dart';
import 'package:openvine/providers/avatar_svg_repository_provider.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';
import 'package:openvine/utils/dead_image_hosts.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

enum UserAvatarPlaceholderTone {
  auto,
  yellow,
  lime,
  pink,
  orange,
  violet,
  purple,
  blue,
}

/// The tone [UserAvatar] picks for [seed], so a surface that draws its own
/// placeholder (the list-card member collage) gives the same person the
/// same accent everywhere. An empty seed lands on the first tone.
UserAvatarPlaceholderTone userAvatarToneForSeed(String seed) =>
    _Placeholder.toneForSeed(seed);

/// The fill and figure ink [UserAvatar] pairs for [tone].
///
/// The ink is chosen per accent for contrast — a white figure on the lime
/// fill measures 1.16:1 — so anything painting a glyph on one of these
/// accents should take the figure color from here rather than using white.
({Color base, Color figure}) userAvatarPlaceholderColors(
  UserAvatarPlaceholderTone tone,
) {
  final palette = _Placeholder._palettes[tone] ?? _Placeholder._fallbackPalette;
  return (base: palette.base, figure: palette.figure);
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.imageProvider,
    this.name,
    this.size = 44,
    this.onTap,
    this.semanticLabel,
    this.placeholderTone = UserAvatarPlaceholderTone.auto,
    this.placeholderSeed,
    this.cornerRadius,
    this.contentOverride,
    this.avatarSvgRepository,
  });

  final String? imageUrl;
  final ImageProvider<Object>? imageProvider;
  final String? name;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final UserAvatarPlaceholderTone placeholderTone;

  /// Stable seed used to pick the placeholder tone. When non-empty this
  /// takes precedence over [name] / [imageUrl] / [semanticLabel] so the
  /// same user produces the same accent color across every surface
  /// (notifications, profile header, lists). Pass the user's pubkey.
  final String? placeholderSeed;

  /// Optional override for the avatar's corner radius. When null the radius
  /// is computed from [size] (see [_cornerRadius] default). Used by the
  /// profile avatar lightbox to render the maximized avatar at 112px
  /// instead of the size-derived default.
  final double? cornerRadius;

  /// Fixed artwork rendered in place of [imageUrl] / [imageProvider] and the
  /// generated placeholder, inside the shared avatar chrome (size, corner
  /// radius, border) so it still lines up with neighbouring avatars.
  ///
  /// For rows whose identity is known ahead of the network and whose remote
  /// picture cannot be trusted to render.
  final Widget? contentOverride;

  /// Corner radius of an avatar rendered at [size] without a [cornerRadius]
  /// override. Exposed so skeleton stand-ins can match avatar geometry
  /// without duplicating the ratio.
  static double cornerRadiusForSize(double size) =>
      size <= 24 ? size / 3 : math.min(size * 0.4, 56);

  /// Overrides the repository read from [avatarSvgRepositoryProvider], so a
  /// test can render an SVG avatar without a `ProviderScope`.
  @visibleForTesting
  final AvatarSvgRepository? avatarSvgRepository;

  @visibleForTesting
  static bool isSvgImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    final lower = url.toLowerCase();
    if (lower.endsWith('.svg')) return true;

    try {
      return Uri.parse(url).path.toLowerCase().endsWith('.svg');
    } on FormatException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(context),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cornerRadius),
                border: Border.all(
                  color: context.vineColors.disabled,
                  width: _borderWidth,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: semanticLabel ?? (name != null ? '$name avatar' : 'User avatar'),
      button: onTap != null,
      child: onTap == null
          ? avatar
          : GestureDetector(onTap: onTap, child: avatar),
    );
  }

  double get _cornerRadius => cornerRadius ?? cornerRadiusForSize(size);

  double get _borderWidth => size >= 120 ? 3 : 1;

  bool get _hasNetworkImage =>
      imageUrl != null &&
      imageUrl!.isNotEmpty &&
      isUsableNetworkImageUrl(imageUrl!);

  bool get _isSvgImageUrl => isSvgImageUrl(imageUrl);

  Widget _buildPlaceholder() => _Placeholder(
    size: size,
    placeholderTone: placeholderTone,
    placeholderSeed: placeholderSeed,
    semanticLabel: semanticLabel,
    imageUrl: imageUrl,
    name: name,
  );

  /// Decode width for this avatar's slot, in device pixels.
  ///
  /// An avatar URL is an arbitrary user-supplied kind-0 `picture` at an
  /// arbitrary resolution, and the slot is usually 32-44pt. Without a hint
  /// Flutter decodes at the source's full resolution, so a 4000x3000 photo
  /// costs 48 MB of bitmap to fill 4 KB of pixels — and `SizedBox.square`
  /// above bounds layout, not decode. Height is deliberately left to
  /// [ResizeImage] so the aspect ratio survives.
  ///
  /// Returns null for a non-finite or non-positive [size], leaving the
  /// framework to decode at native resolution. A `double.infinity` slot
  /// (an avatar told to fill its cell) would otherwise reach
  /// `(size * dpr).ceil()`, which throws. Mirrors
  /// `_VideoThumbnailWidgetState._decodeWidth`.
  int? _decodeWidth(BuildContext context) {
    if (!size.isFinite || size <= 0) return null;
    return (size * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  Widget _buildContent(BuildContext context) {
    if (contentOverride case final override?) {
      return override;
    }

    if (imageProvider != null) {
      return Image(
        image: ResizeImage.resizeIfNeeded(
          _decodeWidth(context),
          null,
          imageProvider!,
        ),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    if (_hasNetworkImage && _isSvgImageUrl) {
      if (AvatarFailureCache.instance.isFailed(imageUrl!)) {
        return _buildPlaceholder();
      }

      final repository = avatarSvgRepository;
      if (repository != null) {
        return _AvatarSvgContent(
          imageUrl: imageUrl!,
          repository: repository,
          placeholderBuilder: _buildPlaceholder,
        );
      }
      return _ProvidedAvatarSvgContent(
        imageUrl: imageUrl!,
        placeholderBuilder: _buildPlaceholder,
      );
    }

    if (_hasNetworkImage) {
      if (AvatarFailureCache.instance.isFailed(imageUrl!)) {
        return _buildPlaceholder();
      }

      return VineCachedImage(
        imageUrl: imageUrl!,
        memCacheWidth: _decodeWidth(context),
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          final failureKind = AvatarFailureCache.instance.recordFailureForError(
            url,
            error,
          );

          if (failureKind == AvatarFailureKind.deterministic) {
            UnifiedLogger.warning(
              'Avatar image data was invalid; showing placeholder',
              name: 'UserAvatar',
            );
          } else {
            UnifiedLogger.debug(
              'Avatar image request failed; showing placeholder',
              name: 'UserAvatar',
            );
          }
          return _buildPlaceholder();
        },
      );
    }

    return _buildPlaceholder();
  }
}

/// Resolves the shared [AvatarSvgRepository] from the container.
///
/// Separate from [_AvatarSvgContent] so a caller that injects its own
/// repository needs no `ProviderScope` above it.
class _ProvidedAvatarSvgContent extends ConsumerWidget {
  const _ProvidedAvatarSvgContent({
    required this.imageUrl,
    required this.placeholderBuilder,
  });

  final String imageUrl;
  final Widget Function() placeholderBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AvatarSvgContent(
      imageUrl: imageUrl,
      repository: ref.watch(avatarSvgRepositoryProvider),
      placeholderBuilder: placeholderBuilder,
    );
  }
}

class _AvatarSvgContent extends StatelessWidget {
  const _AvatarSvgContent({
    required this.imageUrl,
    required this.repository,
    required this.placeholderBuilder,
  });

  final String imageUrl;
  final AvatarSvgRepository repository;
  final Widget Function() placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AvatarSvgCubit>(
      key: ValueKey((imageUrl, repository)),
      create: (_) =>
          AvatarSvgCubit(repository: repository, url: imageUrl)..load(),
      child: BlocBuilder<AvatarSvgCubit, AvatarSvgState>(
        builder: (context, state) {
          final bytes = state.bytes;
          if (state.status != AvatarSvgStatus.ready || bytes == null) {
            return placeholderBuilder();
          }

          return SvgPicture.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              UnifiedLogger.debug(
                'Avatar SVG failed to render; showing placeholder',
                name: 'UserAvatar',
              );
              AvatarFailureCache.instance.recordFailureForError(
                imageUrl,
                error,
              );
              return placeholderBuilder();
            },
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.size,
    required this.placeholderTone,
    required this.placeholderSeed,
    required this.semanticLabel,
    required this.imageUrl,
    required this.name,
  });

  final double size;
  final UserAvatarPlaceholderTone placeholderTone;
  final String? placeholderSeed;
  final String? semanticLabel;
  final String? imageUrl;
  final String? name;

  static const List<UserAvatarPlaceholderTone> _paletteOrder = [
    UserAvatarPlaceholderTone.yellow,
    UserAvatarPlaceholderTone.lime,
    UserAvatarPlaceholderTone.pink,
    UserAvatarPlaceholderTone.orange,
    UserAvatarPlaceholderTone.violet,
    UserAvatarPlaceholderTone.purple,
    UserAvatarPlaceholderTone.blue,
  ];

  static const Map<UserAvatarPlaceholderTone, _AvatarPalette> _palettes = {
    UserAvatarPlaceholderTone.yellow: _AvatarPalette(
      base: VineTheme.accentYellow,
      figure: Color(0xFFAF9500),
      shadow: Color(0xFF665900),
    ),
    UserAvatarPlaceholderTone.lime: _AvatarPalette(
      base: VineTheme.accentLime,
      figure: Color(0xFF79A200),
      shadow: Color(0xFF445C00),
    ),
    UserAvatarPlaceholderTone.pink: _AvatarPalette(
      base: VineTheme.accentPink,
      figure: Color(0xFFCB4E82),
      shadow: Color(0xFF7E2351),
    ),
    UserAvatarPlaceholderTone.orange: _AvatarPalette(
      base: VineTheme.accentOrange,
      figure: Color(0xFFD74C17),
      shadow: Color(0xFF8A2805),
    ),
    UserAvatarPlaceholderTone.violet: _AvatarPalette(
      base: VineTheme.accentViolet,
      figure: Color(0xFF6D74D5),
      shadow: Color(0xFF41489B),
    ),
    UserAvatarPlaceholderTone.purple: _AvatarPalette(
      base: VineTheme.accentPurple,
      figure: Color(0xFF5C37F6),
      shadow: Color(0xFF321D8F),
    ),
    UserAvatarPlaceholderTone.blue: _AvatarPalette(
      base: VineTheme.accentBlue,
      figure: Color(0xFF0B84C3),
      shadow: Color(0xFF07577F),
    ),
  };

  static Color _lighten(Color color, double amount) =>
      Color.lerp(color, VineTheme.whiteText, amount) ?? color;

  static Color _darken(Color color, double amount) =>
      Color.lerp(color, VineTheme.backgroundColor, amount) ?? color;

  static _AvatarPalette get _fallbackPalette => _palettes.values.first;

  static UserAvatarPlaceholderTone toneForSeed(String seed) {
    if (seed.isEmpty) return UserAvatarPlaceholderTone.yellow;

    final index =
        seed.runes.fold<int>(0, (sum, rune) => sum + rune) %
        _paletteOrder.length;
    return _paletteOrder[index];
  }

  UserAvatarPlaceholderTone get _effectiveTone {
    if (placeholderTone != UserAvatarPlaceholderTone.auto) {
      return placeholderTone;
    }

    final stableSeed = placeholderSeed?.trim();
    final seed = stableSeed != null && stableSeed.isNotEmpty
        ? stableSeed
        : [name, imageUrl, semanticLabel]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join('|');
    return toneForSeed(seed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[_effectiveTone] ?? _fallbackPalette;
    // Geometry matches Figma node 11251:229419 (profile-setup avatar).
    final headSize = size * 0.46;
    final headHorizontalInset = (size - headSize) / 2;
    final headTopInset = size * 0.20;

    // Body is a wide ellipse; its lower half is clipped by the avatar box.
    final bodyWidth = size * 0.76;
    final bodyHeight = size * 0.56;
    final bodyHorizontalInset = (size - bodyWidth) / 2;
    final bodyTopInset = size * 0.68;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _lighten(palette.base, 0.22),
            palette.base,
            _darken(palette.base, 0.08),
          ],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.55, -0.9),
                radius: 1.15,
                colors: [
                  VineTheme.whiteText.withValues(alpha: 0.18),
                  VineTheme.transparent,
                ],
              ),
            ),
          ),
          // Body: horizontal ellipse, partly clipped by the bounding box.
          // Rendered before the head so the head sits on top at the neck.
          Positioned(
            left: bodyHorizontalInset,
            top: bodyTopInset,
            child: SizedBox(
              width: bodyWidth,
              height: bodyHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base figure colour with a soft top-left highlight.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(bodyWidth / 2, bodyHeight / 2),
                      ),
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.6),
                        radius: 1.1,
                        colors: [
                          _lighten(palette.figure, 0.20),
                          palette.figure,
                        ],
                      ),
                    ),
                  ),
                  // Inner shadow: directional dark overlay on the
                  // lower-right edge. Transparent on the lit side so the
                  // base figure colour shows through unchanged.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(bodyWidth / 2, bodyHeight / 2),
                      ),
                      gradient: RadialGradient(
                        center: const Alignment(-0.5, -0.7),
                        radius: 1.4,
                        colors: [
                          VineTheme.transparent,
                          VineTheme.transparent,
                          _darken(palette.shadow, 0.35).withValues(alpha: 0.95),
                        ],
                        stops: const [0, 0.25, 1],
                      ),
                    ),
                  ),
                  // Inner shadow: dark band along the top edge that fades
                  // downward. Reads as the body curving away beneath the
                  // head / neck.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(bodyWidth / 2, bodyHeight / 2),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _darken(palette.shadow, 0.4).withValues(alpha: 0.35),
                          VineTheme.transparent,
                        ],
                        stops: const [0, 0.22],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: headHorizontalInset,
            top: headTopInset,
            child: SizedBox(
              width: headSize,
              height: headSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base head with soft top-left highlight.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.4, -0.45),
                        radius: 1.05,
                        colors: [
                          _lighten(palette.figure, 0.22),
                          palette.figure,
                        ],
                      ),
                    ),
                  ),
                  // Inner shadow: directional dark overlay on the
                  // lower-right edge.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.55, -0.6),
                        radius: 1.3,
                        colors: [
                          VineTheme.transparent,
                          VineTheme.transparent,
                          _darken(palette.shadow, 0.35).withValues(alpha: 0.95),
                        ],
                        stops: const [0, 0.25, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: Container(
                height: size * 0.24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VineTheme.transparent,
                      palette.shadow.withValues(alpha: 0.26),
                    ],
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

class _AvatarPalette {
  const _AvatarPalette({
    required this.base,
    required this.figure,
    required this.shadow,
  });

  final Color base;
  final Color figure;
  final Color shadow;
}
