import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/upload_explainer_constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Static explainer panel shown when the user selects the Upload mode tab.
///
/// Divine does not accept camera-roll uploads — every video is recorded
/// in-app to support camera-to-user verification. This panel explains
/// that stance and links out to divine.video/proofmode for users who
/// want to read more.
class VideoRecorderUploadStack extends StatelessWidget {
  /// Creates the Upload-mode explainer stack.
  const VideoRecorderUploadStack({super.key});

  Future<void> _openLearnMore() async {
    await launchUrl(
      Uri.parse(proofmodeLearnMoreUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Text(
                l10n.videoRecorderUploadTitle,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              Text(
                l10n.videoRecorderUploadBody,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              Text(
                l10n.videoRecorderUploadBodyDetail,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              Text(
                l10n.videoRecorderUploadBodyCta,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              _LearnMoreLink(onPressed: _openLearnMore),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        link: true,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              spacing: 8,
              children: [
                Text(
                  context.l10n.videoRecorderUploadLearnMore,
                  style: VineTheme.bodyMediumFont(color: VineTheme.primary),
                ),
                const ExcludeSemantics(
                  child: DivineIcon(
                    icon: DivineIconName.arrowUpRight,
                    size: 16,
                    color: VineTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
