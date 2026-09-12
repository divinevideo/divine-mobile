// ABOUTME: Regression tests for app-level startup and lifecycle transitions
// ABOUTME: Verifies auth waiting, badge clearing, and pending autosave handling

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/services/app_badge_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _CountingAppBadgeClearer implements AppBadgeClearer {
  _CountingAppBadgeClearer({this.throwOnClear = false});

  final bool throwOnClear;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    if (throwOnClear) {
      throw Exception('badge clear failed');
    }
  }
}

class _NoopVideoPublishNotifier extends VideoPublishNotifier {
  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> resumePendingPublishes(BuildContext context) async {}
}

class _FlushTrackingVideoEditorNotifier extends VideoEditorNotifier {
  int flushCalls = 0;

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<bool> flushPendingAutosave() async {
    flushCalls++;
    return true;
  }
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('startup', () {
    testWidgets('handles auth stream closing before authentication', (
      tester,
    ) async {
      final authService = _MockAuthService();
      final authStates = StreamController<AuthState>();
      when(() => authService.isAuthenticated).thenReturn(false);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStates.stream);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            appBadgeServiceProvider.overrideWithValue(
              _CountingAppBadgeClearer(),
            ),
            notificationRefreshCoordinatorProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppLifecycleHandler(child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await authStates.close();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('lifecycle transitions', () {
    testWidgets('flushes pending autosave before background lifecycle states', (
      tester,
    ) async {
      final authService = _MockAuthService();
      addTearDown(() {
        BackgroundActivityManager().onAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });

      when(() => authService.isAuthenticated).thenReturn(true);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      final clipLibraryService = _MockClipLibraryService();
      when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
      when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
      final draftStorageService = _MockDraftStorageService();
      when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});

      final editorNotifier = _FlushTrackingVideoEditorNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            videoEditorProvider.overrideWith(() => editorNotifier),
            videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
            clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
            draftStorageServiceProvider.overrideWithValue(draftStorageService),
          ],
          child: const MaterialApp(
            home: AppLifecycleHandler(child: SizedBox.shrink()),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      // Do not simulate detached here: flutter_tester treats it as shell teardown.
      expect(editorNotifier.flushCalls, 3);
      // Drain BackgroundActivityManager's private 30-second suspension timer.
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('treats inactive as non-foreground on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final authService = _MockAuthService();
      addTearDown(() {
        BackgroundActivityManager().onAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });

      when(() => authService.isAuthenticated).thenReturn(true);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      final clipLibraryService = _MockClipLibraryService();
      when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
      when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
      final draftStorageService = _MockDraftStorageService();
      when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
            clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
            draftStorageServiceProvider.overrideWithValue(draftStorageService),
          ],
          child: const MaterialApp(
            home: AppLifecycleHandler(child: SizedBox.shrink()),
          ),
        ),
      );

      final context = tester.element(find.byType(AppLifecycleHandler));
      final container = ProviderScope.containerOf(context);
      expect(container.read(appForegroundProvider), isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(container.read(appForegroundProvider), isFalse);
      await tester.pump(const Duration(seconds: 31));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('app badge', () {
    testWidgets('clears the app badge on launch and resume', (tester) async {
      final authService = _MockAuthService();
      addTearDown(() {
        BackgroundActivityManager().onAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });

      when(() => authService.isAuthenticated).thenReturn(true);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      final clipLibraryService = _MockClipLibraryService();
      when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
      when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
      final draftStorageService = _MockDraftStorageService();
      when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});

      final appBadgeClearer = _CountingAppBadgeClearer();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBadgeServiceProvider.overrideWithValue(appBadgeClearer),
            authServiceProvider.overrideWithValue(authService),
            notificationRefreshCoordinatorProvider.overrideWithValue(null),
            videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
            clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
            draftStorageServiceProvider.overrideWithValue(draftStorageService),
          ],
          child: const MaterialApp(
            home: AppLifecycleHandler(child: SizedBox.shrink()),
          ),
        ),
      );

      await tester.pump();
      expect(appBadgeClearer.clearCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(appBadgeClearer.clearCalls, 2);
    });

    testWidgets('badge clear failure does not break resume handling', (
      tester,
    ) async {
      final authService = _MockAuthService();
      addTearDown(() {
        BackgroundActivityManager().onAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });

      when(() => authService.isAuthenticated).thenReturn(true);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      final clipLibraryService = _MockClipLibraryService();
      when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
      when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
      final draftStorageService = _MockDraftStorageService();
      when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});

      final appBadgeClearer = _CountingAppBadgeClearer(throwOnClear: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBadgeServiceProvider.overrideWithValue(appBadgeClearer),
            authServiceProvider.overrideWithValue(authService),
            notificationRefreshCoordinatorProvider.overrideWithValue(null),
            videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
            clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
            draftStorageServiceProvider.overrideWithValue(draftStorageService),
          ],
          child: const MaterialApp(
            home: AppLifecycleHandler(child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(AppLifecycleHandler));
      final container = ProviderScope.containerOf(context);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(appForegroundProvider), isTrue);
      expect(appBadgeClearer.clearCalls, 2);
      await tester.pump(const Duration(seconds: 31));
    });
  });

  group('relay reconnect on resume', () {
    Future<List<String>> resumeLogs(
      WidgetTester tester, {
      required ForceReconnectOutcome outcome,
      required int connected,
    }) async {
      final authService = _MockAuthService();
      addTearDown(() {
        BackgroundActivityManager().onAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      when(() => authService.isAuthenticated).thenReturn(true);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      final clipLibraryService = _MockClipLibraryService();
      when(clipLibraryService.migrateOldClips).thenAnswer((_) async {});
      when(clipLibraryService.purgeExpiredTrash).thenAnswer((_) async => 0);
      final draftStorageService = _MockDraftStorageService();
      when(draftStorageService.migrateOldDrafts).thenAnswer((_) async {});
      final nostrClient = _MockNostrClient();
      when(nostrClient.forceReconnectAll).thenAnswer((_) async => outcome);
      when(() => nostrClient.connectedRelayCount).thenReturn(connected);
      when(() => nostrClient.configuredRelayCount).thenReturn(2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBadgeServiceProvider.overrideWithValue(
              _CountingAppBadgeClearer(),
            ),
            authServiceProvider.overrideWithValue(authService),
            notificationRefreshCoordinatorProvider.overrideWithValue(null),
            videoPublishProvider.overrideWith(_NoopVideoPublishNotifier.new),
            clipLibraryServiceProvider.overrideWithValue(clipLibraryService),
            draftStorageServiceProvider.overrideWithValue(draftStorageService),
            nostrServiceProvider.overrideWithValue(nostrClient),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppLifecycleHandler(child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
      unawaited(LogCaptureService().clearAllLogs());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(nostrClient.forceReconnectAll).called(1);
      final messages = [
        for (final entry in LogCaptureService().getRecentLogs()) entry.message,
      ];
      await tester.pump(const Duration(seconds: 31));
      return messages;
    }

    testWidgets('logs how many relays connected when the reconnect '
        'finishes', (tester) async {
      final messages = await resumeLogs(
        tester,
        outcome: ForceReconnectOutcome.completed,
        connected: 1,
      );

      expect(
        messages,
        contains(
          '📱 Relay reconnect after app resume finished: 1 of 2 relays '
          'connected',
        ),
      );
      expect(
        messages,
        isNot(contains('📱 Relay connections restored after app resume')),
      );
    });

    testWidgets('says relays are still connecting when the wait ends '
        'first', (tester) async {
      final messages = await resumeLogs(
        tester,
        outcome: ForceReconnectOutcome.stillDialling,
        connected: 0,
      );

      expect(
        messages,
        contains(
          '📱 Relay reconnect after app resume ended with relays still '
          'connecting (0 of 2 connected)',
        ),
      );
      expect(
        messages,
        isNot(contains('📱 Relay connections restored after app resume')),
      );
    });
  });
}
