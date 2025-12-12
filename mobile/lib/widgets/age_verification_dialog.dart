// ABOUTME: Age verification dialog for camera access and adult content viewing
// ABOUTME: Supports both 16+ creation and 18+ content viewing verification

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';

enum AgeVerificationType {
  creation, // 16+ for creating content
  adultContent, // 18+ for viewing adult content
}

class AgeVerificationDialog extends StatelessWidget {
  const AgeVerificationDialog({
    super.key,
    this.type = AgeVerificationType.creation,
  });
  final AgeVerificationType type;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.black,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: VineTheme.vineGreen, width: 2),
    ),
    child: Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            color: VineTheme.vineGreen,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            type == AgeVerificationType.adultContent
                ? 'Content Warning'
                : 'Age Verification',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            type == AgeVerificationType.adultContent
                ? 'This content has been flagged as potentially containing adult material. You must be 18 or older to view it.'
                : 'To use the camera and create content, you must be at least 16 years old.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            type == AgeVerificationType.adultContent
                ? 'Are you 18 years of age or older?'
                : 'Are you 16 years of age or older?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('No'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Yes'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static Future<bool> show(
    BuildContext context, {
    AgeVerificationType type = AgeVerificationType.creation,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgeVerificationDialog(type: type),
    );
    return result ?? false;
  }
}
