// ABOUTME: Widget tests for UsernameField in the profile-setup form.
// ABOUTME: Covers label/status rendering, external-mode disabling, and dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/username_field.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(UsernameField, () {
    late TextEditingController controller;
    late FocusNode nextFocusNode;
    late _MockProfileEditorBloc bloc;

    setUp(() {
      controller = TextEditingController();
      nextFocusNode = FocusNode();
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
    });

    tearDown(() {
      controller.dispose();
      nextFocusNode.dispose();
    });

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileEditorBloc>.value(
              value: bloc,
              child: UsernameField(
                controller: controller,
                nextFocusNode: nextFocusNode,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the localized label and the status indicator', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10n.profileSetupUsernameLabel), findsOneWidget);
      expect(find.text(l10n.profileSetupUsernameHelper), findsOneWidget);
      expect(find.byType(UsernameStatusIndicator), findsOneWidget);
    });

    testWidgets('typing dispatches UsernameChanged with the entered value', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'bob');
      final changes = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<UsernameChanged>().toList();
      expect(changes.last.username, 'bob');
    });

    testWidgets('keeps invalid characters visible for validation feedback', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'Last_Outlaw');

      expect(controller.text, 'last_outlaw');
      final changes = verify(
        () => bloc.add(captureAny()),
      ).captured.whereType<UsernameChanged>().toList();
      expect(changes.last.username, 'last_outlaw');
    });

    testWidgets('pins the public handle shape to at-name', (tester) async {
      await pump(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.prefixText, '@');
      expect(field.decoration?.suffixText, isNull);
    });

    testWidgets('the keyboard next key skips the select row for the bio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileEditorBloc>.value(
              value: bloc,
              child: Column(
                children: [
                  UsernameField(
                    controller: controller,
                    nextFocusNode: nextFocusNode,
                  ),
                  // Stands in for the NIP-05 card: focusable, but with no
                  // keyboard. A plain nextFocus() stops here.
                  InkWell(onTap: () {}, child: const Text('select')),
                  TextField(focusNode: nextFocusNode),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(nextFocusNode.hasFocus, isTrue);
    });

    testWidgets('field is disabled in external NIP-05 mode', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const ProfileEditorState(nip05Mode: Nip05Mode.external_));
      await pump(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      // The status indicator is hidden while editing an external identifier.
      expect(find.byType(UsernameStatusIndicator), findsNothing);
    });
  });
}
