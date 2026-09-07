import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for caching and dismissal tracking.
abstract class UpdatePrefsKeys {
  /// Update availability and prompts belong to the installation,
  /// not an account.
  static const List<String> deviceScopedPrefsKeys = [
    dismissedVersion,
    dismissedAt,
    lastChecked,
    latestVersion,
    downloadUrl,
  ];

  /// Key for the dismissed version string.
  static const dismissedVersion = 'update_dismissed_version';

  /// Key for the dismissed-at timestamp.
  static const dismissedAt = 'update_dismissed_at';

  /// Key for the last-checked timestamp.
  static const lastChecked = 'update_last_checked';

  /// Key for the latest version found during the last successful check.
  static const latestVersion = 'update_latest_version';

  /// Key for the store URL resolved during the last successful check.
  static const downloadUrl = 'update_download_url';
}

/// Cooldown before showing the moderate dialog again after dismissal.
const moderateCooldown = Duration(days: 3);

/// Duration after which a release escalates from gentle to moderate.
const _moderateThreshold = Duration(days: 14);

/// Compares the current app version against the latest release,
/// manages caching, dismissal, and determines the update urgency.
class AppUpdateRepository {
  /// Creates an [AppUpdateRepository].
  AppUpdateRepository({
    required AppVersionClient appVersionClient,
    required SharedPreferences sharedPreferences,
    required String currentVersion,
    required InstallSource installSource,
  }) : _client = appVersionClient,
       _prefs = sharedPreferences,
       _currentVersion = currentVersion,
       _installSource = installSource;

  final AppVersionClient _client;
  final SharedPreferences _prefs;
  final String _currentVersion;
  final InstallSource _installSource;

  /// Checks for updates, respecting the 24h cache TTL.
  ///
  /// Returns `null` if the check should be skipped:
  /// - First install (no prior check recorded)
  /// - Within the 24h TTL window
  ///
  /// Returns [UpdateCheckResult] with the appropriate urgency otherwise.
  /// Returns [UpdateCheckResult.none] on network failures (silent skip).
  Future<UpdateCheckResult?> checkForUpdate() async {
    // Skip on first install.
    final lastChecked = _prefs.getString(UpdatePrefsKeys.lastChecked);
    if (lastChecked == null) {
      await _prefs.setString(
        UpdatePrefsKeys.lastChecked,
        DateTime.now().toIso8601String(),
      );
      return null;
    }

    // Respect 24h cache TTL.
    final lastCheckedAt = DateTime.tryParse(lastChecked);
    if (lastCheckedAt != null &&
        DateTime.now().difference(lastCheckedAt) <
            AppVersionConstants.cacheTtl) {
      return null;
    }

    final AppVersionInfo info;
    try {
      info = await _client.fetchLatestRelease();
    } on AppVersionFetchException {
      return const UpdateCheckResult.none();
    }

    await _prefs.setString(
      UpdatePrefsKeys.lastChecked,
      DateTime.now().toIso8601String(),
    );

    if (!isOlderThan(_currentVersion, info.latestVersion)) {
      return const UpdateCheckResult.none();
    }

    final downloadUrl = DownloadUrls.forSource(_installSource);
    final age = DateTime.now().difference(info.publishedAt);
    final rawUrgency = _determineUrgency(info, age);
    final urgency = _applyDismissalRules(rawUrgency, info.latestVersion);

    return UpdateCheckResult(
      urgency: urgency,
      downloadUrl: downloadUrl,
      latestVersion: info.latestVersion,
      releaseHighlights: info.releaseHighlights,
      releaseNotesUrl: info.releaseNotesUrl,
    );
  }

  /// Records that the user dismissed the nudge for [version].
  Future<void> dismissUpdate(String version) async {
    await _prefs.setString(UpdatePrefsKeys.dismissedVersion, version);
    await _prefs.setString(
      UpdatePrefsKeys.dismissedAt,
      DateTime.now().toIso8601String(),
    );
  }

  UpdateUrgency _determineUrgency(AppVersionInfo info, Duration age) {
    if (info.minimumVersion != null &&
        isBelowMinimum(_currentVersion, info.minimumVersion!)) {
      return UpdateUrgency.urgent;
    }
    if (age >= _moderateThreshold) {
      return UpdateUrgency.moderate;
    }
    return UpdateUrgency.gentle;
  }

  UpdateUrgency _applyDismissalRules(
    UpdateUrgency urgency,
    String latestVersion,
  ) {
    // Urgent: always show, ignore dismissal.
    if (urgency == UpdateUrgency.urgent) return urgency;

    final dismissedVersion = _prefs.getString(UpdatePrefsKeys.dismissedVersion);
    final dismissedAtStr = _prefs.getString(UpdatePrefsKeys.dismissedAt);

    // Different version: reset, show nudge.
    if (dismissedVersion != latestVersion) return urgency;

    // Same version was dismissed.
    final dismissedAt = dismissedAtStr != null
        ? DateTime.tryParse(dismissedAtStr)
        : null;

    // Gentle: once per version.
    if (urgency == UpdateUrgency.gentle) return UpdateUrgency.none;

    // Moderate: 3-day cooldown.
    if (urgency == UpdateUrgency.moderate && dismissedAt != null) {
      if (DateTime.now().difference(dismissedAt) < moderateCooldown) {
        return UpdateUrgency.none;
      }
    }

    return urgency;
  }
}
