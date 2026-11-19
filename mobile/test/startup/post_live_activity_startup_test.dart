// ABOUTME: Tests that startup builds the post Live Activity device only when
// ABOUTME: the OS supports it, so iOS 16.0/16.1 keep the feature off entirely.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/post_live_activity_channel.dart';
import 'package:openvine/startup/app_bootstrap.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

class _MockCrashReporting extends Mock implements CrashReportingService {}

/// Answers the OS check without a native bridge; the channel's own test pins
/// how the real answer is read.
class _Channel extends PostLiveActivityChannel {
  _Channel({required this.osSupported}) : super(isSupported: () => false);

  final bool osSupported;

  @override
  Future<bool> isOsSupported() async => osSupported;
}

void main() {
  group('buildPostLiveActivityDevice', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('builds nothing when the OS predates Live Activities', () async {
      final device = await app.buildPostLiveActivityDevice(
        sharedPreferences: prefs,
        crashReporting: _MockCrashReporting(),
        channel: _Channel(osSupported: false),
      );

      expect(device, isNull);
    });

    test('builds the device on a supported OS', () async {
      final channel = _Channel(osSupported: true);

      final device = await app.buildPostLiveActivityDevice(
        sharedPreferences: prefs,
        crashReporting: _MockCrashReporting(),
        channel: channel,
      );
      addTearDown(() => device?.repository.dispose());

      expect(device, isNotNull);
      expect(device!.channel, same(channel));
    });
  });
}
