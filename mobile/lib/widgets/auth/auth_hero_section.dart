// ABOUTME: Shared hero section widget for authentication screens
// ABOUTME: Large tagline text with decorative 3D emoji stickers and Divine logo

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/l10n/l10n.dart';

/// Hero section with large tagline text and decorative 3D emoji stickers.
///
/// Displays "Authentic moments." in green and "Human creativity." in white,
/// with positioned sticker images and the Divine wordmark logo.
class AuthHeroSection extends StatelessWidget {
  const AuthHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero text with positioned emoji stickers
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main text
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // "Authentic moments." - green, BricolageGrotesque font
                    Text(
                      context.l10n.authHeroTaglineAuthentic,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: VineTheme.vineGreen,
                        height: 1.1,
                      ),
                    ),
                    // "Human creativity." - white, BricolageGrotesque font
                    Text(
                      context.l10n.authHeroTaglineHuman,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: context.vineColors.primaryText,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Camera emoji - top left
              const Positioned(
                top: -30,
                left: 10,
                child: _StickerImage(
                  path: 'assets/stickers/video_camera.svg',
                  size: 60,
                ),
              ),

              // Teeth emoji - top right
              const Positioned(
                top: -5,
                right: -20,
                child: _StickerImage(
                  path: 'assets/stickers/teeth.svg',
                  size: 70,
                ),
              ),

              // Balloon dog emoji - bottom left
              const Positioned(
                bottom: -34,
                left: 15,
                child: _StickerImage(
                  path: 'assets/stickers/balloon_dog.svg',
                  size: 80,
                ),
              ),

              // Disco ball emoji - bottom right
              const Positioned(
                bottom: -10,
                right: -10,
                child: _StickerImage(
                  path: 'assets/stickers/disco_ball.svg',
                  size: 65,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Divine wordmark. `logo.svg` is the current geometric heart-V mark;
          // auth_hero_section_test.dart pins it against retired brand assets.
          // The label is the brand name, not copy: it stays out of the ARB
          // catalog so no locale can translate or transliterate it.
          Semantics(
            label: AppConfig.appName,
            image: true,
            child: ExcludeSemantics(
              child: SvgPicture.asset(
                DivineIconName.logo.assetPath,
                width: 120,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative sticker image widget.
class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
