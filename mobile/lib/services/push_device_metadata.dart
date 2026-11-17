// ABOUTME: Device-only release targeting metadata for encrypted push registration.
// ABOUTME: Unknown installs never guess a distribution channel.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';

/// Installed platform, store and marketing version; never sent to engagement.
class PushDeviceMetadata {
  const PushDeviceMetadata._({
    this.platform,
    this.installChannel,
    this.appVersion,
  });

  /// Resolves actual bootstrap metadata, omitting unsupported or unknown values.
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

/// The bounded canonical version contract shared with release targeting.
bool validReleaseVersion(String value) =>
    value.length <= 20 &&
    RegExp(r'^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})$')
        .hasMatch(value);
