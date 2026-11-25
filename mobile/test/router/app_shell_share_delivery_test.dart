// ABOUTME: Verify owner-scoped snackbar navigation above the root navigator.
import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/share_delivery_host.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_sharing_service.dart';

class _Auth extends Mock implements AuthService {}

class _Repository extends Mock implements DmRepository {}

void main() {
  testWidgets(
    'View chat samples current restrictions and owner changes clear feedback',
    (tester) async {
      final auth = _Auth();
      final repository = _Repository();
      final stream = StreamController<DmDeliveryState>();
      addTearDown(stream.close);
      var owner = 'original';
      var restricted = true;
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
      when(
        () =>
            repository.watchDeliveryState(ownerPubkey: owner, rumorId: 'rumor'),
      ).thenAnswer((_) => stream.stream);
      final providers = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          dmRepositoryProvider.overrideWithValue(repository),
          isDmRestrictedProvider.overrideWith((ref) => restricted),
        ],
      );
      addTearDown(providers.dispose);
      final router = GoRouter(
        navigatorKey: NavigatorKeys.root,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.read<ShareDeliveryCubit>().track(
                  ownerPubkey: owner,
                  recipients: [
                    (
                      name: 'Friend',
                      pubkey: 'peer',
                      outcome: const ShareResult.queued('rumor', 'chat'),
                    ),
                  ],
                ),
                child: const Text('queue'),
              ),
            ),
          ),
          GoRoute(
            path: '/inbox/conversation/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Opened ${state.pathParameters["id"]}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: providers,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => ShareDeliveryHost(child: child!),
          ),
        ),
      );
      await tester.tap(find.text('queue'));
      await tester.pumpAndSettle();
      expect(find.text('Sending…'), findsOneWidget);
      final chat = find.text('View chat');
      await tester.tap(chat);
      await tester.pumpAndSettle();
      expect(find.text('queue'), findsOneWidget);
      restricted = false;
      providers.invalidate(isDmRestrictedProvider);
      stream.add(DmDeliveryState.accepted);
      await tester.pumpAndSettle();
      expect(find.text('Sent'), findsOneWidget);
      await tester.tap(chat);
      await tester.pumpAndSettle();
      expect(find.text('Opened chat'), findsOneWidget);
      owner = 'other';
      providers
          .read(nostrSessionProvider.notifier)
          .update(NostrSessionReadiness.identityKnown(pubkey: owner));
      await tester.pumpAndSettle();
      expect(find.text('Sent'), findsNothing);
    },
  );
}
