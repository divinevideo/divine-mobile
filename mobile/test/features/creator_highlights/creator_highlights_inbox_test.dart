import 'dart:async';
import 'dart:convert';

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/features/creator_highlights/creator_highlights_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/test_provider_overrides.dart';

class _Notifications extends Mock implements NotificationRepository {}

class _Following extends Mock implements FollowRepository {}

class _Badges extends Mock implements BadgeRepository {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _video =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  setUp(() {
    final controller = VisibilityDetectorController.instance;
    final interval = controller.updateInterval;
    controller.updateInterval = Duration.zero;
    addTearDown(() => controller.updateInterval = interval);
  });
  group('navigation', () {
    testWidgets(
      'creator card survives an empty Inbox and fits a narrow viewport',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final notifications = _Notifications();
        final following = _Following();
        final badges = _Badges();
        when(() => notifications.watchSnapshot(filter: any(named: 'filter')))
            .thenAnswer((_) => const Stream<NotificationPage>.empty());
        when(() => notifications.refreshFeed(any()))
            .thenAnswer((_) async => NotificationPage.empty);
        when(notifications.markAllAsRead).thenAnswer((_) async {});
        when(() => following.isFollowing(any())).thenReturn(false);
        when(badges.loadDashboard).thenAnswer(
          (_) async =>
              const BadgeDashboardData(awarded: [], issued: [], created: []),
        );
        final visibility = ValueNotifier(false);
        addTearDown(visibility.dispose);
        final auth = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: _owner,
        );
        final authStates = StreamController<AuthState>.broadcast();
        addTearDown(authStates.close);
        when(() => auth.authStateStream).thenAnswer((_) => authStates.stream);
        var authorRequests = 0;
        final authorRelease = Completer<void>();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.com',
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/videos')) {
              authorRequests++;
              await authorRelease.future;
              return http.Response(
                jsonEncode({
                  'data': [
                    {
                      'id': _video,
                      'pubkey': _owner,
                      'kind': 34236,
                      'created_at': now,
                      'tags': [
                        ['d', 'a-tiny-dance'],
                      ],
                      'video_url': 'https://example.com/video.mp4',
                      'title': 'A tiny dance',
                      'views': 3,
                    },
                  ],
                  'pagination': {'has_more': false},
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'stats': {
                  _video: {'event_id': _video, 'views': 3},
                },
              }),
              200,
            );
          }),
        );
        Object? receivedExtra;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: RepaintBoundary(
                  key: const ValueKey('inbox-capture'),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: visibility,
                    builder: (context, visible, child) =>
                        InboxNotificationsPage(isVisible: visible),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '${RoutePaths.videoDetailBase}/:id',
              builder: (context, state) {
                receivedExtra = state.extra;
                return const Scaffold(body: Text('Video destination'));
              },
            ),
            GoRoute(
              path: RoutePaths.videoRecorder,
              builder: (_, _) =>
                  const Scaffold(body: Text('Camera destination')),
            ),
            GoRoute(
              path: RoutePaths.creatorAnalytics,
              builder: (_, _) =>
                  const Scaffold(body: Text('Analytics destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            mockSharedPreferences: prefs,
            mockAuthService: auth,
            mockFollowRepository: following,
            additionalOverrides: [
              notificationRepositoryProvider.overrideWithValue(notifications),
              badgeRepositoryProvider.overrideWithValue(badges),
              funnelcakeApiClientProvider.overrideWithValue(client),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: ThemeData.dark(),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          authorRequests,
          0,
          reason: 'An initially hidden Inbox must not load highlights.',
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(InboxNotificationsPage)),
        );
        visibility.value = true;
        await tester.pump();
        await tester.pump();
        expect(authorRequests, 1);
        container
            .read(shellObscuredProvider.notifier)
            .setObscured(obscured: true);
        await tester.pump();
        authorRelease.complete();
        await tester.pumpAndSettle();
        expect(
          prefs.getString(
            FunnelcakeCreatorHighlightsRepository.presentationKey(_owner),
          ),
          isNull,
          reason: 'A covered Inbox cannot consume an unseen celebration.',
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        container
            .read(shellObscuredProvider.notifier)
            .setObscured(obscured: false);
        await tester.pumpAndSettle();
        expect(
          prefs.getString(
            FunnelcakeCreatorHighlightsRepository.presentationKey(_owner),
          ),
          isNull,
          reason: 'A backgrounded app cannot consume a celebration.',
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          prefs.getString(
            FunnelcakeCreatorHighlightsRepository.presentationKey(_owner),
          ),
          isNotNull,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(InboxNotificationsPage)),
        );
        expect(find.text(l10n.creatorHighlightLabel), findsOneWidget);
        expect(find.text(l10n.creatorHighlightCreatedToday(1)), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(authorRequests, 2);
        await tester.tap(find.text(l10n.creatorHighlightWatch));
        await tester.pumpAndSettle();
        expect(find.text('Video destination'), findsOneWidget);
        expect(receivedExtra, isA<VideoDetailRouteExtra>());
        expect(
          (receivedExtra! as VideoDetailRouteExtra).initialVideo?.id,
          _video,
        );
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.creatorHighlightCreate));
        await tester.pumpAndSettle();
        expect(find.text('Camera destination'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.creatorHighlightAnalytics));
        await tester.pumpAndSettle();
        expect(find.text('Analytics destination'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.notificationsTabLikes));
        await tester.pumpAndSettle();
        expect(find.text(l10n.creatorHighlightLabel), findsNothing);
        expect(authorRequests, 2);
        await tester.tap(find.text(l10n.notificationsTabAll));
        await tester.pumpAndSettle();
        expect(find.text(l10n.creatorHighlightLabel), findsOneWidget);
        expect(authorRequests, 3);
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, 350),
        );
        await tester.pumpAndSettle();
        expect(
          authorRequests,
          4,
          reason: 'Pull-to-refresh refreshes both content sources.',
        );
        when(() => auth.isAuthenticated).thenReturn(false);
        when(() => auth.currentPublicKeyHex).thenReturn(null);
        authStates.add(AuthState.unauthenticated);
        await tester.pumpAndSettle();
        expect(find.text(l10n.creatorHighlightLabel), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });
}
