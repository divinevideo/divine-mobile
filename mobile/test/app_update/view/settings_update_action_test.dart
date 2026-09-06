import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

void main() {
  group(SettingsUpdateAction, () {
    late _MockAppUpdateBloc bloc;

    setUp(() => bloc = _MockAppUpdateBloc());

    Widget buildSubject({UpdateUrlLauncher? launchUpdate}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AppUpdateBloc>.value(
          value: bloc,
          child: Scaffold(
            body: SettingsUpdateAction(
              launchUpdate: launchUpdate ?? (_) async {},
            ),
          ),
        ),
      );
    }

    testWidgets('is hidden when no update was resolved', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const AppUpdateState(status: AppUpdateStatus.resolved));

      await tester.pumpWidget(buildSubject());

      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('is hidden outside the app-level update scope', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsUpdateAction()),
        ),
      );

      expect(find.text('Update available'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is hidden when an update has no usable store URL', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          latestVersion: '1.0.21',
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('remains visible after the transient nudge is dismissed', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          latestVersion: '1.0.21',
          downloadUrl: DownloadUrls.appStore,
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('opens the resolved store URL', (tester) async {
      Uri? launchedUri;
      when(() => bloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.gentle,
          latestVersion: '1.0.21',
          downloadUrl: DownloadUrls.appStore,
        ),
      );

      await tester.pumpWidget(
        buildSubject(launchUpdate: (uri) async => launchedUri = uri),
      );
      await tester.tap(find.text('Update available'));
      await tester.pump();

      expect(launchedUri, Uri.parse(DownloadUrls.appStore));
    });
  });
}
