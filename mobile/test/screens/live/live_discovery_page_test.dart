import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_room_detail_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/screens/live/widgets/live_explore_entry_card.dart';
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
              home: Scaffold(
                body: Consumer(
                  builder: _buildExploreLiveEntry,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(LiveExploreEntryCard.entryKey), findsOneWidget);
      },
    );

    testWidgets('tapping a room card opens room detail', (tester) async {
      final activeRoom = _room(
        id: 'room-123',
        hostPubkey: 'host-pubkey',
        title: 'Signal from the stage',
      );
      final activeSession = _session(
        id: 'session-123',
        roomId: activeRoom.id,
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();

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
        status: LiveSessionStatus.live,
      );
      final upcomingSession = _session(
        id: 'session-456',
        roomId: upcomingRoom.id,
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
          child: const MaterialApp(home: LiveDiscoveryPage()),
        ),
      );
      await tester.pump();
      await tester.pump();

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
  required LiveSessionStatus status,
}) {
  return LiveSession(
    id: id,
    roomId: roomId,
    status: status,
    startedAt: DateTime.utc(2026, 4, 6, 8),
    endedAt: null,
    speakerPubkeys: const <String>['host-pubkey'],
    audienceCount: 42,
  );
}
