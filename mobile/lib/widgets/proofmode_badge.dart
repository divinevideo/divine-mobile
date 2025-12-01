// ABOUTME: ProofMode verification badge widget for displaying video authenticity levels
// ABOUTME: Shows tiered verification badges (Verified Mobile, Verified Web, Basic Proof, Unverified) plus original Vine badge

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Verification level enum matching ProofMode implementation
enum VerificationLevel { verifiedMobile, verifiedWeb, basicProof, unverified }

/// ProofMode verification badge widget
class ProofModeBadge extends StatelessWidget {
  const ProofModeBadge({
    super.key,
    required this.level,
    this.size = BadgeSize.small,
  });

  final VerificationLevel level;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final config = _getBadgeConfig(level);
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: dimensions.iconSize, color: config.iconColor),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            config.label,
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.verifiedMobile:
        return const _BadgeConfig(
          label: 'Fully Verified',
          icon: Icons.verified,
          backgroundColor: Color(0xFFD4EDDA), // Light green
          borderColor: Color(0xFF28A745), // Green
          iconColor: Color(0xFF28A745),
          textColor: Color(0xFF155724), // Dark green
        );
      case VerificationLevel.verifiedWeb:
        return const _BadgeConfig(
          label: 'Verified',
          icon: Icons.shield_outlined,
          backgroundColor: Color(0xFFD1ECF1), // Light blue
          borderColor: Color(0xFF17A2B8), // Blue
          iconColor: Color(0xFF17A2B8),
          textColor: Color(0xFF0C5460), // Dark blue
        );
      case VerificationLevel.basicProof:
        return const _BadgeConfig(
          label: 'Basic Proof',
          icon: Icons.info_outline,
          backgroundColor: Color(0xFFFFF3CD), // Light yellow
          borderColor: Color(0xFFFFC107), // Yellow
          iconColor: Color(0xFFFFC107),
          textColor: Color(0xFF856404), // Dark yellow
        );
      case VerificationLevel.unverified:
        return const _BadgeConfig(
          label: 'Unverified',
          icon: Icons.shield_outlined,
          backgroundColor: Color(0xFFF8D7DA), // Light red
          borderColor: Color(0xFFF5C6CB), // Red
          iconColor: Color(0xFF721C24), // Dark red
          textColor: Color(0xFF721C24),
        );
    }
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 12,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 14,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 16,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// Original content badge for user-created (non-repost) vines
class OriginalContentBadge extends StatelessWidget {
  const OriginalContentBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFF00BCD4,
        ), // Cyan/teal - modern original content color
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(
          color: const Color(0xFF0097A7), // Darker cyan border
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: dimensions.iconSize,
            color: Colors.white,
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Original',
            style: GoogleFonts.pacifico(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 12, // More pill-shaped
          iconSize: 10,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 14,
          iconSize: 12,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 16,
          iconSize: 14,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// Original Vine badge for recovered vintage vines
class OriginalVineBadge extends StatelessWidget {
  const OriginalVineBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF00BF8F), // Vine teal/green
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'V',
            style: GoogleFonts.pacifico(
              fontSize: dimensions.fontSize + 2,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Original',
            style: GoogleFonts.pacifico(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 12,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 14,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 16,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// Badge size enum
enum BadgeSize { small, medium, large }

/// Badge configuration
class _BadgeConfig {
  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
}

/// Badge dimensions based on size
class _BadgeDimensions {
  const _BadgeDimensions({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.borderRadius,
    required this.iconSize,
    required this.fontSize,
    required this.iconTextSpacing,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double iconSize;
  final double fontSize;
  final double iconTextSpacing;
}
