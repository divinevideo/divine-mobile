// ABOUTME: Reusable user avatar widget that displays profile pictures or fallback initials
// ABOUTME: Handles loading states, errors, and provides consistent avatar appearance across the app

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.onTap,
  });
  final String? imageUrl;
  final String? name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Green border circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VineTheme.vineGreen,
          ),
        ),
        // Inner circle with image
        Container(
          width: size - 4,
          height: size - 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: size - 4,
                    height: size - 4,
                    fit: BoxFit.cover,
                    cacheManager: openVineImageCache,
                    placeholder: (context, url) => _buildFallback(),
                    errorWidget: (context, url, error) {
                      // Log the failed URL for debugging
                      if (error.toString().contains('Invalid image data') ||
                          error.toString().contains('Image codec failed')) {
                        UnifiedLogger.warning(
                          '🖼️ Invalid image data for avatar URL: $url - Error: $error',
                          name: 'UserAvatar',
                        );
                      } else {
                        UnifiedLogger.debug(
                          'Avatar image failed to load URL: $url - Error: $error',
                          name: 'UserAvatar',
                        );
                      }
                      return _buildFallback();
                    },
                  )
                : _buildFallback(),
          ),
        ),
      ],
    ),
  );

  Widget _buildFallback() {
    return Image.asset(
      'assets/icon/user-avatar.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // If asset fails to load, show icon-based fallback
        UnifiedLogger.debug(
          'Avatar asset failed to load: $error',
          name: 'UserAvatar',
        );
        return _buildIconFallback();
      },
    );
  }

  Widget _buildIconFallback() {
    return Container(
      color: VineTheme.vineGreen.withValues(alpha: 0.2),
      child: Center(
        child: Icon(Icons.person, color: VineTheme.vineGreen, size: size * 0.5),
      ),
    );
  }
}
