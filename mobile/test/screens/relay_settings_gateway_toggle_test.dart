// ABOUTME: Widget tests for gateway toggle in relay settings
// ABOUTME: Validates visibility, state changes, and persistence

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNostrService extends Mock implements INostrService {}

void main() {
  group('RelaySettingsScreen Gateway Toggle', () {
    late MockNostrService mockNostrService;

    setUp(() {
      mockNostrService = MockNostrService();
      SharedPreferences.setMockInitialValues({});
    });

    Widget createTestWidget(List<String> configuredRelays) {
      when(() => mockNostrService.relays).thenReturn(configuredRelays);
      when(() => mockNostrService.connectedRelayCount).thenReturn(configuredRelays.length);

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
        ],
      );

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VineTheme.theme,
          home: const RelaySettingsScreen(),
        ),
      );
    }

    testWidgets('shows gateway section when divine relay configured', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://relay.divine.video']));
      await tester.pumpAndSettle();

      expect(find.text('REST Gateway'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.byKey(const Key('gateway_toggle')), findsOneWidget);
    });

    testWidgets('hides gateway section when divine relay not configured', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://other.relay']));
      await tester.pumpAndSettle();

      expect(find.text('REST Gateway'), findsNothing);
      expect(find.byKey(const Key('gateway_toggle')), findsNothing);
    });

    testWidgets('shows gateway section when divine relay is one of many', (tester) async {
      await tester.pumpWidget(createTestWidget([
        'wss://other.relay',
        'wss://relay.divine.video',
      ]));
      await tester.pumpAndSettle();

      expect(find.text('REST Gateway'), findsOneWidget);
    });

    testWidgets('toggle starts in enabled state by default', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://relay.divine.video']));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('gateway_toggle')),
      );

      expect(switchWidget.value, true);
    });

    testWidgets('toggle changes gateway enabled state', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://relay.divine.video']));
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('gateway_toggle'));
      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify toggle is now off
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, false);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('relay_gateway_enabled'), false);
    });

    testWidgets('displays description text', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://relay.divine.video']));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Use caching gateway for faster loading of discovery feeds, hashtags, and profiles.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Only available when using relay.divine.video'),
        findsOneWidget,
      );
    });

    testWidgets('uses VineTheme.vineGreen for toggle and icon', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://relay.divine.video']));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('gateway_toggle')),
      );
      expect(switchWidget.activeTrackColor, VineTheme.vineGreen);

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.bolt));
      expect(iconWidget.color, VineTheme.vineGreen);
    });
  });
}
