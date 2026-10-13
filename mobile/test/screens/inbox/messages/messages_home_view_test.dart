import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/messages/messages_navigation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/messages/messages_home_view.dart';
import 'package:openvine/services/messages_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(MessagesHomeView, () {
    late MessagesNavigationCubit cubit;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cubit = MessagesNavigationCubit(
        account: 'a' * 64,
        preferences: MessagesPreferenceService(
          await SharedPreferences.getInstance(),
        ),
      );
    });
    tearDown(() => cubit.close());

    Widget subject({double textScale = 1, ThemeData? theme}) => MaterialApp(
      theme: theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const MessagesHomeView(
              direct: TextField(key: Key('direct-draft')),
              rooms: Text('rooms-content'),
            ),
          ),
        ),
      ),
    );

    testWidgets('switches panes and preserves the Direct draft', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.enterText(
        find.byKey(const Key('direct-draft')),
        'unfinished',
      );
      await cubit.select(MessagesSection.rooms);
      await tester.pump();
      expect(find.byKey(const Key('direct-draft')), findsNothing);
      expect(find.text('rooms-content'), findsOneWidget);
      await cubit.select(MessagesSection.direct);
      await tester.pump();
      expect(find.text('unfinished'), findsOneWidget);
      expect(find.text('rooms-content'), findsNothing);
    });

    for (final theme in [VineTheme.theme, VineTheme.lightTheme]) {
      testWidgets('controls support large text in ${theme.brightness}', (
        tester,
      ) async {
        await tester.pumpWidget(subject(textScale: 2, theme: theme));
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.messagesRooms));
        await tester.pump();
        expect(find.text('rooms-content'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
