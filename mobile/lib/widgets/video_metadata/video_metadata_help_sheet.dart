import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class VideoMetadataHelpSheet extends StatelessWidget {
  const VideoMetadataHelpSheet({
    required this.title,
    required this.message,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String message;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const .only(top: 8.0, bottom: 16),
              child: Image.asset(assetPath, height: 132, width: 132),
            ),

            Text(
              title,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: .center,
            ),
            const SizedBox(height: 8),

            Text(
              message,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurfaceVariant,
              ),
              textAlign: .center,
            ),
            const SizedBox(height: 32),

            Semantics(
              button: true,
              label: context.l10n.videoMetadataDismissHelpDialogSemanticLabel,

              child: Material(
                color: context.vineColors.surfaceContainer,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 2,
                    color: context.vineColors.outlineMuted,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: .circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const .symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      context.l10n.videoMetadataGotItButton,
                      textAlign: TextAlign.center,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.accentPositive,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
