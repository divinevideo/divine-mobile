// ABOUTME: DM / message-request routes (conversation, requests, request preview)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';

part 'messaging_routes.g.dart';

List<RouteBase> messagingRoutes() => $appRoutes;

/// DM conversation detail, pushed from the inbox with no bottom nav.
@TypedGoRoute<ConversationRouteData>(
  path: ConversationPage.pathPattern,
  name: ConversationPage.routeName,
)
class ConversationRouteData extends GoRouteData with $ConversationRouteData {
  const ConversationRouteData({required this.id, this.$extra});

  final String id;

  /// The participant hint read by [dmRouteExtra]; absent after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (id.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
    }
    final extra = dmRouteExtra($extra);
    return ConversationPage(
      conversationId: id,
      participantPubkeys: extra.participantPubkeys,
      subject: extra.subject,
    );
  }
}

/// Message requests inbox, pushed from the inbox with no bottom nav.
@TypedGoRoute<MessageRequestsRouteData>(
  path: MessageRequestsPage.path,
  name: MessageRequestsPage.routeName,
)
class MessageRequestsRouteData extends GoRouteData
    with $MessageRequestsRouteData {
  const MessageRequestsRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MessageRequestsPage();
}

/// Message request preview, pushed from the requests inbox.
@TypedGoRoute<RequestPreviewRouteData>(
  path: RequestPreviewPage.pathPattern,
  name: RequestPreviewPage.routeName,
)
class RequestPreviewRouteData extends GoRouteData
    with $RequestPreviewRouteData {
  const RequestPreviewRouteData({required this.id, this.$extra});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  final String id;

  /// The participant hint read by [dmRouteExtra]; absent after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (id.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidRequestId);
    }
    // Pubkeys are optional — the page loads them from the DB when not
    // provided (e.g. deep link); DM-restricted users fail closed (#176).
    final extra = dmRouteExtra($extra);
    return RequestPreviewPage(
      conversationId: id,
      participantPubkeys: extra.participantPubkeys,
      subject: extra.subject,
    );
  }
}

/// The participant hint [dmRouteExtra] reads from a DM route's `extra`.
///
/// Callers pass the counterparty list, or a map with `participantPubkeys` and
/// `subject`, never this class: it is not a shape [dmRouteExtra] reads.
class DmRouteExtra {
  const DmRouteExtra({required this.participantPubkeys, this.subject});

  final List<String> participantPubkeys;
  final String? subject;
}

@visibleForTesting
List<String> stringListRouteExtra(Object? extra) {
  if (extra is! Iterable) return const [];

  final values = <String>[];
  for (final item in extra) {
    if (item is! String) return const [];
    values.add(item);
  }
  return List<String>.unmodifiable(values);
}

DmRouteExtra dmRouteExtra(Object? extra) {
  if (extra is Map) {
    return DmRouteExtra(
      participantPubkeys: stringListRouteExtra(extra['participantPubkeys']),
      subject: extra['subject'] is String ? extra['subject'] as String : null,
    );
  }
  return DmRouteExtra(participantPubkeys: stringListRouteExtra(extra));
}
