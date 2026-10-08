import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/router/deep_link_coordinator.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/deep_link_service.dart';

import '../helpers/test_provider_overrides.dart';

class _Auth extends Mock implements AuthService {}

void main() {
  group('list identity URL roundtrip', () {
    final dTags = <String>[
      'x' * 201,
      '界' * 50,
      'favourite / ? # % +',
      'dot/%2F/✓',
      'friends:part/',
    ];
    for (var index = 0; index < dTags.length; index++) {
      final dTag = dTags[index];
      for (final type in [DeepLinkType.peopleList, DeepLinkType.list]) {
        testWidgets(
          'd-tag fixture $index $type survives shared URL, parser and GoRouter consumer for both authors',
          (tester) async {
            final router = GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
                GoRoute(
                  path: '/people-lists/:listId',
                  builder: (_, state) {
                    return Text(
                      '${state.uri.queryParameters['owner']}\n${state.pathParameters['listId']}',
                    );
                  },
                ),
                GoRoute(
                  path: '/list/:pubkey/:listId',
                  builder: (_, state) {
                    return Text(
                      '${state.pathParameters['pubkey']}\n${state.pathParameters['listId']}',
                    );
                  },
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              testMaterialApp(home: Router.withConfig(config: router)),
            );
            await tester.pumpAndSettle();
            final coordinator = DeepLinkCoordinator(
              router: router,
              authService: _Auth(),
            );
            for (final owner in ['a' * 64, 'b' * 64]) {
              final path = type == DeepLinkType.peopleList
                  ? RoutePaths.peopleListByAuthorFor(
                      pubkey: owner,
                      listId: dTag,
                    )
                  : RoutePaths.curatedListByAuthorFor(
                      pubkey: owner,
                      listId: dTag,
                    );
              final uri = Uri.parse('https://divine.video$path');
              expect(uri.pathSegments, [
                if (type == DeepLinkType.peopleList) 'people-lists' else 'list',
                owner,
                dTag,
              ]);
              final parsed = DeepLinkService.parseDeepLink(uri.toString());
              expect(parsed.type, type);
              expect(parsed.listPubkey, owner);
              expect(parsed.listId, dTag);
              coordinator.handle(AsyncValue.data(parsed));
              await tester.pumpAndSettle();
              expect(find.text('$owner\n$dTag'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  });
}
