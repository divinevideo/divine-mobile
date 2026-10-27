import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_link.dart';
import 'package:openvine/features/challenges/challenge_page.dart';
import 'package:openvine/features/challenges/challenge_test_build.dart';
import 'package:openvine/features/challenges/challenges_tab.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';

part 'challenge_routes.g.dart';

List<RouteBase> challengeRoutes() => $appRoutes;

@TypedGoRoute<ChallengesRouteData>(path: RoutePaths.challenges)
class ChallengesRouteData extends GoRouteData with $ChallengesRouteData {
  const ChallengesRouteData();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      challengesTestEnabled
      ? Scaffold(
          appBar: DiVineAppBar(
            title: context.l10n.challengeTitle,
            showBackButton: true,
          ),
          body: const ChallengesTab(),
        )
      : RouteErrorScreen(message: context.l10n.routeUnknownPath);
}

@TypedGoRoute<ChallengeRouteData>(path: RoutePaths.challenge)
class ChallengeRouteData extends GoRouteData with $ChallengeRouteData {
  const ChallengeRouteData({required this.naddr});
  final String naddr;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    final link = ChallengeLink.parse(naddr);
    if (!challengesTestEnabled || link == null) {
      return RouteErrorScreen(message: context.l10n.routeUnknownPath);
    }
    return ChallengePage(link: link);
  }
}
