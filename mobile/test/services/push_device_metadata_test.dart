// ABOUTME: Verifies conservative device metadata for release targeting.
// ABOUTME: Covers platform/store matching and canonical bounded versions.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/push_device_metadata.dart';

void main() {
  group('PushDeviceMetadata.resolve', () {
    const supportedChannels = {
      (TargetPlatform.iOS, InstallSource.appStore): 'app_store',
      (TargetPlatform.android, InstallSource.playStore): 'google_play',
      (TargetPlatform.android, InstallSource.zapstore): 'zapstore',
    };

    for (final platform in TargetPlatform.values) {
      for (final source in InstallSource.values) {
        test('${platform.name} with ${source.name}', () {
          final metadata = PushDeviceMetadata.resolve(
            platform: platform,
            source: source,
            appVersion: '1.2.3',
          );

          expect(
            metadata.supportsDirectMessageRouting,
            !kIsWeb &&
                (platform == TargetPlatform.android ||
                    platform == TargetPlatform.iOS),
          );
          expect(metadata.platform, switch (platform) {
            TargetPlatform.iOS => 'ios',
            TargetPlatform.android => 'android',
            _ => null,
          });
          expect(
            metadata.installChannel,
            supportedChannels[(platform, source)],
          );
          expect(metadata.appVersion, '1.2.3');
        });
      }
    }

    for (final version in ['01.2.3', '1.2.3-beta', '1.2.3+4', '1000000.2.3']) {
      test('omits invalid version $version without dropping known store', () {
        final metadata = PushDeviceMetadata.resolve(
          platform: TargetPlatform.iOS,
          source: InstallSource.appStore,
          appVersion: version,
        );

        expect(metadata.appVersion, isNull);
        expect(metadata.platform, 'ios');
        expect(metadata.installChannel, 'app_store');
      });
    }
  });

  group('validReleaseVersion', () {
    for (final version in ['0.0.0', '1.2.3', '999999.999999.999999']) {
      test('accepts canonical bounded version $version', () {
        expect(validReleaseVersion(version), isTrue);
      });
    }

    for (final version in [
      '',
      '1.2',
      '1.2.3.4',
      '01.2.3',
      '1.02.3',
      '1.2.03',
      '1.2.3-beta',
      '1.2.3+4',
      '1000000.2.3',
      '1.1000000.3',
      '1.2.1000000',
      '-1.2.3',
      ' 1.2.3',
      '1.2.3 ',
    ]) {
      test('rejects noncanonical or out-of-range version "$version"', () {
        expect(validReleaseVersion(version), isFalse);
      });
    }
  });

  group('PushDeviceMetadata.toJson', () {
    test('serializes supported platform, channel and canonical version', () {
      final metadata = PushDeviceMetadata.resolve(
        platform: TargetPlatform.android,
        source: InstallSource.zapstore,
        appVersion: '1.2.3',
      );

      expect(metadata.toJson(), {
        'platform': 'android',
        'installChannel': 'zapstore',
        'appVersion': '1.2.3',
      });
    });

    test('omits unknown platform, channel and invalid version keys', () {
      final metadata = PushDeviceMetadata.resolve(
        platform: TargetPlatform.linux,
        source: InstallSource.sideload,
        appVersion: 'unknown',
      );

      expect(metadata.toJson(), isEmpty);
    });

    test('omits unrecognized install channel on a supported platform', () {
      final metadata = PushDeviceMetadata.resolve(
        platform: TargetPlatform.android,
        source: InstallSource.sideload,
        appVersion: '1.2.3',
      );

      expect(metadata.toJson(), {'platform': 'android', 'appVersion': '1.2.3'});
    });
  });
}
