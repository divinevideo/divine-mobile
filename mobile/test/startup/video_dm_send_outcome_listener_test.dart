// ABOUTME: Tests that video DM send outcomes show a snackbar anywhere in the app
// ABOUTME: Covers the copy mapping and resubscribing when the outbox is replaced

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:openvine/startup/video_dm_send_outcome_listener.dart';

class _FakeOutbox extends Fake implements VideoDmOutbox {
  final controller = StreamController<VideoDmSendOutcome>.broadcast();

  @override
  Stream<VideoDmSendOutcome> get outcomes => controller.stream;
}

VideoDmSendOutcome _outcome(
  VideoDmOutcomeStatus status, {
  int sent = 0,
  int total = 1,
}) => VideoDmSendOutcome(status: status, sentCount: sent, total: total);

void main() {
  late _FakeOutbox outbox;
  late AppLocalizations l10n;

  setUp(() {
    outbox = _FakeOutbox();
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  tearDown(() => outbox.controller.close());

  Future<void> pumpApp(WidgetTester tester, StateProvider<VideoDmOutbox> p) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoDmOutboxProvider.overrideWith((ref) => ref.watch(p)),
        ],
        child: VideoDmSendOutcomeListener(
          child: MaterialApp(
            navigatorKey: NavigatorKeys.root,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
  }

  group(VideoDmSendOutcomeListener, () {
    final cases = <String, (VideoDmSendOutcome, String Function())>{
      'sent': (
        _outcome(VideoDmOutcomeStatus.sent, sent: 1),
        () => l10n.dmVideoSent,
      ),
      'partial': (
        _outcome(VideoDmOutcomeStatus.failed, sent: 1, total: 3),
        () => l10n.dmClipsPartlySent(1, 3),
      ),
      'tooLarge': (
        _outcome(VideoDmOutcomeStatus.tooLarge),
        () => l10n.dmVideoTooLarge('$videoDmMaxMegabytes'),
      ),
      'clipNotVerified': (
        _outcome(VideoDmOutcomeStatus.clipNotVerified),
        () => l10n.dmClipSendNotVerified,
      ),
      'failed': (
        _outcome(VideoDmOutcomeStatus.failed),
        () => l10n.dmVideoSendFailed,
      ),
    };

    for (final entry in cases.entries) {
      testWidgets('shows the ${entry.key} message', (tester) async {
        final provider = StateProvider<VideoDmOutbox>((ref) => outbox);
        await pumpApp(tester, provider);

        outbox.controller.add(entry.value.$1);
        await tester.pump();
        await tester.pump();

        expect(find.text(entry.value.$2()), findsOneWidget);
      });
    }

    testWidgets('survives the outbox being replaced', (tester) async {
      final replacement = _FakeOutbox();
      addTearDown(replacement.controller.close);
      final provider = StateProvider<VideoDmOutbox>((ref) => outbox);
      await pumpApp(tester, provider);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      container.read(provider.notifier).state = replacement;
      await tester.pump();

      outbox.controller.add(_outcome(VideoDmOutcomeStatus.failed));
      await tester.pump();
      expect(find.text(l10n.dmVideoSendFailed), findsNothing);

      replacement.controller.add(_outcome(VideoDmOutcomeStatus.sent, sent: 1));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.dmVideoSent), findsOneWidget);
    });
  });
}
