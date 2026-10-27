// ABOUTME: Verifies the short-link failure view retries and late results do not navigate away.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/short_link/short_link_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/short_link_screen.dart';
import 'package:openvine/services/short_link_resolver.dart';
import 'package:openvine/utils/external_link_launcher.dart';

void main() {
  group('navigation', () {
    testWidgets(
      'resolving a short link preserves the originating page for Back',
      (tester) async {
        final pending = Completer<http.Response>();
        final uri = Uri.parse('https://divine.video/l/Abc12345');
        final client = MockClient((_) => pending.future);
        final cubit = ShortLinkCubit(ShortLinkResolver(client: client));
        final router = GoRouter(
          initialLocation: '/source',
          routes: [
            GoRoute(
              path: '/source',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      unawaited(openExternalLink(context, uri.toString())),
                  child: const Text('open link'),
                ),
              ),
            ),
            GoRoute(
              path: '/l/:code',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: ShortLinkScreen(uri: uri),
              ),
            ),
            GoRoute(
              path: '/video/:id',
              builder: (_, _) => const Scaffold(body: Text('resolved video')),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open link'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          router.canPop(),
          isTrue,
          reason: 'receiver is pushed above source',
        );
        final lookup = cubit.resolve(uri);
        pending.complete(
          http.Response(
            jsonEncode({
              'code': 'Abc12345',
              'short_url': uri.toString(),
              'url': 'https://divine.video/video/shared',
            }),
            200,
          ),
        );
        await lookup;
        await tester.pumpAndSettle();
        expect(find.text('resolved video'), findsOneWidget);
        expect(router.canPop(), isTrue);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('open link'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await cubit.close();
        client.close();
      },
    );

    testWidgets(
      'failed resolution offers retry and retry opens the destination',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        var fail = true;
        final uri = Uri.parse('https://divine.video/l/Abc12345');
        final client = MockClient(
          (_) async => http.Response(
            fail
                ? '{}'
                : jsonEncode({
                    'code': 'Abc12345',
                    'short_url': uri.toString(),
                    'url': 'https://divine.video/video/retried',
                  }),
            fail ? 503 : 200,
          ),
        );
        final cubit = ShortLinkCubit(ShortLinkResolver(client: client));
        final router = GoRouter(
          initialLocation: '/l/Abc12345',
          routes: [
            GoRoute(
              path: '/l/:code',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: ShortLinkScreen(uri: uri),
              ),
            ),
            GoRoute(
              path: '/video/:id',
              builder: (_, _) => const Scaffold(body: Text('resolved video')),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        unawaited(cubit.resolve(uri));
        await tester.pumpAndSettle();
        expect(find.text(l10n.commonRetry), findsOneWidget);
        fail = false;
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pumpAndSettle();
        expect(find.text('resolved video'), findsOneWidget);
        expect(
          router.canPop(),
          isFalse,
          reason: 'cold start must not retain the alias page',
        );
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await cubit.close();
        client.close();
      },
    );

    testWidgets('lookup finishing after navigation cannot pull the user back', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      final uri = Uri.parse('https://divine.video/l/Abc12345');
      final client = MockClient((_) => pending.future);
      final cubit = ShortLinkCubit(ShortLinkResolver(client: client));
      final router = GoRouter(
        initialLocation: '/l/Abc12345',
        routes: [
          GoRoute(
            path: '/l/:code',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: ShortLinkScreen(uri: uri),
            ),
          ),
          GoRoute(
            path: '/other',
            builder: (_, _) => const Scaffold(body: Text('another page')),
          ),
          GoRoute(
            path: '/video/:id',
            builder: (_, _) => const Scaffold(body: Text('resolved video')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      final lookup = cubit.resolve(uri);
      router.go('/other');
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(
          jsonEncode({
            'code': 'Abc12345',
            'short_url': uri.toString(),
            'url': 'https://divine.video/video/stale',
          }),
          200,
        ),
      );
      await lookup;
      await tester.pumpAndSettle();
      expect(find.text('another page'), findsOneWidget);
      expect(find.text('resolved video'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await cubit.close();
      client.close();
    });

    testWidgets('lookup finishing under a pushed page does not replace it', (
      tester,
    ) async {
      final pending = Completer<http.Response>();
      final uri = Uri.parse('https://divine.video/l/Abc12345');
      final client = MockClient((_) => pending.future);
      final cubit = ShortLinkCubit(ShortLinkResolver(client: client));
      final router = GoRouter(
        initialLocation: '/l/Abc12345',
        routes: [
          GoRoute(
            path: '/l/:code',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: ShortLinkScreen(uri: uri),
            ),
          ),
          GoRoute(
            path: '/other',
            builder: (_, _) => const Scaffold(body: Text('another page')),
          ),
          GoRoute(
            path: '/video/:id',
            builder: (_, _) => const Scaffold(body: Text('resolved video')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      final lookup = cubit.resolve(uri);
      // Unlike `go`, a push keeps the short-link screen mounted underneath,
      // so its listener still hears the late result.
      unawaited(router.push<void>('/other'));
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(
          jsonEncode({
            'code': 'Abc12345',
            'short_url': uri.toString(),
            'url': 'https://divine.video/video/stale',
          }),
          200,
        ),
      );
      await lookup;
      await tester.pumpAndSettle();
      expect(cubit.state, isA<ShortLinkReady>());
      expect(find.text('another page'), findsOneWidget);
      expect(find.text('resolved video'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await cubit.close();
      client.close();
    });
  });
}
