// ABOUTME: Tests the settings-card selection derived from crossposting state
// ABOUTME: Pins which platform the benefit and automatic-mode cards target

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/crossposting_settings/crossposting_settings_cubit.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

CrosspostingPlatformSettings _settings(
  CrosspostingPlatform platform, {
  CrosspostingConnectionStatus? status,
  bool supportsAutomatic = true,
  CrosspostingMode mode = CrosspostingMode.manual,
}) {
  return CrosspostingPlatformSettings(
    platform: platform,
    supportsAutomatic: supportsAutomatic,
    mode: mode,
    connection: status == null
        ? null
        : CrosspostingConnection(
            id: '${platform.wireName}-connection',
            platform: platform,
            status: status,
          ),
  );
}

void main() {
  group(CrosspostingSettingsState, () {
    group('allPlatformsDisconnected', () {
      test('is false when there are no platforms', () {
        expect(CrosspostingSettingsState().allPlatformsDisconnected, isFalse);
      });

      test('is true when no platform is connected', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(CrosspostingPlatform.instagram),
            _settings(
              CrosspostingPlatform.youtube,
              status: CrosspostingConnectionStatus.needsReauth,
            ),
          ],
        );

        expect(state.allPlatformsDisconnected, isTrue);
      });

      test('is false when any platform is connected', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(CrosspostingPlatform.instagram),
            _settings(
              CrosspostingPlatform.youtube,
              status: CrosspostingConnectionStatus.connected,
            ),
          ],
        );

        expect(state.allPlatformsDisconnected, isFalse);
      });
    });

    group('benefitCardPlatform', () {
      test('is the first platform when none is connected', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(CrosspostingPlatform.youtube),
            _settings(CrosspostingPlatform.instagram),
          ],
        );

        expect(state.benefitCardPlatform, CrosspostingPlatform.youtube);
      });

      test('is null once a platform is connected', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(CrosspostingPlatform.youtube),
            _settings(
              CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.connected,
            ),
          ],
        );

        expect(state.benefitCardPlatform, isNull);
      });

      test('is null when there are no platforms', () {
        expect(CrosspostingSettingsState().benefitCardPlatform, isNull);
      });
    });

    group('automaticModeCardPlatform', () {
      test('is the first connected platform not yet automatic', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(CrosspostingPlatform.instagram),
            _settings(
              CrosspostingPlatform.tiktok,
              status: CrosspostingConnectionStatus.connected,
              mode: CrosspostingMode.automatic,
            ),
            _settings(
              CrosspostingPlatform.youtube,
              status: CrosspostingConnectionStatus.connected,
            ),
          ],
        );

        expect(state.automaticModeCardPlatform, CrosspostingPlatform.youtube);
      });

      test('skips a connected platform that cannot run automatically', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(
              CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.connected,
              supportsAutomatic: false,
            ),
            _settings(
              CrosspostingPlatform.youtube,
              status: CrosspostingConnectionStatus.connected,
              mode: CrosspostingMode.disabled,
            ),
          ],
        );

        expect(state.automaticModeCardPlatform, CrosspostingPlatform.youtube);
      });

      test('is null when every connected platform is already automatic', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(
              CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.connected,
              mode: CrosspostingMode.automatic,
            ),
            _settings(CrosspostingPlatform.youtube),
          ],
        );

        expect(state.automaticModeCardPlatform, isNull);
      });

      test('ignores a platform that needs reauthorization', () {
        final state = CrosspostingSettingsState(
          entries: [
            _settings(
              CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.needsReauth,
            ),
          ],
        );

        expect(state.automaticModeCardPlatform, isNull);
      });
    });
  });
}
