// ABOUTME: Age verification dialog for camera access and adult content viewing
// ABOUTME: Supports both 16+ creation and 18+ content viewing verification

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

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
    backgroundColor: context.vineColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.vineColors.accentPositive, width: 2),
    ),
    child: Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineIcon(
            icon: DivineIconName.user,
            color: context.vineColors.accentPositive,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            type == AgeVerificationType.adultContent
                ? context.l10n.ageVerificationContentWarning
                : context.l10n.ageVerificationTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.vineColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            type == AgeVerificationType.adultContent
                ? context.l10n.ageVerificationAdultDescription
                : context.l10n.ageVerificationCreationDescription,
            style:
                Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(
                  color: context.vineColors.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            type == AgeVerificationType.adultContent
                ? context.l10n.ageVerificationAdultQuestion
                : context.l10n.ageVerificationCreationQuestion,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.vineColors.primaryText,
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
                    foregroundColor: context.vineColors.primaryText,
                    side: BorderSide(color: context.vineColors.onSurfaceMuted),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(context.l10n.ageVerificationNo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: VineTheme.whiteText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(context.l10n.ageVerificationYes),
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
