import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('divine_video_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group(NativePlaybackDiagnostics, () {
    test('reads process-wide gauges without creating a player', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return <String, Object>{
          'version': 1,
          'platform': 'ios_on_mac',
          'appState': 'background',
          'footprintBytes': 650000000,
          'registeredPlayers': 0,
          'liveInstances': 1,
          'players': 1,
          'playingPlayers': 0,
          'textures': 0,
          'pendingLoads': 0,
          'disposedPlayers': 1,
          'framesDelivered': 125,
        };
      });

      final result = await NativePlaybackDiagnostics.read();

      expect(calls, ['getDiagnostics']);
      expect(result?.footprintBytes, 650000000);
      expect(result?.disposedPlayers, 1);
      expect(result?.pendingLoads, 0);
      expect(result?.framesDelivered, 125);
      expect(result?.toMap()['platform'], 'ios_on_mac');

      final values = result!.toMap();
      values['untrustedExtra'] = 'private@example.invalid';
      expect(
        NativePlaybackDiagnostics.fromMap(values)?.toMap(),
        isNot(contains('untrustedExtra')),
      );
      values['footprintBytes'] = -1;
      expect(NativePlaybackDiagnostics.fromMap(values)?.footprintBytes, -1);
      values['footprintBytes'] = -2;
      expect(NativePlaybackDiagnostics.fromMap(values), isNull);
      values['footprintBytes'] = 0;
      values['pendingLoads'] = -1;
      expect(NativePlaybackDiagnostics.fromMap(values), isNull);
    });

    test(
      'older binaries and unsupported platforms return unavailable',
      () async {
        expect(await NativePlaybackDiagnostics.read(), isNull);
      },
    );

    test(
      'rejects an unknown schema rather than reporting zero resources',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {'version': 2},
        );
        expect(await NativePlaybackDiagnostics.read(), isNull);
      },
    );

    test('malformed gauges cannot enter crash-report metadata', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'version': 1, 'platform': 'https://private.invalid'},
      );
      expect(await NativePlaybackDiagnostics.read(), isNull);
    });

    test('null response is unavailable, not an empty player pool', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await NativePlaybackDiagnostics.read(), isNull);
    });

    test('platform failures remain visible to the sampling boundary', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(NativePlaybackDiagnostics.read, throwsA(isA<PlatformException>()));
    });
  });
}
