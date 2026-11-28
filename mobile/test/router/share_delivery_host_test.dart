// ABOUTME: Verify the share delivery banner's copy, timing and navigation.
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/share_delivery/share_delivery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/share_delivery_host.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_sharing_service.dart';

import '../helpers/test_pubkeys.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _TestEnvironment extends CurrentEnvironmentNotifier {
  @override
  EnvironmentConfig build() => EnvironmentConfig.production;

  void switchTo(EnvironmentConfig config) => state = config;
}

const _home = 'home';

ShareDeliveryRecipient _queued(String name, {required int seed}) => (
  name: name,
  pubkey: testPubkeyFromSeed(seed),
  outcome: ShareResult.queued('rumor-$name', 'chat-$name'),
);

ShareDeliveryRecipient _refused(String name, {required int seed}) => (
  name: name,
  pubkey: testPubkeyFromSeed(seed),
  outcome: const ShareResult.failure(ShareRefusal.blocked),
);

/// Pumps a [ShareDeliveryHost] whose delivery streams the test drives.
class _Harness {
  _Harness() {
    when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
    when(
      () => repository.watchDeliveryState(
        ownerPubkey: any(named: 'ownerPubkey'),
        rumorId: any(named: 'rumorId'),
      ),
    ).thenAnswer(
      (invocation) => deliveries
          .putIfAbsent(
            invocation.namedArguments[#rumorId] as String,
            StreamController<DmDeliveryState>.broadcast,
          )
          .stream,
    );
  }

  final auth = _MockAuthService();
  final repository = _MockDmRepository();
  final deliveries = <String, StreamController<DmDeliveryState>>{};
  String owner = testPubkeyFromSeed(1);
  bool restricted = false;
  late final ProviderContainer providers;

  Future<ShareDeliveryCubit> pump(WidgetTester tester) async {
    providers = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        dmRepositoryProvider.overrideWithValue(repository),
        isDmRestrictedProvider.overrideWith((ref) => restricted),
        currentEnvironmentProvider.overrideWith(_TestEnvironment.new),
      ],
    );
    addTearDown(providers.dispose);
    addTearDown(
      () => Future.wait(deliveries.values.map((stream) => stream.close())),
    );
    final router = GoRouter(
      navigatorKey: NavigatorKeys.root,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text(_home)),
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
    return tester.element(find.text(_home)).read<ShareDeliveryCubit>();
  }

  Future<void> share(
    WidgetTester tester,
    ShareDeliveryCubit cubit,
    List<ShareDeliveryRecipient> recipients,
  ) async {
    cubit.track(ownerPubkey: owner, recipients: recipients);
    await tester.pumpAndSettle();
  }

  Future<void> deliver(
    WidgetTester tester,
    String name,
    DmDeliveryState state,
  ) async {
    deliveries['rumor-$name']!.add(state);
    // The first pump runs the stream microtasks that schedule a frame; the
    // second draws it without advancing the clock.
    await tester.pump();
    await tester.pump();
  }
}

