// ABOUTME: Tests that video DM send outcomes show a snackbar anywhere in the app
// ABOUTME: Covers the copy mapping and resubscribing when the outbox is replaced

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/moderation_presentation.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:openvine/startup/video_dm_send_outcome_listener.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart' show LogCaptureService;

class _MockProfileReader extends Mock implements ProfileReader {}

class _FakeOutbox extends Fake implements VideoDmOutbox {
  final controller = StreamController<VideoDmSendOutcome>.broadcast();

  @override
  Stream<VideoDmSendOutcome> get outcomes => controller.stream;
}

VideoDmSendOutcome _outcome(
  VideoDmOutcomeStatus status, {
  int sent = 0,
  int total = 1,
  String conversationId = 'chat',
}) => VideoDmSendOutcome(
  conversationId: conversationId,
  recipientPubkey: '1' * 64,
  status: status,
  sentCount: sent,
  total: total,
);

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
          resolveChatName: (_, _) async => 'Test chat',
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

        expect(
          find.text(l10n.dmVideoOutcomeInChat('Test chat', entry.value.$2())),
          findsOneWidget,
        );
      });
    }

    testWidgets('queues behind another screen snackbar', (tester) async {
      final provider = StateProvider<VideoDmOutbox>((ref) => outbox);
      await pumpApp(tester, provider);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonRetry)));
      await tester.pumpAndSettle();
      outbox.controller.add(_outcome(VideoDmOutcomeStatus.failed));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(find.text(l10n.dmVideoSendFailed), findsNothing);
    });

    testWidgets('announces the visible chat outcome once without a snackbar', (
      tester,
    ) async {
      final router = GoRouter(
        navigatorKey: NavigatorKeys.root,
        initialLocation: '/inbox/conversation/chat',
        routes: [
          GoRoute(
            path: '/inbox/conversation/:id',
            builder: (_, _) => const Scaffold(body: SizedBox()),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoDmOutboxProvider.overrideWithValue(outbox)],
          child: VideoDmSendOutcomeListener(
            resolveChatName: (_, _) async => 'Test chat',
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      outbox.controller.add(_outcome(VideoDmOutcomeStatus.failed));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.takeAnnouncements().single.message,
        l10n.dmVideoOutcomeInChat('Test chat', l10n.dmVideoSendFailed),
      );
      // A different chat still reports the result while this one is visible.
      outbox.controller.add(
        _outcome(VideoDmOutcomeStatus.sent, sent: 1, conversationId: 'other'),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text(l10n.dmVideoOutcomeInChat('Test chat', l10n.dmVideoSent)),
        findsOneWidget,
      );
    });

    testWidgets('preserves queued outcomes in order', (tester) async {
      final provider = StateProvider<VideoDmOutbox>((ref) => outbox);
      await pumpApp(tester, provider);
      outbox.controller.add(_outcome(VideoDmOutcomeStatus.failed));
      outbox.controller.add(_outcome(VideoDmOutcomeStatus.sent, sent: 1));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.dmVideoOutcomeInChat('Test chat', l10n.dmVideoSendFailed),
        ),
        findsOneWidget,
      );
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      );
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.dmVideoOutcomeInChat('Test chat', l10n.dmVideoSent)),
        findsOneWidget,
      );
    });

    testWidgets(
      'names the chat using the cached profile and honors a vanished peer',
      (tester) async {
        final recipient = '1' * 64;
        final profiles = _MockProfileReader();
        when(() => profiles.getCachedProfile(pubkey: recipient)).thenAnswer(
          (_) async => UserProfile(
            pubkey: recipient,
            displayName: 'Camera friend',
            rawData: const {'display_name': 'Camera friend'},
            eventId: '2' * 64,
            createdAt: DateTime(2026),
          ),
        );
        final vanished = StateProvider<bool>((_) => false);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoDmOutboxProvider.overrideWithValue(outbox),
              profileReadRepositoryProvider.overrideWithValue(profiles),
              profileVanishedSnapshotProvider(recipient)
                  .overrideWith((ref) async => ref.watch(vanished)),
              moderationPresentationProvider(recipient)
                  .overrideWithValue(ModerationPresentation.ordinary),
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
        outbox.controller.add(_outcome(VideoDmOutcomeStatus.sent, sent: 1));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          find.text(
            l10n.dmVideoOutcomeInChat('Camera friend', l10n.dmVideoSent),
          ),
          findsOneWidget,
        );
        final context = tester.element(find.byType(Scaffold));
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ProviderScope.containerOf(context).read(vanished.notifier).state = true;
        outbox.controller.add(_outcome(VideoDmOutcomeStatus.failed));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          find.text(
            l10n.dmVideoOutcomeInChat(
              l10n.profileDeletedAccountName,
              l10n.dmVideoSendFailed,
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(recipient), findsNothing);
      },
    );

    testWidgets('logs a result it has no messenger to show on', (
      tester,
    ) async {
      await LogCaptureService().clearAllLogs();
      final provider = StateProvider<VideoDmOutbox>((ref) => outbox);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoDmOutboxProvider.overrideWith((ref) => ref.watch(provider)),
          ],
          child: const VideoDmSendOutcomeListener(child: SizedBox()),
        ),
      );

      outbox.controller.add(
        _outcome(VideoDmOutcomeStatus.failed, sent: 1, total: 3),
      );
      await tester.pump();

      expect(
        [
          for (final entry in LogCaptureService().getRecentLogs())
            entry.message,
        ],
        contains(
          'Video DM send outcome failed (1 of 3 sent) not shown: '
          'no root messenger',
        ),
      );
    });

    testWidgets('announces the result to screen readers', (tester) async {
      final provider = StateProvider<VideoDmOutbox>((ref) => outbox);
      await pumpApp(tester, provider);

      outbox.controller.add(_outcome(VideoDmOutcomeStatus.failed));
      await tester.pump();
      await tester.pump();

      expect(
        tester.takeAnnouncements().single.message,
        equals(l10n.dmVideoOutcomeInChat('Test chat', l10n.dmVideoSendFailed)),
      );
    });

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
      // Two pumps, as for a shown result: the first only delivers the event.
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.dmVideoSendFailed), findsNothing);

      replacement.controller.add(_outcome(VideoDmOutcomeStatus.sent, sent: 1));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(l10n.dmVideoOutcomeInChat('Test chat', l10n.dmVideoSent)),
        findsOneWidget,
      );
    });
  });
}
