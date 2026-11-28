// ABOUTME: Dependency and analytics wiring for permanent or optional discovery.
// ABOUTME: Account changes replace the cubit and erase predecessor UI state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:openvine/providers/find_people_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/find_people/find_people_view.dart';
import 'package:openvine/screens/find_people/widgets/find_people_recommendations.dart';

class FindPeoplePage extends ConsumerWidget {
  const FindPeoplePage({this.source = 'findPeople', this.onAction, super.key});
  static const String path = RoutePaths.findPeople;
  final String source;
  final FindPeopleActionCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callback =
        onAction ?? ref.watch(findPeopleActionRecorderProvider)(source);
    final recordSkip = source == 'onboarding'
        ? ref.watch(findPeopleOnboardingSkipRecorderProvider)
        : null;
    return FindPeopleScope(
      child: FindPeopleView(
        source: source,
        onAction: callback,
        onSkip: () {
          recordSkip?.call();
          context.go(RoutePaths.root);
        },
        onDone: () => context.go(RoutePaths.root),
      ),
    );
  }
}
