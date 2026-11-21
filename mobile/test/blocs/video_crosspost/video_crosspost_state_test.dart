import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/services/crossposting_api_client.dart';

void main() {
  group(VideoCrosspostState, () {
    group('selectedConnections', () {
      const instagram = CrosspostingConnection(
        id: 'connection-1',
        platform: CrosspostingPlatform.instagram,
        status: CrosspostingConnectionStatus.connected,
      );
      const tiktok = CrosspostingConnection(
        id: 'connection-2',
        platform: CrosspostingPlatform.tiktok,
        status: CrosspostingConnectionStatus.connected,
      );

      test('keeps only the connections the creator left selected', () {
        const state = VideoCrosspostState(
          connections: [instagram, tiktok],
          selectedPlatforms: {'tiktok'},
        );

        expect(state.selectedConnections, equals([tiktok]));
      });

      test('drops a selected platform that is no longer connected', () {
        const disconnected = CrosspostingConnection(
          id: 'connection-3',
          platform: CrosspostingPlatform.youtube,
          status: CrosspostingConnectionStatus.disconnected,
        );
        const state = VideoCrosspostState(
          connections: [instagram, disconnected],
          selectedPlatforms: {'instagram', 'youtube'},
        );

        expect(state.selectedConnections, equals([instagram]));
      });
    });
  });
}
