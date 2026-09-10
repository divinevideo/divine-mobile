// ABOUTME: Widget tests for VerifiedAccountsSection in the profile-setup form.
// ABOUTME: Covers title rendering and the "Get verified" navigation.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';
import 'package:openvine/screens/profile_setup/widgets/verified_accounts_section.dart';
import 'package:openvine/screens/verify/verify_screen.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VerifiedAccountsSection, () {
    late _MockProfileEditorBloc editorBloc;
    late _MockMyProfileBloc myProfileBloc;

    setUp(() {
      editorBloc = _MockProfileEditorBloc();
      when(() => editorBloc.state).thenReturn(const ProfileEditorState());
      myProfileBloc = _MockMyProfileBloc();
      when(() => myProfileBloc.state).thenReturn(const MyProfileInitial());
      when(() => myProfileBloc.isClosed).thenReturn(false);
    });

    Future<void> pump(WidgetTester tester) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<ProfileEditorBloc>.value(value: editorBloc),
                  BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
                ],
                child: const VerifiedAccountsSection(),
              ),
            ),
          ),
          GoRoute(
            path: VerifyPage.path,
            name: VerifyPage.routeName,
            builder: (context, state) =>
                const Scaffold(body: Text('verify screen')),
          ),
        ],
      );
      addTearDown(router.dispose);
      return tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
    }

    testWidgets('renders the section title and get-verified CTA', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10n.profileEditVerifiedAccountsTitle), findsOneWidget);
      expect(find.text(l10n.profileEditGetVerifiedCta), findsOneWidget);
    });

    testWidgets('draws get-verified as a form card, not a list tile', (
      tester,
    ) async {
      await pump(tester);

      final row = tester.widget<ProfileSelectRow>(
        find.byType(ProfileSelectRow),
      );
      expect(row.label, l10n.profileEditGetVerifiedCta);
      expect(row.trailingColor, VineTheme.primary);
      expect(find.byType(ListTile), findsNothing);
      // The explanation survives the move, as the card's supporting text.
      expect(find.text(l10n.profileEditGetVerifiedSubtitle), findsOneWidget);
    });

    testWidgets('tapping get-verified opens the verify screen', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text(l10n.profileEditGetVerifiedCta));
      await tester.pumpAndSettle();

      expect(find.text('verify screen'), findsOneWidget);
    });

    testWidgets('re-reads the profile after the verify screen closes', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text(l10n.profileEditGetVerifiedCta));
      await tester.pumpAndSettle();

      // The chip row renders from MyProfileBloc, so a link added in the flow
      // only shows up here after a re-read.
      verifyNever(() => myProfileBloc.add(const MyProfileFetchRequested()));

      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      verify(
        () => myProfileBloc.add(const MyProfileFetchRequested()),
      ).called(1);
    });
  });
}
