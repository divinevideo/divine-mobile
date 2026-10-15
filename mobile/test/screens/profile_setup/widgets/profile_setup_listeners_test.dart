// ABOUTME: Widget tests for the dialogs ProfileSetupListeners opens
// ABOUTME: Covers the reserved-username and publish-confirmation dialogs

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_listeners.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ProfileSetupListeners, () {
    late _MockProfileEditorBloc editorBloc;
    late _MockMyProfileBloc myProfileBloc;
    late StreamController<ProfileEditorState> editorStates;
    late TextEditingController nameController;
    late TextEditingController bioController;
    late TextEditingController websiteController;
    late TextEditingController nip05Controller;

    setUp(() {
      editorStates = StreamController<ProfileEditorState>.broadcast();
      addTearDown(editorStates.close);

      editorBloc = _MockProfileEditorBloc();
      whenListen(
        editorBloc,
        editorStates.stream,
        initialState: const ProfileEditorState(),
      );
      when(() => editorBloc.isClosed).thenReturn(false);

      myProfileBloc = _MockMyProfileBloc();
      whenListen(
        myProfileBloc,
        const Stream<MyProfileState>.empty(),
        initialState: const MyProfileInitial(),
      );
      when(() => myProfileBloc.isClosed).thenReturn(false);

      nameController = TextEditingController();
      bioController = TextEditingController();
      websiteController = TextEditingController();
      nip05Controller = TextEditingController();
      addTearDown(nameController.dispose);
      addTearDown(bioController.dispose);
      addTearDown(websiteController.dispose);
      addTearDown(nip05Controller.dispose);
    });

    Future<void> pumpListeners(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileEditorBloc>.value(value: editorBloc),
              BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
            ],
            child: ProfileSetupListeners(
              isNewUser: false,
              nameController: nameController,
              bioController: bioController,
              websiteController: websiteController,
              nip05Controller: nip05Controller,
              child: const Scaffold(body: SizedBox.shrink()),
            ),
          ),
        ),
      );
    }

    group('when the username claim is rejected as reserved', () {
      const reserved = ProfileEditorState(
        status: ProfileEditorStatus.failure,
        error: ProfileEditorError.usernameReserved,
        username: 'reservedname',
      );

      testWidgets('opens $UsernameReservedDialog for the claimed username', (
        tester,
      ) async {
        await pumpListeners(tester);

        editorStates.add(reserved);
        await tester.pumpAndSettle();

        final dialog = tester.widget<UsernameReservedDialog>(
          find.byType(UsernameReservedDialog),
        );
        expect(dialog.username, equals('reservedname'));
      });

      testWidgets('Check again re-checks the username and closes the dialog', (
        tester,
      ) async {
        await pumpListeners(tester);
        editorStates.add(reserved);
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.profileSetupCheckAgain));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        verify(() => editorBloc.add(const UsernameRechecked())).called(1);
        expect(find.byType(UsernameReservedDialog), findsNothing);
      });
    });

    group('when saving needs confirmation', () {
      const confirmation = ProfileEditorState(
        status: ProfileEditorStatus.confirmationRequired,
      );

      testWidgets('Publish confirms the save and closes the dialog', (
        tester,
      ) async {
        await pumpListeners(tester);
        editorStates.add(confirmation);
        await tester.pumpAndSettle();
        expect(find.text(l10n.profileSetupCreateNewProfile), findsOneWidget);

        await tester.tap(find.text(l10n.profileSetupPublishButton));
        await tester.pumpAndSettle();

        verify(() => editorBloc.add(const ProfileSaveConfirmed())).called(1);
        expect(find.text(l10n.profileSetupCreateNewProfile), findsNothing);
      });

      testWidgets('Cancel closes the dialog without saving', (tester) async {
        await pumpListeners(tester);
        editorStates.add(confirmation);
        await tester.pumpAndSettle();
        expect(find.text(l10n.profileSetupCreateNewProfile), findsOneWidget);

        await tester.tap(find.text(l10n.profileCancelButton));
        await tester.pumpAndSettle();

        verifyNever(() => editorBloc.add(const ProfileSaveConfirmed()));
        expect(find.text(l10n.profileSetupCreateNewProfile), findsNothing);
      });
    });
  });
}
