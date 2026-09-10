// ABOUTME: Widget tests for SaveButton in the profile-setup form.
// ABOUTME: Covers enabled/disabled states from canSave + bloc loading status.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/save_button.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(SaveButton, () {
    late _MockProfileEditorBloc bloc;

    setUp(() {
      bloc = _MockProfileEditorBloc();
      when(() => bloc.state).thenReturn(const ProfileEditorState());
    });

    testWidgets('shows the save label and calls onSave when enabled', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileEditorBloc>.value(
              value: bloc,
              child: SaveButton(canSave: true, onSave: () => tapped = true),
            ),
          ),
        ),
      );
      expect(find.text(l10n.profileSetupSaveButton), findsOneWidget);
      await tester.tap(find.byType(SaveButton));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onSave when canSave is false', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileEditorBloc>.value(
              value: bloc,
              child: SaveButton(canSave: false, onSave: () => tapped = true),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SaveButton));
      expect(tapped, isFalse);
    });

    testWidgets('shows the saving label and is disabled while loading', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ProfileEditorState(status: ProfileEditorStatus.loading),
      );
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<ProfileEditorBloc>.value(
              value: bloc,
              child: SaveButton(canSave: true, onSave: () => tapped = true),
            ),
          ),
        ),
      );
      expect(find.text(l10n.profileSetupSavingButton), findsOneWidget);
      await tester.tap(find.byType(SaveButton));
      expect(tapped, isFalse);
    });
  });
}
