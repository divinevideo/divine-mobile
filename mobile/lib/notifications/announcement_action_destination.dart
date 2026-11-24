// ABOUTME: Maps validated announcement actions to store or contest URLs.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/services/push_device_metadata.dart';

/// Returns the URL [action] should open on [device], or null to hide it.
///
/// No arbitrary store URL is accepted: update links come from the existing
/// install-source URL catalog, and only apply to older matching installs.
/// Contest URLs were already validated by the catalog parser.
Uri? announcementActionDestination(
  AnnouncementAction? action,
  PushDeviceMetadata? device,
) {
  switch (action) {
    case ContestAnnouncementAction(:final url):
      return url;
    case UpdateAppAnnouncementAction(
      :final platform,
      :final channel,
      :final version,
    ):
      if (device == null) return null;
      final current = device.appVersion;
      if (device.platform != platform ||
          device.installChannel != channel ||
          current == null ||
          !validReleaseVersion(version) ||
          !isOlderThan(current, version)) {
        return null;
      }
      final source = switch (channel) {
        'app_store' => InstallSource.appStore,
        'google_play' => InstallSource.playStore,
        'zapstore' => InstallSource.zapstore,
        _ => null,
      };
      return source == null ? null : Uri.parse(DownloadUrls.forSource(source));
    case null:
      return null;
  }
}
