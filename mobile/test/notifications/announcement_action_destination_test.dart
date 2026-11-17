import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/announcement_action_destination.dart';
import 'package:openvine/services/push_device_metadata.dart';

void main() {
  PushDeviceMetadata device(
    TargetPlatform platform,
    InstallSource source,
    String version,
  ) => PushDeviceMetadata.resolve(
    platform: platform,
    source: source,
    appVersion: version,
  );

  group('PushDeviceMetadata.resolve', () {
    test(
      'registration metadata records actual store and marketing version',
      () {
        for (final (platform, source, channel) in [
          (TargetPlatform.iOS, InstallSource.appStore, 'app_store'),
          (TargetPlatform.android, InstallSource.playStore, 'google_play'),
          (TargetPlatform.android, InstallSource.zapstore, 'zapstore'),
        ]) {
          final metadata = device(platform, source, '1.2.3');
          expect(metadata.toJson(), {
            'platform': platform == TargetPlatform.iOS ? 'ios' : 'android',
            'installChannel': channel,
            'appVersion': '1.2.3',
          });
        }
        expect(
          device(
            TargetPlatform.android,
            InstallSource.sideload,
            '1.2.3',
          ).toJson(),
          {'platform': 'android', 'appVersion': '1.2.3'},
        );
        expect(
          device(
            TargetPlatform.iOS,
            InstallSource.testFlight,
            '1.2.3',
          ).toJson(),
          {'platform': 'ios', 'appVersion': '1.2.3'},
        );
        for (final invalid in [
          '1.2',
          '01.2.3',
          '1.2.3+4',
          '1.2.3-beta',
          '1000000.2.3',
        ]) {
          expect(
            device(
              TargetPlatform.android,
              InstallSource.playStore,
              invalid,
            ).toJson(),
            {'platform': 'android', 'installChannel': 'google_play'},
          );
        }
      },
    );
  });

  group('announcementActionDestination', () {
    test('update action uses canonical store link only for an older matching install', () {
      const action = UpdateAppAnnouncementAction(
        platform: 'android',
        channel: 'zapstore',
        version: '1.3.0',
      );
      expect(
        announcementActionDestination(
          action,
          device(TargetPlatform.android, InstallSource.zapstore, '1.2.3'),
        ),
        Uri.parse(DownloadUrls.zapstore),
      );
      for (final metadata in [
        device(TargetPlatform.android, InstallSource.zapstore, '1.3.0'),
        device(TargetPlatform.android, InstallSource.zapstore, '1.4.0'),
        device(TargetPlatform.android, InstallSource.playStore, '1.2.3'),
        device(TargetPlatform.android, InstallSource.sideload, '1.2.3'),
        device(TargetPlatform.iOS, InstallSource.appStore, '1.2.3'),
        device(TargetPlatform.android, InstallSource.zapstore, 'unknown'),
      ]) {
        expect(announcementActionDestination(action, metadata), isNull);
      }
    });

    test(
      'update actions use the established App Store and Play Store URLs',
      () {
        for (final (platform, source, channel, url) in [
          (
            TargetPlatform.iOS,
            InstallSource.appStore,
            'app_store',
            DownloadUrls.appStore,
          ),
          (
            TargetPlatform.android,
            InstallSource.playStore,
            'google_play',
            DownloadUrls.playStore,
          ),
        ]) {
          final metadata = device(platform, source, '1.2.3');
          expect(
            announcementActionDestination(
              UpdateAppAnnouncementAction(
                platform: metadata.platform!,
                channel: channel,
                version: '1.3.0',
              ),
              metadata,
            ),
            Uri.parse(url),
          );
          expect(announcementActionDestination(null, metadata), isNull);
        }
      },
    );

    test('contest action opens the validated official detail URL', () {
      final url = Uri.parse(
        'https://divine-challenges.pages.dev/contests/loop-2026',
      );
      expect(
        announcementActionDestination(
          ContestAnnouncementAction(url: url),
          device(TargetPlatform.iOS, InstallSource.appStore, '1.2.3'),
        ),
        url,
      );
    });
  });
}
