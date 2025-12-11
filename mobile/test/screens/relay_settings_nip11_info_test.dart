// ABOUTME: Widget tests for NIP-11 relay info display in relay settings
// ABOUTME: Validates that relay name, description, supported NIPs, and web link are shown

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNostrService extends Mock implements INostrService {}

class MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

void main() {
  group('RelaySettingsScreen NIP-11 Info', () {
    late MockNostrService mockNostrService;
    late MockRelayCapabilityService mockCapabilityService;
    late MockRelayStatisticsService mockStatsService;

    setUp(() {
      mockNostrService = MockNostrService();
      mockCapabilityService = MockRelayCapabilityService();
      mockStatsService = MockRelayStatisticsService();
      SharedPreferences.setMockInitialValues({});
    });

    Widget createTestWidget(
      List<String> configuredRelays, {
      RelayCapabilities? capabilities,
    }) {
      when(() => mockNostrService.relays).thenReturn(configuredRelays);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(configuredRelays.length);

      // Mock stats service - create a stats object and set isConnected
      final relayUrl = configuredRelays.isNotEmpty
          ? configuredRelays.first
          : 'wss://test.relay';
      final stats = RelayStatistics(relayUrl: relayUrl);
      stats.isConnected = true;
      when(() => mockStatsService.getStatistics(any())).thenReturn(stats);
      when(
        () => mockStatsService.getAllStatistics(),
      ).thenReturn({relayUrl: stats});

      // Mock capability service
      if (capabilities != null) {
        when(
          () => mockCapabilityService.getRelayCapabilities(any()),
        ).thenAnswer((_) async => capabilities);
      } else {
        when(
          () => mockCapabilityService.getRelayCapabilities(any()),
        ).thenThrow(RelayCapabilityException('Not found', 'wss://test.relay'));
      }

      // Create the statistics map for the stream provider
      final statsMap = <String, RelayStatistics>{relayUrl: stats};

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          relayCapabilityServiceProvider.overrideWithValue(
            mockCapabilityService,
          ),
          relayStatisticsServiceProvider.overrideWithValue(mockStatsService),
          relayStatisticsStreamProvider.overrideWith(
            (ref) => Stream.value(statsMap),
          ),
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

    testWidgets('shows relay info section header when expanded', (
      tester,
    ) async {
      final capabilities = RelayCapabilities(
        relayUrl: 'wss://relay.divine.video',
        name: 'Divine Video Relay',
        description: 'Specialized relay for short vertical videos',
        supportedNips: [1, 2, 9, 11, 12, 71],
        rawData: {},
      );

      await tester.pumpWidget(
        createTestWidget([
          'wss://relay.divine.video',
        ], capabilities: capabilities),
      );
      await tester.pumpAndSettle();

      // Find and tap the expansion tile
      final expansionTile = find.byType(ExpansionTile);
      expect(expansionTile, findsOneWidget);

      await tester.tap(expansionTile);
      await tester.pumpAndSettle();

      // Should show "About Relay" section header
      expect(find.text('About Relay'), findsOneWidget);
    });

    testWidgets('displays relay name from NIP-11', (tester) async {
      final capabilities = RelayCapabilities(
        relayUrl: 'wss://relay.divine.video',
        name: 'Divine Video Relay',
        description: 'Specialized relay for short vertical videos',
        supportedNips: [1, 2, 9, 11],
        rawData: {},
      );

      await tester.pumpWidget(
        createTestWidget([
          'wss://relay.divine.video',
        ], capabilities: capabilities),
      );
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('Divine Video Relay'), findsOneWidget);
    });

    testWidgets('displays relay description from NIP-11', (tester) async {
      final capabilities = RelayCapabilities(
        relayUrl: 'wss://relay.divine.video',
        name: 'Divine Video Relay',
        description: 'Specialized relay for short vertical videos',
        supportedNips: [1, 2, 9, 11],
        rawData: {},
      );

      await tester.pumpWidget(
        createTestWidget([
          'wss://relay.divine.video',
        ], capabilities: capabilities),
      );
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(
        find.text('Specialized relay for short vertical videos'),
        findsOneWidget,
      );
    });

    testWidgets('displays supported NIPs as formatted string', (tester) async {
      final capabilities = RelayCapabilities(
        relayUrl: 'wss://relay.divine.video',
        name: 'Divine Video Relay',
        description: 'Test relay',
        supportedNips: [1, 2, 9, 11, 12, 71],
        rawData: {},
      );

      await tester.pumpWidget(
        createTestWidget([
          'wss://relay.divine.video',
        ], capabilities: capabilities),
      );
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Should show "Supported NIPs" label
      expect(find.text('Supported NIPs'), findsOneWidget);
      // Should show the NIPs as a formatted string
      expect(find.text('1, 2, 9, 11, 12, 71'), findsOneWidget);
    });

    testWidgets('shows web link button to open relay page', (tester) async {
      final capabilities = RelayCapabilities(
        relayUrl: 'wss://relay.divine.video',
        name: 'Divine Video Relay',
        description: 'Test relay',
        supportedNips: [1, 2, 11],
        rawData: {},
      );

      await tester.pumpWidget(
        createTestWidget([
          'wss://relay.divine.video',
        ], capabilities: capabilities),
      );
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Should show "View Website" button
      expect(find.text('View Website'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsWidgets);
    });

    testWidgets('shows software info when available', (tester) async {
      final capabilities = RelayCapabilities(
        relayUrl: 'wss://relay.divine.video',
        name: 'Divine Video Relay',
        description: 'Test relay',
        supportedNips: [1, 2, 11],
        rawData: {'software': 'nosflare', 'version': '0.3.0'},
      );

      await tester.pumpWidget(
        createTestWidget([
          'wss://relay.divine.video',
        ], capabilities: capabilities),
      );
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Should show software info
      expect(find.text('Software'), findsOneWidget);
      expect(find.text('nosflare v0.3.0'), findsOneWidget);
    });

    testWidgets('handles missing NIP-11 info gracefully', (tester) async {
      await tester.pumpWidget(createTestWidget(['wss://relay.divine.video']));
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Should not crash, and should not show "About Relay" if no info
      // The screen should still be functional
      expect(find.text('Connection'), findsOneWidget);
    });

    testWidgets('shows loading indicator while fetching NIP-11', (
      tester,
    ) async {
      // Use a completer to control when the fetch completes
      final completer = Completer<RelayCapabilities>();

      // Mock a fetch that doesn't complete until we say so
      when(
        () => mockCapabilityService.getRelayCapabilities(any()),
      ).thenAnswer((_) => completer.future);

      when(
        () => mockNostrService.relays,
      ).thenReturn(['wss://relay.divine.video']);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      final loadingStats = RelayStatistics(
        relayUrl: 'wss://relay.divine.video',
      );
      loadingStats.isConnected = true;
      when(
        () => mockStatsService.getStatistics(any()),
      ).thenReturn(loadingStats);
      when(
        () => mockStatsService.getAllStatistics(),
      ).thenReturn({'wss://relay.divine.video': loadingStats});

      // Create the statistics map for the stream provider
      final loadingStatsMap = <String, RelayStatistics>{
        'wss://relay.divine.video': loadingStats,
      };

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          relayCapabilityServiceProvider.overrideWithValue(
            mockCapabilityService,
          ),
          relayStatisticsServiceProvider.overrideWithValue(mockStatsService),
          relayStatisticsStreamProvider.overrideWith(
            (ref) => Stream.value(loadingStatsMap),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: VineTheme.theme,
            home: const RelaySettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();

      // Should show loading indicator while fetching
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer error
      completer.complete(
        RelayCapabilities(
          relayUrl: 'wss://relay.divine.video',
          name: 'Test',
          rawData: {},
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
