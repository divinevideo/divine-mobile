// ABOUTME: Widget tests for NIP-11 relay info display in relay settings
// ABOUTME: Validates that relay name, description, supported NIPs, and web link are shown

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNostrService extends Mock implements NostrClient {}

class MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

class MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group('RelaySettingsScreen NIP-11 Info', () {
    late MockNostrService mockNostrService;
    late MockRelayCapabilityService mockCapabilityService;
    late MockRelayStatisticsService mockStatsService;
    late MockVideoEventService mockVideoEventService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      mockNostrService = MockNostrService();
      mockCapabilityService = MockRelayCapabilityService();
      mockStatsService = MockRelayStatisticsService();
      mockVideoEventService = MockVideoEventService();
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    Widget createTestWidget(
      List<String> configuredRelays, {
      RelayCapabilities? capabilities,
    }) {
      when(
        () => mockNostrService.configuredRelays,
      ).thenReturn(configuredRelays);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(configuredRelays.length);

      // Mock stats service - create a stats object and set isConnected
      final relayUrl = configuredRelays.isNotEmpty
          ? configuredRelays.first
          : 'wss://test.relay';
      when(() => mockNostrService.defaultRelayUrl).thenReturn(relayUrl);
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
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          relayCapabilityServiceProvider.overrideWithValue(
            mockCapabilityService,
          ),
          relayStatisticsServiceProvider.overrideWithValue(mockStatsService),
          relayStatisticsStreamProvider.overrideWith(
            (ref) => Stream.value(statsMap),
          ),
        ],
      );
      addTearDown(container.dispose);

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      final websiteButton = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, 'View Website'),
      );
      expect(websiteButton.leadingIcon, DivineIconName.arrowUpRight);
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
        () => mockNostrService.configuredRelays,
      ).thenReturn(['wss://relay.divine.video']);
      when(
        () => mockNostrService.defaultRelayUrl,
      ).thenReturn('wss://relay.divine.video');
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
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          relayCapabilityServiceProvider.overrideWithValue(
            mockCapabilityService,
          ),
          relayStatisticsServiceProvider.overrideWithValue(mockStatsService),
          relayStatisticsStreamProvider.overrideWith(
            (ref) => Stream.value(loadingStatsMap),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);

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
