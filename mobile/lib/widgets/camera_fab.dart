// ABOUTME: Reusable camera FAB widget for consistent camera access across all screens
// ABOUTME: Handles age verification and navigation to camera screen

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/camera_permission_check.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';

class CameraFAB extends ConsumerWidget {
  const CameraFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () async {
        final scaffoldContext = context;

        // Check age verification
        final ageVerificationService = ref.read(ageVerificationServiceProvider);
        final isVerified = await ageVerificationService.checkAgeVerification();

        if (!isVerified) {
          if (!scaffoldContext.mounted) return;
          final result = await AgeVerificationDialog.show(scaffoldContext);
          if (result) {
            final saved = await ageVerificationService.setAgeVerified(true);
            if (saved && scaffoldContext.mounted) {
              await scaffoldContext.pushToCameraWithPermission();
            }
          } else {
            if (scaffoldContext.mounted) {
              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(scaffoldContext.l10n.cameraAgeRestriction),
                  backgroundColor: VineTheme.error,
                ),
              );
            }
          }
        } else {
          if (scaffoldContext.mounted) {
            await scaffoldContext.pushToCameraWithPermission();
          }
        }
      },
      backgroundColor: VineTheme.vineGreen,
      foregroundColor: VineTheme.whiteText,
      child: const DivineIcon(
        icon: DivineIconName.videoCamera,
        size: 32,
        color: VineTheme.whiteText,
      ),
    );
  }
}
