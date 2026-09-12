// ABOUTME: Tests for RelayDiagnosticScreen's retry-connection flow (#6934).
// ABOUTME: Pins that the connected count is reported without a wall-clock wait.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

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
    }

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
  });
}