bool _bannerIsError(WidgetTester tester) => tester
    .widget<DivineSnackbarContainer>(find.byType(DivineSnackbarContainer))
    .error;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final friend = _queued('Friend', seed: 2);

  group(ShareDeliveryHost, () {
    group('renders', () {
      testWidgets('a queued share as sending, without the error style', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);

        expect(find.text(l10n.dmPendingVideoSending), findsOneWidget);
        expect(_bannerIsError(tester), isFalse);
      });

      testWidgets('an accepted share as sent, without the error style', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await harness.deliver(tester, 'Friend', DmDeliveryState.accepted);

        expect(find.text(l10n.shareSent), findsOneWidget);
        expect(_bannerIsError(tester), isFalse);
      });

      testWidgets('a failed delivery as not sent yet, in the error style', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await harness.deliver(tester, 'Friend', DmDeliveryState.failed);

        expect(find.text(l10n.shareDeliveryFailed), findsOneWidget);
        expect(_bannerIsError(tester), isTrue);
      });

      testWidgets('an overdue queued share as queued', (tester) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await tester.pump(ShareDeliveryCubit.overdueAfter);

        expect(find.text(l10n.crosspostStatusQueued), findsOneWidget);
        expect(find.text(l10n.dmPendingVideoSending), findsNothing);
      });

      testWidgets('an overdue held share as waiting for the recipient', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await harness.deliver(tester, 'Friend', DmDeliveryState.held);
        expect(find.text(l10n.dmPendingVideoSending), findsOneWidget);

        await tester.pump(ShareDeliveryCubit.overdueAfter);

        expect(find.text(l10n.shareDeliveryHeld('Friend')), findsOneWidget);
      });

      testWidgets('a cancelled delivery as not sent to the recipient', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await harness.deliver(tester, 'Friend', DmDeliveryState.cancelled);

        expect(find.text(l10n.shareCouldNotSendTo('Friend')), findsOneWidget);
      });

      testWidgets('a refused recipient beside a queued one', (tester) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [
          friend,
          _refused('Blocked', seed: 3),
        ]);

        expect(
          find.text(
            '${l10n.shareDeliveryForRecipient('Friend', l10n.dmPendingVideoSending)}'
            '\n${l10n.shareCouldNotSendTo('Blocked')}',
          ),
          findsOneWidget,
        );
        expect(_bannerIsError(tester), isTrue);
      });
    });

    group('dismissal', () {
      testWidgets('stays while queued and leaves dismissAfter after sending', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await tester.pump(
          ShareDeliveryCubit.overdueAfter - const Duration(seconds: 1),
        );
        expect(find.text(l10n.dmPendingVideoSending), findsOneWidget);

        await harness.deliver(tester, 'Friend', DmDeliveryState.accepted);
        await tester.pump(
          ShareDeliveryHost.dismissAfter - const Duration(milliseconds: 100),
        );
        expect(find.text(l10n.shareSent), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text(l10n.shareSent), findsNothing);
      });

      testWidgets('a dismissed failure does not return at the overdue limit', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        await harness.deliver(tester, 'Friend', DmDeliveryState.failed);
        expect(
          tester.takeAnnouncements().map((a) => a.message),
          [l10n.shareDeliveryFailed],
        );

        await tester.pump(ShareDeliveryHost.dismissAfter);
        await tester.pumpAndSettle();
        expect(find.text(l10n.shareDeliveryFailed), findsNothing);

        await tester.pump(
          ShareDeliveryCubit.overdueAfter - ShareDeliveryHost.dismissAfter,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.shareDeliveryFailed), findsNothing);
        expect(tester.takeAnnouncements(), isEmpty);
      });
    });

    group('resets', () {
      testWidgets('clears the banner when the environment changes', (
        tester,
      ) async {
        final harness = _Harness();
        final cubit = await harness.pump(tester);
        await harness.share(tester, cubit, [friend]);
        expect(find.text(l10n.dmPendingVideoSending), findsOneWidget);

        (harness.providers.read(
          currentEnvironmentProvider.notifier,
        ) as _TestEnvironment).switchTo(
          const EnvironmentConfig(environment: AppEnvironment.staging),
        );
        await tester.pumpAndSettle();

        expect(cubit.state, isNull);
        expect(find.text(l10n.dmPendingVideoSending), findsNothing);
      });
    });

    group('navigation', () {
      testWidgets(
        'View chat samples current restrictions and owner changes clear feedback',
        (tester) async {
          final harness = _Harness()..restricted = true;
          final cubit = await harness.pump(tester);
          await harness.share(tester, cubit, [friend]);
          expect(find.text(l10n.dmPendingVideoSending), findsOneWidget);
          final chat = find.text(l10n.dmReelReplyViewChat);
          await tester.tap(chat);
          await tester.pumpAndSettle();
          expect(find.text(_home), findsOneWidget);

          harness.restricted = false;
          harness.providers.invalidate(isDmRestrictedProvider);
          await harness.deliver(tester, 'Friend', DmDeliveryState.accepted);
          await tester.pumpAndSettle();
          expect(find.text(l10n.shareSent), findsOneWidget);
          await tester.tap(chat);
          await tester.pumpAndSettle();
          expect(find.text('Opened chat-Friend'), findsOneWidget);

          harness.owner = testPubkeyFromSeed(4);
          harness.providers
              .read(nostrSessionProvider.notifier)
              .update(
                NostrSessionReadiness.identityKnown(pubkey: harness.owner),
              );
          await tester.pumpAndSettle();
          expect(find.text(l10n.shareSent), findsNothing);
        },
      );
    });
  });
}
