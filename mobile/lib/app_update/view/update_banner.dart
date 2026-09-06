import 'package:app_update_repository/app_update_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// A slim dismissible banner shown above the bottom navigation
/// when a gentle update is available.
class UpdateBanner extends StatelessWidget {
  /// Creates an [UpdateBanner].
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppUpdateBloc, AppUpdateState, String?>(
      selector: (state) {
        if (state.status != AppUpdateStatus.resolved) return null;
        if (state.urgency != UpdateUrgency.gentle) return null;
        return state.downloadUrl;
      },
      builder: (context, downloadUrl) {
        if (downloadUrl == null) return const SizedBox.shrink();
        return _BannerContent(downloadUrl: downloadUrl);
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.downloadUrl});

  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(color: VineTheme.vineGreen.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _launchUpdate(downloadUrl),
              child: Text(
                context.l10n.updateGentleBanner,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: VineTheme.vineGreen),
              ),
            ),
          ),
          IconButton(
            icon: DivineIcon(
              icon: DivineIconName.x,
              size: 18,
              color: context.vineColors.mutedText.withValues(alpha: 0.6),
            ),
            onPressed: () {
              context.read<AppUpdateBloc>().add(const AppUpdateDismissed());
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdate(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
