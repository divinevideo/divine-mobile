// ABOUTME: Tests the DM routes registered by messagingRoutes.
// ABOUTME: Pins their locations, navigators and how each reads its extra hint.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required String location,
    required this.pathParameters,
    this.extra,
  }) : uri = Uri.parse(location),
       matchedLocation = location,
       fullPath = location,
       pageKey = ValueKey<String>(location);

  @override
  final Uri uri;

  @override
  final String matchedLocation;

  @override
  final String? fullPath;

  @override
  final ValueKey<String> pageKey;

  @override
  final Map<String, String> pathParameters;

  @override
  final Object? extra;
}

const _conversationId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _peer =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('messagingRoutes', () {
    late BuildContext context;

    Future<void> captureContext(WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    GoRoute routeNamed(String name) => messagingRoutes()
        .whereType<GoRoute>()
        .singleWhere((route) => route.name == name);

    Widget build(String name, String location, {Object? extra}) =>
        routeNamed(name).builder!(
          context,
          _FakeGoRouterState(
            location: location,
            pathParameters: const {'id': _conversationId},
            extra: extra,
          ),
        );

    group('locations', () {
      test('a conversation is at the location redirects compare against', () {
        // The minor-account review redirect allows exactly this location.
        expect(
          const ConversationRouteData(id: _conversationId).location,
          equals(RoutePaths.conversationForId(_conversationId)),
        );
      });

      test('a request preview sits under the message requests inbox', () {
        expect(
          const RequestPreviewRouteData(id: _conversationId).location,
          equals('${RoutePaths.messageRequests}/$_conversationId'),
        );
        expect(
          const MessageRequestsRouteData().location,
          equals(RoutePaths.messageRequests),
        );
      });
    });

    group('navigators', () {
      test('message requests and their previews cover the shell', () {
        expect(
          routeNamed(MessageRequestsPage.routeName).parentNavigatorKey,
          same(NavigatorKeys.root),
        );
        expect(
          routeNamed(RequestPreviewPage.routeName).parentNavigatorKey,
          same(NavigatorKeys.root),
        );
      });
    });

    group('extra', () {
      testWidgets('a conversation reads a counterparty list', (tester) async {
        await captureContext(tester);

        final screen = build(
          ConversationPage.routeName,
          ConversationPage.pathForId(_conversationId),
          extra: const [_peer],
        );

        expect(
          screen,
          isA<ConversationPage>()
              .having(
                (s) => s.conversationId,
                'conversationId',
                _conversationId,
              )
              .having((s) => s.participantPubkeys, 'participantPubkeys', [
                _peer,
              ])
              .having((s) => s.subject, 'subject', isNull),
        );
      });

      testWidgets('a conversation reads the subject a group row carries', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          ConversationPage.routeName,
          ConversationPage.pathForId(_conversationId),
          extra: const {
            'participantPubkeys': [_peer],
            'subject': 'Weekend',
          },
        );

        expect(
          screen,
          isA<ConversationPage>()
              .having((s) => s.participantPubkeys, 'participantPubkeys', [
                _peer,
              ])
              .having((s) => s.subject, 'subject', 'Weekend'),
        );
      });

      testWidgets('a request preview reads the same hint', (tester) async {
        await captureContext(tester);

        final screen = build(
          RequestPreviewPage.routeName,
          '${RoutePaths.messageRequests}/$_conversationId',
          extra: const {
            'participantPubkeys': [_peer],
            'subject': 'Weekend',
          },
        );

        expect(
          screen,
          isA<RequestPreviewPage>()
              .having(
                (s) => s.conversationId,
                'conversationId',
                _conversationId,
              )
              .having((s) => s.participantPubkeys, 'participantPubkeys', [
                _peer,
              ])
              .having((s) => s.subject, 'subject', 'Weekend'),
        );
      });
    });
  });
}
