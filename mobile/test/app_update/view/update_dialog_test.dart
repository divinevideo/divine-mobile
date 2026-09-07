import 'dart:async';

import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/navigator_keys.dart';

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(UpdateDialogListener, () {
    late _MockAppUpdateBloc bloc;

    setUp(() {
      bloc = _MockAppUpdateBloc();
    });

    /// Mirrors production topology: the listener sits *above* [MaterialApp],
    /// so its own [BuildContext] has no [Navigator] ancestor. The app is keyed
    /// to [NavigatorKeys.root] so the listener can resolve one the same way
    /// production does.
    ///
    /// When [withApp] is false the listener has no [MaterialApp] below it at
    /// all — the shape GeoBlockingGate produces while its check is in flight,
    /// where no [Navigator] exists yet. That stand-in is a spinner rather than
    /// an inert box on purpose: the gate's own spinner animates, so the app
    /// keeps producing frames throughout the wait, which is what drives the
    /// listener's deferred retry.
    Widget buildSubject({bool withApp = true}) {
      return BlocProvider<AppUpdateBloc>.value(
        value: bloc,
        child: UpdateDialogListener(
          child: withApp
              ? MaterialApp(
                  navigatorKey: NavigatorKeys.root,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: const Scaffold(body: Text('Home')),
                )
              : const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
      );
    }

    testWidgets('shows dialog when urgency transitions to moderate', (
      tester,
    ) async {
      whenListen(
        bloc,
        Stream.value(
          const AppUpdateState(
            status: AppUpdateStatus.resolved,
            urgency: UpdateUrgency.moderate,
            latestVersion: '1.0.8',
            downloadUrl: DownloadUrls.github,
            releaseHighlights: ['New feature'],
          ),
        ),
        initialState: const AppUpdateState(status: AppUpdateStatus.resolved),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.updateModerateTitle),
        findsOneWidget,
      );
      expect(find.text('New feature'), findsOneWidget);
      expect(find.text(l10n.updateAction), findsOneWidget);
      expect(find.text(l10n.updateNotNow), findsOneWidget);
    });

    testWidgets('shows urgent copy when urgency is urgent', (tester) async {
      whenListen(
        bloc,
        Stream.value(
          const AppUpdateState(
            status: AppUpdateStatus.resolved,
            urgency: UpdateUrgency.urgent,
            latestVersion: '1.0.9',
            downloadUrl: DownloadUrls.github,
            releaseHighlights: ['Security fix'],
          ),
        ),
        initialState: const AppUpdateState(status: AppUpdateStatus.resolved),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.updateUrgentTitle), findsOneWidget);
    });

    testWidgets('Not now button dispatches dismiss', (tester) async {
      whenListen(
        bloc,
        Stream.value(
          const AppUpdateState(
            status: AppUpdateStatus.resolved,
            urgency: UpdateUrgency.moderate,
            latestVersion: '1.0.8',
            downloadUrl: DownloadUrls.github,
          ),
        ),
        initialState: const AppUpdateState(status: AppUpdateStatus.resolved),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.updateNotNow));

      verify(() => bloc.add(const AppUpdateDismissed())).called(1);
    });

    testWidgets('defers the dialog until a Navigator exists', (tester) async {
      final states = StreamController<AppUpdateState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const AppUpdateState(status: AppUpdateStatus.resolved),
      );

      // No MaterialApp below the listener yet, so no Navigator anywhere.
      await tester.pumpWidget(buildSubject(withApp: false));

      states.add(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.moderate,
          latestVersion: '1.0.8',
          downloadUrl: DownloadUrls.github,
        ),
      );
      await tester.pump();

      expect(
        find.text(l10n.updateModerateTitle),
        findsNothing,
      );

      // The gate opens and the app — with it, the root Navigator — mounts.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.updateModerateTitle),
        findsOneWidget,
      );
    });

    testWidgets('stops waiting when no Navigator ever arrives', (tester) async {
      final states = StreamController<AppUpdateState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const AppUpdateState(status: AppUpdateStatus.resolved),
      );

      await tester.pumpWidget(buildSubject(withApp: false));

      states.add(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.moderate,
          latestVersion: '1.0.8',
          downloadUrl: DownloadUrls.github,
        ),
      );
      await tester.pump();

      // A geo-blocked user is served GeoBlockedScreen and never gets a
      // MaterialApp, so the retry has to give up rather than re-arm itself on
      // every frame for the rest of the session.
      await tester.pump(const Duration(seconds: 31));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.updateModerateTitle),
        findsNothing,
      );
    });
  });
}
