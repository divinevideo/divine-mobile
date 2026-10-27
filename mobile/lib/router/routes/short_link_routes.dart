// ABOUTME: Typed route and composition root for incoming public short links.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/blocs/short_link/short_link_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/short_link_screen.dart';
import 'package:openvine/services/short_link_resolver.dart';
import 'package:openvine/utils/short_link_url.dart';

part 'short_link_routes.g.dart';

List<RouteBase> shortLinkRoutes() => $appRoutes;

@TypedGoRoute<ShortLinkRouteData>(
  path: RoutePaths.shortLink,
  name: ShortLinkScreen.routeName,
)
class ShortLinkRouteData extends GoRouteData with $ShortLinkRouteData {
  const ShortLinkRouteData({required this.code});
  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final incoming = state.uri.hasScheme
        ? state.uri
        : Uri.parse('https://divine.video${state.uri}');
    if (shortLinkCodeFor(incoming) != code) {
      return RouteErrorScreen(message: context.l10n.routeUnknownPath);
    }
    final uri = Uri.https('divine.video', RoutePaths.shortLinkForCode(code));
    return RepositoryProvider<http.Client>(
      key: ValueKey(code),
      create: (_) => http.Client(),
      dispose: (client) => client.close(),
      child: BlocProvider(
        create: (context) {
          final cubit = ShortLinkCubit(
            ShortLinkResolver(client: context.read<http.Client>()),
          );
          unawaited(cubit.resolve(uri));
          return cubit;
        },
        child: ShortLinkScreen(uri: uri),
      ),
    );
  }
}
