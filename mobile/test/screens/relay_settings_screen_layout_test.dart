// ABOUTME: Widget tests for RelaySettingsScreen layout.
// ABOUTME: Verifies the Nostr relay menu aligns with other settings screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_list_repository_provider.dart';
import 'package:openvine/repositories/relay_list_repository.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/finders.dart';

class _MockNostrService extends Mock implements NostrClient {}

/// The real provider reaches AuthService and SharedPreferences, which this
/// layout-focused suite does not wire up. Publishing always succeeds here so
/// the assertions stay about the screen.
class _FakeRelayListRepository implements RelayListRepository {
  @override
  Future<RelayListPublishResult> publishConfiguredRelayList() async =>
      const RelayListPublishResult.published();

  @override
  Future<RelayListPublishResult> retryDirtyPublish() async =>
      const RelayListPublishResult.published();

  @override
  bool isDirty(String pubkey) => false;
}

class _FailingRelayListRepository extends _FakeRelayListRepository {
  @override
  Future<RelayListPublishResult> publishConfiguredRelayList() async =>
      RelayListPublishResult.failed(
        StateError('no indexer accepted'),
        StackTrace.current,
      );
}

class _MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class _MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  setUpAll(() {
    registerFallbackValue(RelayAddSource.automatic);
  });

  testWidgets(
    'RelaySettingsScreen constrains menu content width on wide screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});

      final nostrService = _MockNostrService();
      final capabilityService = _MockRelayCapabilityService();
      final statsService = _MockRelayStatisticsService();
      final videoEventService = _MockVideoEventService();
      final stats = RelayStatistics(relayUrl: 'wss://relay.divine.video')
        ..isConnected = true;

      when(
        () => nostrService.configuredRelays,
      ).thenReturn(['wss://relay.divine.video']);
      when(
        () => nostrService.defaultRelayUrl,
      ).thenReturn('wss://relay.divine.video');
      when(() => nostrService.connectedRelayCount).thenReturn(1);
      when(() => statsService.getStatistics(any())).thenReturn(stats);
      when(
        statsService.getAllStatistics,
      ).thenReturn({'wss://relay.divine.video': stats});
      when(() => capabilityService.getRelayCapabilities(any())).thenThrow(
        RelayCapabilityException('Not found', 'wss://relay.divine.video'),
      );

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrService),
          relayCapabilityServiceProvider.overrideWithValue(capabilityService),
          relayStatisticsServiceProvider.overrideWithValue(statsService),
          relayStatisticsStreamProvider.overrideWith(
            (_) => Stream.value({'wss://relay.divine.video': stats}),
          ),
          relayListRepositoryProvider.overrideWithValue(
            _FakeRelayListRepository(),
          ),
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const RelaySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    },
  );

  testWidgets('warns before removing the Divine relay', (tester) async {
    SharedPreferences.setMockInitialValues({});

    const defaultRelay = 'wss://relay.divine.video/';
    const configuredRelay = 'wss://relay.divine.video';
    final nostrService = _MockNostrService();
    final capabilityService = _MockRelayCapabilityService();
    final statsService = _MockRelayStatisticsService();
    final videoEventService = _MockVideoEventService();
    final stats = RelayStatistics(relayUrl: configuredRelay)
      ..isConnected = true;

    when(() => nostrService.defaultRelayUrl).thenReturn(defaultRelay);
    when(() => nostrService.configuredRelays).thenReturn([configuredRelay]);
    when(() => nostrService.connectedRelayCount).thenReturn(1);
    when(statsService.getAllStatistics).thenReturn({configuredRelay: stats});
    when(
      () => capabilityService.getRelayCapabilities(any()),
    ).thenThrow(RelayCapabilityException('Not found', configuredRelay));

    final container = ProviderContainer(
      overrides: [
        nostrServiceProvider.overrideWithValue(nostrService),
        relayCapabilityServiceProvider.overrideWithValue(capabilityService),
        relayStatisticsServiceProvider.overrideWithValue(statsService),
        relayStatisticsStreamProvider.overrideWith(
          (_) => Stream.value({defaultRelay: stats}),
        ),
        relayListRepositoryProvider.overrideWithValue(
          _FakeRelayListRepository(),
        ),
        videoEventServiceProvider.overrideWithValue(videoEventService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const RelaySettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    final removeButton = findByTooltip(l10n.relaySettingsRemoveRelayTooltip);
    expect(removeButton, findsOneWidget);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.relaySettingsRemoveDefaultRelayTitle),
      findsOneWidget,
    );
    expect(
      find.text(l10n.relaySettingsRemoveDefaultRelayMessage(configuredRelay)),
      findsOneWidget,
    );
  });

  testWidgets('can restore Divine relay while custom relays remain', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    const defaultRelay = 'wss://relay.divine.video';
    const customRelay = 'wss://relay.example.com';
    final nostrService = _MockNostrService();
    final capabilityService = _MockRelayCapabilityService();
    final statsService = _MockRelayStatisticsService();
    final videoEventService = _MockVideoEventService();
    final stats = RelayStatistics(relayUrl: customRelay)..isConnected = true;

    when(() => nostrService.defaultRelayUrl).thenReturn(defaultRelay);
    when(() => nostrService.configuredRelays).thenReturn([customRelay]);
    when(() => nostrService.connectedRelayCount).thenReturn(1);
    when(
      () => nostrService.addRelay(defaultRelay, source: RelayAddSource.user),
    ).thenAnswer((_) async => true);
    when(statsService.getAllStatistics).thenReturn({customRelay: stats});
    when(
      () => capabilityService.getRelayCapabilities(any()),
    ).thenThrow(RelayCapabilityException('Not found', customRelay));

    final container = ProviderContainer(
      overrides: [
        nostrServiceProvider.overrideWithValue(nostrService),
        relayCapabilityServiceProvider.overrideWithValue(capabilityService),
        relayStatisticsServiceProvider.overrideWithValue(statsService),
        relayStatisticsStreamProvider.overrideWith(
          (_) => Stream.value({customRelay: stats}),
        ),
        relayListRepositoryProvider.overrideWithValue(
          _FakeRelayListRepository(),
        ),
        videoEventServiceProvider.overrideWithValue(videoEventService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const RelaySettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.relaySettingsRestoreDefaultRelay), findsOneWidget);

    await tester.tap(find.text(l10n.relaySettingsRestoreDefaultRelay));
    await tester.pumpAndSettle();

    verify(
      () => nostrService.addRelay(defaultRelay, source: RelayAddSource.user),
    ).called(1);
    expect(
      find.text(l10n.relaySettingsRestoredDefault(defaultRelay)),
      findsOneWidget,
    );
  });

  group('Add Relay validation (#3362)', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required _MockNostrService nostrService,
      RelayListRepository? relayListRepository,
    }) async {
      SharedPreferences.setMockInitialValues({});

      final capabilityService = _MockRelayCapabilityService();
      final statsService = _MockRelayStatisticsService();
      final videoEventService = _MockVideoEventService();

      when(() => nostrService.configuredRelays).thenReturn(const []);
      when(() => nostrService.connectedRelayCount).thenReturn(0);
      when(statsService.getAllStatistics).thenReturn(const {});
      when(
        () => capabilityService.getRelayCapabilities(any()),
      ).thenThrow(RelayCapabilityException('Not found', 'wss://x'));

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrService),
          relayCapabilityServiceProvider.overrideWithValue(capabilityService),
          relayStatisticsServiceProvider.overrideWithValue(statsService),
          relayStatisticsStreamProvider.overrideWith(
            (_) => const Stream<Map<String, RelayStatistics>>.empty(),
          ),
          relayListRepositoryProvider.overrideWithValue(
            relayListRepository ?? _FakeRelayListRepository(),
          ),
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );
      addTearDown(container.dispose);

      // The screen uses go_router's `dialogContext.pop()` to close its
      // Add Relay dialog, so the test must host it inside a GoRouter.
      final router = GoRouter(
        initialLocation: RelaySettingsScreen.path,
        routes: [
          GoRoute(
            path: RelaySettingsScreen.path,
            name: RelaySettingsScreen.routeName,
            builder: (_, _) => const RelaySettingsScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openAddSheetAndSubmit(
      WidgetTester tester,
      String url,
      AppLocalizations l10n,
    ) async {
      // The empty-relay state surfaces an "Add custom relay" button; it
      // opens the same sheet that the populated state's "Add relay" button
      // does. Tap whichever is showing.
      await tester.tap(find.text(l10n.relaySettingsAddCustomRelay));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), url);
      await tester.pumpAndSettle();

      // The sheet's confirm button uses relaySettingsAdd ("Add").
      await tester.tap(find.text(l10n.relaySettingsAdd));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects ws:// non-loopback URL with insecure-url snackbar', (
      tester,
    ) async {
      final nostrService = _MockNostrService();
      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddSheetAndSubmit(tester, 'ws://attacker.example.com', l10n);

      expect(find.text(l10n.relaySettingsInsecureUrl), findsOneWidget);
      verifyNever(
        () => nostrService.addRelay(any(), source: any(named: 'source')),
      );
    });

    testWidgets('accepts wss:// URL and forwards to NostrClient', (
      tester,
    ) async {
      final nostrService = _MockNostrService();
      when(
        () => nostrService.addRelay(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => true);

      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddSheetAndSubmit(tester, 'wss://relay.example.com', l10n);

      verify(
        () => nostrService.addRelay(
          'wss://relay.example.com',
          source: RelayAddSource.user,
        ),
      ).called(1);
    });

    testWidgets('does not autocorrect a typed relay address (#8993)', (
      tester,
    ) async {
      await pumpScreen(tester, nostrService: _MockNostrService());

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.relaySettingsAddCustomRelay));
      await tester.pumpAndSettle();

      // iOS autocorrect rewrote `ws://` to `we://` as soon as `:` was typed,
      // and the address was then rejected as invalid.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.keyboardType, TextInputType.url);
    });

    testWidgets('warns when added relay is saved but not connected', (
      tester,
    ) async {
      const relay = 'wss://pending.example.com';
      final nostrService = _MockNostrService();
      final configuredRelays = <String>[];
      when(
        () => nostrService.defaultRelayUrl,
      ).thenReturn('wss://relay.divine.video');
      when(
        () => nostrService.configuredRelays,
      ).thenAnswer((_) => List.unmodifiable(configuredRelays));
      when(
        () => nostrService.addRelay(relay, source: RelayAddSource.user),
      ).thenAnswer((_) async {
        configuredRelays.add(relay);
        return false;
      });

      await pumpScreen(tester, nostrService: nostrService);
      when(
        () => nostrService.configuredRelays,
      ).thenAnswer((_) => List.unmodifiable(configuredRelays));

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddSheetAndSubmit(tester, relay, l10n);

      expect(find.text(l10n.relaySettingsFailedToConnectCheck), findsOneWidget);
      expect(find.text(l10n.relaySettingsAddedRelay(relay)), findsNothing);
      verify(
        () => nostrService.addRelay(relay, source: RelayAddSource.user),
      ).called(1);
    });

    testWidgets(
      'still reports the connection failure when the relay list also '
      'failed to publish',
      (tester) async {
        const relay = 'wss://pending.example.com';
        final nostrService = _MockNostrService();
        final configuredRelays = <String>[];
        when(
          () => nostrService.defaultRelayUrl,
        ).thenReturn('wss://relay.divine.video');
        when(
          () => nostrService.configuredRelays,
        ).thenAnswer((_) => List.unmodifiable(configuredRelays));
        when(
          () => nostrService.addRelay(relay, source: RelayAddSource.user),
        ).thenAnswer((_) async {
          configuredRelays.add(relay);
          return false;
        });

        await pumpScreen(
          tester,
          nostrService: nostrService,
          relayListRepository: _FailingRelayListRepository(),
        );
        // pumpScreen pins configuredRelays to const []; restore the live view
        // so the cubit sees the relay that addRelay just saved locally.
        when(
          () => nostrService.configuredRelays,
        ).thenAnswer((_) => List.unmodifiable(configuredRelays));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await openAddSheetAndSubmit(tester, relay, l10n);

        expect(
          find.textContaining(l10n.relaySettingsFailedToConnectCheck),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.relaySettingsSavedLocallyPublishPending),
          findsOneWidget,
        );
      },
    );

    testWidgets('accepts uppercase WSS:// URL and forwards to NostrClient', (
      tester,
    ) async {
      final nostrService = _MockNostrService();
      when(
        () => nostrService.addRelay(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => true);

      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddSheetAndSubmit(tester, 'WSS://relay.example.com', l10n);

      verify(
        () => nostrService.addRelay(
          'WSS://relay.example.com',
          source: RelayAddSource.user,
        ),
      ).called(1);
    });

    testWidgets('shows malformed-URL message for empty-host wss://', (
      tester,
    ) async {
      // Self-review fix: a bare scheme like `wss://` previously surfaced
      // the security-relevant insecure-URL message, which told the user
      // to do exactly what they typed. After the fix it falls through to
      // the malformed-URL message.
      final nostrService = _MockNostrService();
      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await openAddSheetAndSubmit(tester, 'wss://', l10n);

      expect(find.text(l10n.relaySettingsInvalidUrl), findsOneWidget);
      expect(find.text(l10n.relaySettingsInsecureUrl), findsNothing);
      verifyNever(
        () => nostrService.addRelay(any(), source: any(named: 'source')),
      );
    });

    testWidgets(
      'shows malformed-URL message for https:// input (relays are WS-only)',
      (tester) async {
        // Reviewer ask on PR #3806: form previously accepted https:// /
        // http://, but `normalizeRelayUrl` only accepts wss:// /
        // loopback ws://, so they fell through to a generic "failed to add"
        // message. Surface the structurally-bad-input bucket instead.
        final nostrService = _MockNostrService();
        await pumpScreen(tester, nostrService: nostrService);

        final l10n = lookupAppLocalizations(const Locale('en'));
        await openAddSheetAndSubmit(tester, 'https://relay.example.com', l10n);

        expect(find.text(l10n.relaySettingsInvalidUrl), findsOneWidget);
        expect(find.text(l10n.relaySettingsInsecureUrl), findsNothing);
        verifyNever(
          () => nostrService.addRelay(any(), source: any(named: 'source')),
        );
      },
    );

    testWidgets(
      'shows malformed-URL message for http:// input (relays are WS-only)',
      (tester) async {
        final nostrService = _MockNostrService();
        await pumpScreen(tester, nostrService: nostrService);

        final l10n = lookupAppLocalizations(const Locale('en'));
        await openAddSheetAndSubmit(
          tester,
          'http://attacker.example.com',
          l10n,
        );

        expect(find.text(l10n.relaySettingsInvalidUrl), findsOneWidget);
        expect(find.text(l10n.relaySettingsInsecureUrl), findsNothing);
        verifyNever(
          () => nostrService.addRelay(any(), source: any(named: 'source')),
        );
      },
    );

    testWidgets(
      'restore-default snackbar names the environment default relay',
      (tester) async {
        const envDefaultRelay = 'wss://relay.staging.divine.video';
        final nostrService = _MockNostrService();
        when(() => nostrService.defaultRelayUrl).thenReturn(envDefaultRelay);
        when(
          () => nostrService.addRelay(
            envDefaultRelay,
            source: RelayAddSource.user,
          ),
        ).thenAnswer((_) async => true);

        await pumpScreen(tester, nostrService: nostrService);

        when(
          () => nostrService.configuredRelays,
        ).thenReturn(['wss://not-the-default.example']);

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.relaySettingsRestoreDefaultRelay));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.relaySettingsRestoredDefault(envDefaultRelay)),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.relaySettingsRestoredDefault('wss://not-the-default.example'),
          ),
          findsNothing,
        );
        verify(
          () => nostrService.addRelay(
            envDefaultRelay,
            source: RelayAddSource.user,
          ),
        ).called(1);
      },
    );
  });

  group('Retry connection', () {
    const relay = 'wss://relay.divine.video';

    Future<void> pumpScreen(
      WidgetTester tester, {
      required _MockNostrService nostrService,
    }) async {
      SharedPreferences.setMockInitialValues({});

      final capabilityService = _MockRelayCapabilityService();
      final statsService = _MockRelayStatisticsService();
      final videoEventService = _MockVideoEventService();
      final stats = RelayStatistics(relayUrl: relay);

      when(() => nostrService.configuredRelays).thenReturn([relay]);
      when(() => nostrService.defaultRelayUrl).thenReturn(relay);
      when(() => statsService.getStatistics(any())).thenReturn(stats);
      when(statsService.getAllStatistics).thenReturn({relay: stats});
      when(
        () => capabilityService.getRelayCapabilities(any()),
      ).thenThrow(RelayCapabilityException('Not found', relay));
      when(videoEventService.resetAndResubscribeAll).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrService),
          relayCapabilityServiceProvider.overrideWithValue(capabilityService),
          relayStatisticsServiceProvider.overrideWithValue(statsService),
          relayStatisticsStreamProvider.overrideWith(
            (_) => Stream.value({relay: stats}),
          ),
          relayListRepositoryProvider.overrideWithValue(
            _FakeRelayListRepository(),
          ),
          videoEventServiceProvider.overrideWithValue(videoEventService),
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
      await tester.pumpAndSettle();
    }

    testWidgets('says relays are still connecting when the wait ends '
        'before any connects', (tester) async {
      final nostrService = _MockNostrService();
      when(() => nostrService.connectedRelayCount).thenReturn(0);
      when(
        nostrService.forceReconnectAll,
      ).thenAnswer((_) async => ForceReconnectOutcome.stillDialling);

      await pumpScreen(tester, nostrService: nostrService);

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.relaySettingsRetry));
      await tester.pumpAndSettle();
      // The result queues behind the "Forcing relay reconnection" snackbar.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text(l10n.relaySettingsStillConnecting), findsOneWidget);
      expect(find.text(l10n.relaySettingsFailedToConnectCheck), findsNothing);
      verify(nostrService.forceReconnectAll).called(1);
    });
  });
}
