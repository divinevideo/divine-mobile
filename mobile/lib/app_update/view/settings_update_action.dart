import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the store URL selected for an available update.
typedef UpdateUrlLauncher = Future<void> Function(Uri uri);

Future<void> _launchExternalUpdate(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A persistent Settings action for an update found during this session.
///
/// Unlike the transient banner or dialog, this remains available after the
/// user dismisses an update nudge.
class SettingsUpdateAction extends StatelessWidget {
  /// Creates the Settings update action.
  const SettingsUpdateAction({
    super.key,
    this.launchUpdate = _launchExternalUpdate,
  });

  /// Launches the selected store URL.
  final UpdateUrlLauncher launchUpdate;

  @override
  Widget build(BuildContext context) {
    final AppUpdateBloc bloc;
    try {
      bloc = context.read<AppUpdateBloc>();
    } on ProviderNotFoundException {
      // Settings is also rendered in isolated previews and test harnesses.
      // Update availability is optional in those contexts.
      return const SizedBox.shrink();
    }

    return BlocSelector<AppUpdateBloc, AppUpdateState, String?>(
      bloc: bloc,
      selector: (state) {
        if (state.status != AppUpdateStatus.resolved) return null;
        if (state.latestVersion == null) return null;
        return state.downloadUrl;
      },
      builder: (context, downloadUrl) {
        if (downloadUrl == null) return const SizedBox.shrink();
        return TextButton(
          onPressed: () => _launchUpdate(downloadUrl),
          child: Text(context.l10n.settingsUpdateAvailable),
        );
      },
    );
  }

  Future<void> _launchUpdate(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUpdate(uri);
    }
  }
}
