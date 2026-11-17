// ABOUTME: Release-targeting metadata for push registration and update actions.
// ABOUTME: Unknown installs never guess a distribution channel.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';

/// Platform, install channel and marketing version for this install.
///
/// Sent in the encrypted kind-3079 registration and compared against
/// announcement update actions; never added to analytics.
class PushDeviceMetadata {
  const PushDeviceMetadata._({
    this.platform,
    this.installChannel,
    this.appVersion,
  });

  /// Resolves this install's metadata, omitting unsupported or unknown values.
  factory PushDeviceMetadata.resolve({
    required TargetPlatform platform,
    required InstallSource source,
    required String appVersion,
  }) {
    final platformName = switch (platform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    final channel = switch ((platform, source)) {
      (TargetPlatform.iOS, InstallSource.appStore) => 'app_store',
      (TargetPlatform.android, InstallSource.playStore) => 'google_play',
      (TargetPlatform.android, InstallSource.zapstore) => 'zapstore',
      _ => null,
    };
    return PushDeviceMetadata._(
      platform: platformName,
      installChannel: channel,
      appVersion: validReleaseVersion(appVersion) ? appVersion : null,
    );
  }

  final String? platform;
  final String? installChannel;
  final String? appVersion;

  Map<String, String> toJson() => {
    'platform': ?platform,
    'installChannel': ?installChannel,
    'appVersion': ?appVersion,
  };
}

/// Whether [value] is a canonical `major.minor.patch` of at most six digits
/// per part. Keep in step with `AnnouncementsRepository._action` and `_version`
/// in `mobile/scripts/release_train/campaign_drafts.py`.
bool validReleaseVersion(String value) =>
    value.length <= 20 &&
    RegExp(r'^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})$')
        .hasMatch(value);
