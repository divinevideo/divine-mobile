import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(UpdateBanner, () {
    late _MockAppUpdateBloc bloc;

    setUp(() {
      bloc = _MockAppUpdateBloc();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AppUpdateBloc>.value(
          value: bloc,
          child: const Scaffold(body: UpdateBanner()),
        ),
      );
    }

    testWidgets('renders nothing when urgency is none', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const AppUpdateState(status: AppUpdateStatus.resolved));

      await tester.pumpWidget(buildSubject());

      expect(
        find.text('A fresh update just dropped. Check it out →'),
        findsNothing,
      );
    });

    testWidgets('renders banner when urgency is gentle', (tester) async {
      when(() => bloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.gentle,
          downloadUrl: DownloadUrls.github,
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(
        find.text('A fresh update just dropped. Check it out →'),
        findsOneWidget,
      );
    });

    testWidgets('dismiss button dispatches AppUpdateDismissed', (tester) async {
      when(() => bloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.gentle,
          downloadUrl: DownloadUrls.github,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(_divineIcon(DivineIconName.x));

      verify(() => bloc.add(const AppUpdateDismissed())).called(1);
    });

    testWidgets('renders nothing for moderate urgency', (tester) async {
      when(() => bloc.state).thenReturn(
        const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.moderate,
          downloadUrl: DownloadUrls.github,
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(
        find.text('A fresh update just dropped. Check it out →'),
        findsNothing,
      );
    });
  });
}
