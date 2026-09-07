import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for caching and dismissal tracking.
abstract class UpdatePrefsKeys {
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
      return _restoreCachedUpdate();
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
      await _clearCachedUpdate();
      return const UpdateCheckResult.none();
    }

    final downloadUrl = DownloadUrls.forSource(_installSource);
    final age = DateTime.now().difference(info.publishedAt);
    final rawUrgency = _determineUrgency(info, age);
    final urgency = _applyDismissalRules(rawUrgency, info.latestVersion);

    await Future.wait([
      _prefs.setString(UpdatePrefsKeys.latestVersion, info.latestVersion),
      _prefs.setString(UpdatePrefsKeys.downloadUrl, downloadUrl),
    ]);

    return UpdateCheckResult(
      urgency: urgency,
      downloadUrl: downloadUrl,
      latestVersion: info.latestVersion,
      releaseHighlights: info.releaseHighlights,
      releaseNotesUrl: info.releaseNotesUrl,
    );
  }

  Future<UpdateCheckResult?> _restoreCachedUpdate() async {
    final latestVersion = _prefs.getString(UpdatePrefsKeys.latestVersion);
    final downloadUrl = _prefs.getString(UpdatePrefsKeys.downloadUrl);
    if (latestVersion == null || downloadUrl == null) return null;
    if (!isOlderThan(_currentVersion, latestVersion)) {
      await _clearCachedUpdate();
      return null;
    }

    // The cache keeps Settings useful between network checks without replaying
    // a transient banner or dialog on every app launch.
    return UpdateCheckResult(
      urgency: UpdateUrgency.none,
      downloadUrl: downloadUrl,
      latestVersion: latestVersion,
    );
  }

  Future<void> _clearCachedUpdate() async {
    await Future.wait([
      _prefs.remove(UpdatePrefsKeys.latestVersion),
      _prefs.remove(UpdatePrefsKeys.downloadUrl),
    ]);
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
