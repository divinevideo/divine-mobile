import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/live/widgets/live_explore_entry_card.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockLiveRepository extends Mock implements LiveRepository {}

class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true;
}

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => const [];
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
  });

  late _MockVideoEventService videoEventService;
  late _MockLiveRepository liveRepository;

  setUp(() {
    videoEventService = _MockVideoEventService();
    liveRepository = _MockLiveRepository();

    when(
      () => videoEventService.addVideoUpdateListener(any()),
    ).thenReturn(() {});
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(() => videoEventService.discoveryVideos).thenReturn([]);
    when(() => videoEventService.popularNowVideos).thenReturn([]);
    when(() => videoEventService.isSubscribed(any())).thenReturn(false);
    // The fixture needs a deliberately invalid tab to exercise normalization.
    // ignore: invalid_use_of_protected_member
    when(() => videoEventService.hasListeners).thenReturn(false);

    when(() => liveRepository.fetchPublicRooms()).thenAnswer(
      (_) async => const <LiveRoom>[],
    );
    when(() => liveRepository.fetchSessions()).thenAnswer(
      (_) async => const <LiveSession>[],
    );
  });

  testWidgets(
    'ExploreScreen shows Live as a tab and removes the promo card',
    (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            liveRepositoryProvider.overrideWithValue(liveRepository),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
            classicVinesAvailableProvider.overrideWith(
              (ref) async => false,
            ),
            forYouAvailableProvider.overrideWithValue(false),
            allListsProvider.overrideWith(
              (ref) async => (
                userLists: <UserList>[],
                curatedLists: <CuratedList>[],
              ),
            ),
            curatedListsStateProvider.overrideWith(
              _FakeCuratedListsState.new,
            ),
            isFeatureEnabledProvider(
              FeatureFlag.integratedApps,
            ).overrideWithValue(false),
            isFeatureEnabledProvider(
              FeatureFlag.livestreamingBeta,
            ).overrideWithValue(true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.widgetWithText(Tab, 'Live'), findsOneWidget);
      expect(find.byKey(LiveExploreEntryCard.entryKey), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'Live'));
      await tester.pumpAndSettle();

      expect(find.text('Live now'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    },
  );
}
