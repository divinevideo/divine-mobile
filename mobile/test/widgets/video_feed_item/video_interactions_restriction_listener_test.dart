// ABOUTME: Verifies restricted interaction publishes open Account Status.
// ABOUTME: Pins the typed BLoC-state to UI-navigation boundary.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_restriction_listener.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

void main() {
  group('navigation', () {
    testWidgets('opens Account Status with confirmed-publish evidence', (
      tester,
    ) async {
      final bloc = _MockVideoInteractionsBloc();
      const initial = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
      );
      const restricted = VideoInteractionsState(
        accountRestrictionRevision: 1,
      );
      whenListen(bloc, Stream.value(restricted), initialState: initial);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                BlocProvider<VideoInteractionsBloc>.value(
                  value: bloc,
                  child: const VideoInteractionsRestrictionListener(
                    child: SizedBox(),
                  ),
                ),
          ),
          GoRoute(
            path: AccountStatusScreen.path,
            name: AccountStatusScreen.routeName,
            builder: (context, state) => Text('confirmed=${state.extra}'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('confirmed=true'), findsOneWidget);
    });

    testWidgets('does not stack Account Status for another restriction', (
      tester,
    ) async {
      final bloc = _MockVideoInteractionsBloc();
      final states = StreamController<VideoInteractionsState>();
      whenListen(
        bloc,
        states.stream,
        initialState: const VideoInteractionsState(),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                BlocProvider<VideoInteractionsBloc>.value(
                  value: bloc,
                  child: const VideoInteractionsRestrictionListener(
                    child: SizedBox(),
                  ),
                ),
          ),
          GoRoute(
            path: AccountStatusScreen.path,
            name: AccountStatusScreen.routeName,
            builder: (context, state) => Text('confirmed=${state.extra}'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      states.add(const VideoInteractionsState(accountRestrictionRevision: 1));
      await tester.pumpAndSettle();
      states.add(const VideoInteractionsState(accountRestrictionRevision: 2));
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      await states.close();
    });
  });
}
