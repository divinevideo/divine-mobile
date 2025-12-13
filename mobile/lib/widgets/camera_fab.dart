// ABOUTME: Reusable camera FAB widget for consistent camera access across all screens
// ABOUTME: Handles age verification and navigation to camera screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';

class CameraFAB extends ConsumerWidget {
  const CameraFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () async {
        final scaffoldContext = context;

        // Stop any playing videos before opening camera
        disposeAllVideoControllers(ref);

        // Check age verification
        final ageVerificationService = ref.read(ageVerificationServiceProvider);
        final isVerified = await ageVerificationService.checkAgeVerification();

        if (!isVerified) {
          if (!scaffoldContext.mounted) return;
          final result = await AgeVerificationDialog.show(scaffoldContext);
          if (result) {
            await ageVerificationService.setAgeVerified(true);
            if (scaffoldContext.mounted) {
              await scaffoldContext.pushCamera();
            }
          } else {
            if (scaffoldContext.mounted) {
              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                const SnackBar(
                  content: Text('You must be 16 or older to create content'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (scaffoldContext.mounted) {
            await scaffoldContext.pushCamera();
          }
        }
      },
      backgroundColor: VineTheme.vineGreen,
      foregroundColor: VineTheme.whiteText,
      child: const Icon(Icons.videocam, size: 32),
    );
  }
}
