// ABOUTME: Pins the same short-link route for OS, GoRouter and in-app URL delivery.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/short_link_routes.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/services/deep_link_service.dart';

class _MockRouterState extends Mock implements GoRouterState {}

void main() {
  group('navigation', () {
    testWidgets('the typed route rejects foreign and encoded original URLs', (
      tester,
    ) async {
      for (final raw in [
        'https://evil.example/l/Abc12345',
        '/l/Abc%2f2345',
      ]) {
        final state = _MockRouterState();
        when(() => state.uri).thenReturn(Uri.parse(raw));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) =>
                  const ShortLinkRouteData(code: 'Abc12345')
                      .build(context, state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RouteErrorScreen), findsOneWidget);
      }
    });
    test('public short links resolve to the same guarded internal route', () {
      for (final host in ['divine.video', 'www.divine.video']) {
        final uri = Uri.parse('https://$host/l/Abc12345?ignored=1');
        final parsed = DeepLinkService.parseDeepLink(uri.toString());
        expect(parsed.type, DeepLinkType.shortLink);
        expect(parsed.shortCode, 'Abc12345');
        expect(deepLinkRouterPath(parsed), '/l/Abc12345');
        expect(universalLinkToRouterPath(uri), '/l/Abc12345');
        expect(divineUrlToPushRoute(uri), '/l/Abc12345');
      }
    });
    test(
      'foreign hosts and malformed aliases are not short-link navigation',
      () {
        for (final raw in [
          'https://evil.example/l/Abc12345',
          'https://login.divine.video/l/Abc12345',
          'https://divine.video/l/short',
        ]) {
          expect(DeepLinkService.parseDeepLink(raw).type, DeepLinkType.unknown);
        }
      },
    );
  });
}
