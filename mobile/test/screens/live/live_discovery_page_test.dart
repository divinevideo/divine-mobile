import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_room_detail_page.dart';
import 'package:openvine/screens/live/live_room_detail_view.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/screens/live/widgets/live_explore_entry_card.dart';
import 'package:openvine/screens/live/widgets/live_room_card.dart';
import 'package:openvine/services/live_nostr_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _TestBuildConfiguration extends BuildConfiguration {
  const _TestBuildConfiguration({
    required this.liveEnabled,
  });

  final bool liveEnabled;

  @override
  bool getDefault(FeatureFlag flag) {
    if (flag == FeatureFlag.livestreamingBeta) {
      return liveEnabled;
    }
    return super.getDefault(flag);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveDiscoveryPage', () {
    late _MockLiveRepository mockLiveRepository;

    setUp(() {
      mockLiveRepository = _MockLiveRepository();
    });

    testWidgets(
      'Explore shows a Live entry when livestreamingBeta is enabled',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(
              mockSharedPreferences: sharedPreferences,
            ),
            buildConfigurationProvider.overrideWith(
              (ref) => const _TestBuildConfiguration(liveEnabled: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,

              home: Scaffold(
                body: Consumer(
                  builder: _buildExploreLiveEntry,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(LiveExploreEntryCard.entryKey), findsOneWidget);
      },
    );

    testWidgets('a foreign host session cannot advertise an unrelated room', (
      tester,
    ) async {
      const host =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const otherHost =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final publicRoom = _room(
        id: 'shared-room',
        hostPubkey: host,
        title: 'Public room',
      );
      final foreignSession = const LiveNostrCodec().parseSession(
        Event(
          otherHost,
          30313,
          [
            ['d', 'foreign-session'],
            ['a', '30312:$otherHost:${publicRoom.id}'],
          ],
          '',
          createdAt: 1700000000,
        ),
      );
      when(mockLiveRepository.fetchPublicRooms)
          .thenAnswer((_) async => [publicRoom]);
      when(mockLiveRepository.fetchSessions)
          .thenAnswer((_) async => [foreignSession]);
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
          ],
          home: const LiveDiscoveryPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomCard), findsNothing);
      expect(find.text(publicRoom.title), findsNothing);
      expect(find.text('Featured hosts'), findsNothing);
    });

    for (final featured in [false, true]) {
      testWidgets(
        '${featured ? 'featured host' : 'room card'} keeps a shared room id associated with its host through joining',
        (tester) async {
          const host =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          const otherHost =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          final firstRoom = _room(
            id: 'shared:room',
            hostPubkey: host,
            title: 'First host',
          );
          final secondRoom = _room(
            id: firstRoom.id,
            hostPubkey: otherHost,
            title: 'Second host',
          );
          final firstSession = _session(
            id: 'first:session',
            roomId: firstRoom.id,
            hostPubkey: host,
            status: LiveSessionStatus.live,
          );
          final secondSession = _session(
            id: 'second:session',
            roomId: secondRoom.id,
            hostPubkey: otherHost,
            status: LiveSessionStatus.live,
          );
          when(mockLiveRepository.fetchPublicRooms)
              .thenAnswer((_) async => [firstRoom, secondRoom]);
          when(mockLiveRepository.fetchSessions)
              .thenAnswer((_) async => [firstSession, secondSession]);
          LiveRoomDetailRouteData? routedData;
          Map<String, String>? joinedParameters;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const LiveDiscoveryPage(),
              ),
              GoRoute(
                path: LiveRoomDetailPage.pathPattern,
                builder: (context, state) {
                  routedData = state.extra! as LiveRoomDetailRouteData;
                  return LiveRoomDetailPage(
                    roomId: state.pathParameters['roomId']!,
                    initialRoom: routedData!.room,
                    initialSession: routedData!.session,
                  );
                },
              ),
              GoRoute(
                path: '/live/room/:roomId/session/:sessionId',
                builder: (context, state) {
                  joinedParameters = state.pathParameters;
                  return const Scaffold(body: Text('Joined room'));
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            testProviderScope(
              additionalOverrides: [
                liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              ],
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (featured) {
            await tester.tap(find.text(firstRoom.title).first);
          } else {
            final card = find.byWidgetPredicate(
              (widget) =>
                  widget is LiveRoomCard && widget.room.hostPubkey == host,
            );
            await tester.scrollUntilVisible(
              card,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(tester.widget<LiveRoomCard>(card).session, firstSession);
            await tester.tap(card);
          }
          await tester.pumpAndSettle();
          expect(routedData!.room, firstRoom);
          expect(routedData!.session, firstSession);
          expect(
            tester
                .widget<LiveRoomDetailView>(find.byType(LiveRoomDetailView))
                .session,
            firstSession,
          );
          await tester.scrollUntilVisible(
            find.text('Join live'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Join live'));
          await tester.pumpAndSettle();
          expect(joinedParameters, {
            'roomId': firstRoom.id,
            'sessionId': firstSession.id,
          });
        },
      );
    }

    testWidgets('tapping a room card opens room detail', (tester) async {
      final activeRoom = _room(
        id: 'room-123',
        hostPubkey: 'host-pubkey',
        title: 'Signal from the stage',
      );
      final activeSession = _session(
        id: 'session-123',
        roomId: activeRoom.id,
        hostPubkey: activeRoom.hostPubkey,
        status: LiveSessionStatus.live,
      );

      when(() => mockLiveRepository.fetchPublicRooms()).thenAnswer(
        (_) async => <LiveRoom>[activeRoom],
      );
      when(() => mockLiveRepository.fetchSessions()).thenAnswer(
        (_) async => <LiveSession>[activeSession],
      );

      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const LiveDiscoveryPage(),
          ),
          GoRoute(
            path: LiveRoomDetailPage.pathPattern,
            builder: (context, state) {
              final data = state.extra as LiveRoomDetailRouteData?;
              return LiveRoomDetailPage(
                roomId: state.pathParameters['roomId']!,
                initialRoom: data?.room,
                initialSession: data?.session,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('live-room-card-room-123')), findsOneWidget);

      await tester.tap(find.byKey(const Key('live-room-card-room-123')));
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomDetailPage), findsOneWidget);
      expect(find.text('Join live'), findsOneWidget);
    });

    testWidgets('shows featured hosts above the room sections', (
      tester,
    ) async {
      final activeRoom = _room(
        id: 'room-123',
        hostPubkey: 'host-pubkey',
        title: 'Signal from the stage',
      );
      final upcomingRoom = _room(
        id: 'room-456',
        hostPubkey: 'other-host-pubkey',
        title: 'After hours',
      );
      final activeSession = _session(
        id: 'session-123',
        roomId: activeRoom.id,
        hostPubkey: activeRoom.hostPubkey,
        status: LiveSessionStatus.live,
      );
      final upcomingSession = _session(
        id: 'session-456',
        roomId: upcomingRoom.id,
        hostPubkey: upcomingRoom.hostPubkey,
        status: LiveSessionStatus.planned,
      );

      when(() => mockLiveRepository.fetchPublicRooms()).thenAnswer(
        (_) async => <LiveRoom>[activeRoom, upcomingRoom],
      );
      when(() => mockLiveRepository.fetchSessions()).thenAnswer(
        (_) async => <LiveSession>[activeSession, upcomingSession],
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LiveDiscoveryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Featured hosts'), findsOneWidget);
      expect(find.text('Signal from the stage'), findsWidgets);
      expect(find.text('After hours'), findsWidgets);
      expect(
        find.text('A quick scan of the hosts who are live or lined up next.'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildExploreLiveEntry(
  BuildContext context,
  WidgetRef ref,
  Widget? child,
) {
  final isLiveEnabled = ref.watch(
    isFeatureEnabledProvider(FeatureFlag.livestreamingBeta),
  );

  if (!isLiveEnabled) {
    return const SizedBox.shrink();
  }

  return LiveExploreEntryCard(onTap: () {});
}

LiveRoom _room({
  required String id,
  required String hostPubkey,
  required String title,
}) {
  return LiveRoom(
    id: id,
    hostPubkey: hostPubkey,
    title: title,
    summary: 'Public room for testing live discovery flows.',
    imageUrl: null,
    relays: const <String>[],
    visibility: LiveRoomVisibility.public,
  );
}

LiveSession _session({
  required String id,
  required String roomId,
  required String hostPubkey,
  required LiveSessionStatus status,
}) {
  return LiveSession(
    id: id,
    roomId: roomId,
    hostPubkey: hostPubkey,
    status: status,
    startedAt: DateTime.utc(2026, 4, 6, 8),
    endedAt: null,
    speakerPubkeys: <String>[hostPubkey],
    audienceCount: 42,
  );
}
