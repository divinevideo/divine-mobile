// ABOUTME: Tests for RelayDiagnosticScreen's retry-connection flow (#6934).
// ABOUTME: Pins the retry count wait and the API origin the REST check tests.

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/scroll.dart';
import '../helpers/test_provider_overrides.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group(RelayDiagnosticScreen, () {
    late _MockNostrClient nostrClient;
    late _MockVideoEventService videoEventService;

    setUp(() {
      nostrClient = _MockNostrClient();
      videoEventService = _MockVideoEventService();
    });

    void stubScreenDependencies() {
      when(nostrClient.getRelayStats).thenAnswer((_) async => null);
      when(nostrClient.retryDisconnectedRelays).thenAnswer((_) async {});
      when(() => nostrClient.connectedRelayCount).thenReturn(2);
      when(() => nostrClient.configuredRelays).thenReturn(const []);
      when(() => nostrClient.connectedRelays).thenReturn(const []);
      when(() => nostrClient.relayStatuses).thenReturn(const {});
      when(() => nostrClient.isInitialized).thenReturn(true);

      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.isLoading).thenReturn(false);
      when(() => videoEventService.error).thenReturn(null);
    }

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const RelayDiagnosticScreen(),
          mockNostrService: nostrClient,
          mockVideoEventService: videoEventService,
        ),
      );
      await tester.pump();
    }

    // The body is a plain ListView, so the retry button sits below the fold
    // and has no Element until it is scrolled into view.
    Future<void> scrollToRetry(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // Lay out the final ensureVisible scroll before tapping, without
      // advancing the clock that the retry assertions deliberately pin.
      await tester.pump();
    }

    group('initial refresh', () {
      late LogCaptureService logCapture;

      setUp(() async {
        logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
      });

      tearDown(() async {
        await logCapture.clearAllLogs();
      });

      testWidgets(
        'logs no failure when the screen closes before relay stats arrive',
        (tester) async {
          stubScreenDependencies();
          final statsGate = Completer<Map<String, dynamic>?>();
          when(nostrClient.getRelayStats).thenAnswer((_) => statsGate.future);

          await pumpScreen(tester);
          verify(nostrClient.getRelayStats).called(1);

          await tester.pumpWidget(const SizedBox());
          statsGate.complete(<String, dynamic>{});
          for (var i = 0; i < 4; i++) {
            await tester.pump();
          }

          final failures = logCapture.getRecentLogs().where(
            (entry) =>
                entry.name == 'RelayDiagnostic' &&
                entry.level == LogLevel.error,
          );
          expect(failures, isEmpty);
        },
      );
    });

    group('retry connection', () {
      testWidgets('reports the connected count without a wall-clock wait', (
        tester,
      ) async {
        stubScreenDependencies();
        await pumpScreen(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(RelayDiagnosticScreen)),
        );

        await scrollToRetry(tester, l10n.relayDiagnosticRetryConnection);
        await tester.tap(find.text(l10n.relayDiagnosticRetryConnection));

        // Flush the awaited chain WITHOUT advancing the clock. Every pump here
        // is zero-duration, so a `Future.delayed` anywhere in _retryConnection
        // would leave the snackbar unbuilt and this assertion would fail —
        // which is exactly what it is here to catch. retryDisconnectedRelays
        // already awaits down to the WebSocket handshake, so once it resolves
        // connectedRelayCount is final and there is nothing left to wait for.
        for (var i = 0; i < 8; i++) {
          await tester.pump();
        }

        expect(
          find.text(l10n.relayDiagnosticConnectedToRelays(2)),
          findsOneWidget,
        );
      });

      testWidgets('reads the count only after the retry future resolves', (
        tester,
      ) async {
        stubScreenDependencies();
        // The count must be sampled after retryDisconnectedRelays completes,
        // not before — otherwise the snackbar reports a stale number. Holding
        // the future open proves the read is downstream of it.
        final gate = Completer<void>();
        when(
          nostrClient.retryDisconnectedRelays,
        ).thenAnswer((_) => gate.future);
        when(() => nostrClient.connectedRelayCount).thenReturn(0);

        await pumpScreen(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(RelayDiagnosticScreen)),
        );

        await scrollToRetry(tester, l10n.relayDiagnosticRetryConnection);
        await tester.tap(find.text(l10n.relayDiagnosticRetryConnection));
        await tester.pump();

        expect(
          find.text(l10n.relayDiagnosticFailedToConnect),
          findsNothing,
          reason: 'no outcome may be reported while the retry is still open',
        );

        when(() => nostrClient.connectedRelayCount).thenReturn(3);
        gate.complete();
        for (var i = 0; i < 8; i++) {
          await tester.pump();
        }

        expect(
          find.text(l10n.relayDiagnosticConnectedToRelays(3)),
          findsOneWidget,
          reason: 'the count settled by the retry is the one reported',
        );
      });
    });

    group('REST endpoints', () {
      testWidgets(
        'tests the environment API rather than the first configured relay',
        (tester) async {
          stubScreenDependencies();
          // Divine's relay removed, an unrelated relay first (#10841).
          when(
            () => nostrClient.configuredRelays,
          ).thenReturn(const ['wss://relay.example']);
          final blossomService = _MockBlossomUploadService();
          when(blossomService.testServerConnection).thenAnswer(
            (_) async =>
                const BlossomHealthCheckResult(isReachable: true, latencyMs: 1),
          );

          await tester.pumpWidget(
            testMaterialApp(
              home: const RelayDiagnosticScreen(),
              mockNostrService: nostrClient,
              mockVideoEventService: videoEventService,
              additionalOverrides: [
                blossomUploadServiceProvider.overrideWithValue(blossomService),
                currentEnvironmentProvider.overrideWithValue(
                  EnvironmentConfig.production,
                ),
              ],
            ),
          );
          await tester.pump();

          final l10n = lookupAppLocalizations(const Locale('en'));
          // The FunnelCake section's title is unique; its test button is the
          // last of the two that run this check.
          await scrollUntilTappable(
            tester,
            find.text(l10n.relayDiagnosticFunnelCakeApi),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(
            find.text(l10n.relayDiagnosticTestAllEndpoints).last,
          );
          // Each endpoint request completes on its own turn of the stubbed
          // HTTP client, so pump until the sequential checks have all reported.
          for (var i = 0; i < 30; i++) {
            await tester.pump();
          }

          expect(
            find.text(EnvironmentConfig.production.apiBaseUrl),
            findsOneWidget,
          );
          expect(find.text('https://relay.example'), findsNothing);
        },
      );

      for (final outcome in ['succeeds', 'fails']) {
        testWidgets(
          'leaves a closed screen alone when the Blossom check $outcome',
          (tester) async {
            stubScreenDependencies();
            final logCapture = LogCaptureService();
            await logCapture.clearAllLogs();
            addTearDown(logCapture.clearAllLogs);
            final blossomCheck = Completer<BlossomHealthCheckResult>();
            final blossomService = _MockBlossomUploadService();
            when(
              blossomService.testServerConnection,
            ).thenAnswer((_) => blossomCheck.future);

            await tester.pumpWidget(
              testMaterialApp(
                home: const RelayDiagnosticScreen(),
                mockNostrService: nostrClient,
                mockVideoEventService: videoEventService,
                additionalOverrides: [
                  blossomUploadServiceProvider.overrideWithValue(
                    blossomService,
                  ),
                ],
              ),
            );
            await tester.pump();
            final l10n = lookupAppLocalizations(const Locale('en'));
            await scrollUntilTappable(
              tester,
              find.text(l10n.relayDiagnosticBlossomServer),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(
              find.text(l10n.relayDiagnosticTestAllEndpoints).first,
            );
            await tester.pump();

            await tester.pumpWidget(const SizedBox());
            if (outcome == 'succeeds') {
              blossomCheck.complete(
                const BlossomHealthCheckResult(isReachable: true, latencyMs: 1),
              );
            } else {
              blossomCheck.completeError(Exception('connection reset'));
            }
            await tester.pump();

            expect(tester.takeException(), isNull);
            // A setState on the disposed screen would surface here as a
            // logged check failure rather than as an exception.
            final setStateFailures = logCapture.getRecentLogs().where(
              (entry) =>
                  entry.name == 'RelayDiagnostic' &&
                  entry.level == LogLevel.error &&
                  entry.message.contains('setState'),
            );
            expect(setStateFailures, isEmpty);
          },
        );
      }
    });
  });
}
