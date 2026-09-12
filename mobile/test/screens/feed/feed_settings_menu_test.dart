// ABOUTME: Widget coverage for owner-delete behavior in the feed settings menu.
// ABOUTME: Verifies relay feedback and pending-delete action gating.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  const ownPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final video = VideoEvent(
    id: 'owned-video',
    pubkey: ownPubkey,
    createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
    content: 'Owned video',
    timestamp: DateTime(2026),
    title: 'Owned video',
    videoUrl: 'https://example.com/owned.mp4',
  );

  group('owner delete', () {
    testWidgets('shows the relay failure result after delete', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final authService = createMockAuthService();
      final deletionService = _MockContentDeletionService();
      final enforcementRepository = _MockEnforcementRepository();
      final videoEventService = _MockVideoEventService();
      final volumeCubit = _MockVideoVolumeCubit();
      when(() => authService.currentPublicKeyHex).thenReturn(ownPubkey);
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer(
        (_) async => DeleteResult.failure(
          'relay rejected',
          DeleteFailureKind.relayRejected,
        ),
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<VideoVolumeCubit>.value(
            value: volumeCubit,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: FeedSettingsMenu(video: video),
              ),
            ),
          ),
          mockAuthService: authService,
          additionalOverrides: [
            contentDeletionServiceProvider.overrideWith(
              (ref) async => deletionService,
            ),
            creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
              enforcementRepository,
            ),
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        ),
      );

      await tester.tap(find.bySemanticsLabel(l10n.videoSettingsMenuOpen));
      await tester.pump();
      await tester.tap(find.text(l10n.shareMenuDeleteVideo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuDelete));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.shareMenuDeleteFailedRelayRejected),
        findsOneWidget,
      );
    });

    testWidgets('keeps Edit disabled until cleanup finishes', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final authService = createMockAuthService();
      final deletionService = _MockContentDeletionService();
      final enforcementRepository = _MockEnforcementRepository();
      final videoEventService = _MockVideoEventService();
      final volumeCubit = _MockVideoVolumeCubit();
      final relayCompleter = Completer<DeleteResult>();
      final cleanupCompleter = Completer<CreatorDeleteEnforcementResult>();
      when(() => authService.currentPublicKeyHex).thenReturn(ownPubkey);
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer((_) => relayCompleter.future);
      when(
        () => enforcementRepository.enforce('delete-event-id'),
      ).thenAnswer((_) => cleanupCompleter.future);

      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<VideoVolumeCubit>.value(
            value: volumeCubit,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: FeedSettingsMenu(video: video),
              ),
            ),
          ),
          mockAuthService: authService,
          additionalOverrides: [
            contentDeletionServiceProvider.overrideWith(
              (ref) async => deletionService,
            ),
            creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
              enforcementRepository,
            ),
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        ),
      );

      await tester.tap(find.bySemanticsLabel(l10n.videoSettingsMenuOpen));
      await tester.pump();
      await tester.tap(find.text(l10n.shareMenuDeleteVideo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuDelete));
      await tester.pump();

      final editGesture = find.ancestor(
        of: find.text(l10n.shareMenuEditVideo),
        matching: find.byType(GestureDetector),
      );
      expect(tester.widget<GestureDetector>(editGesture).onTap, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      relayCompleter.complete(
        DeleteResult.createSuccess(
          'delete-event-id',
          acceptance: DeleteAcceptance.everyRelay,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.videoSettingsMenuOpen));
      await tester.pump();
      final cleanupEditGesture = find.ancestor(
        of: find.text(l10n.shareMenuEditVideo),
        matching: find.byType(GestureDetector),
      );
      expect(tester.widget<GestureDetector>(cleanupEditGesture).onTap, isNull);

      cleanupCompleter.complete(
        const CreatorDeleteEnforcementResult.confirmed(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<GestureDetector>(cleanupEditGesture).onTap,
        isNotNull,
      );
    });
  });
}
