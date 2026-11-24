// ABOUTME: Widget tests for ProfileSetupListeners navigation and dialogs
// ABOUTME: Covers save results, overlay dismissal, and confirmation dialogs

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/image_url_sheet.dart';
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

    group('when an existing profile saves successfully', () {
      late BuildContext editorContext;
      late Future<bool?> saveResult;

      Future<void> openEditor(
        WidgetTester tester, {
        bool pushed = true,
      }) async {
        final router = GoRouter(
          initialLocation: pushed ? '/' : '/edit',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Profile home')),
            ),
            GoRoute(
              path: '/edit',
              builder: (context, _) {
                editorContext = context;
                return MultiBlocProvider(
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
                    child: const Scaffold(body: Text('Profile editor')),
                  ),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        if (pushed) saveResult = router.push<bool>('/edit');
        await tester.pumpAndSettle();
        expect(find.text('Profile editor'), findsOneWidget);
      }

      Future<void> completeSave(
        WidgetTester tester, {
        bool pushed = true,
      }) async {
        editorStates.add(
          const ProfileEditorState(status: ProfileEditorStatus.success),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Profile editor'), findsNothing);
        expect(find.text('Profile home'), findsOneWidget);
        if (pushed) expect(await saveResult, isTrue);
      }

      testWidgets('returns true to the editor caller', (tester) async {
        await openEditor(tester);
        await completeSave(tester);
      });

      testWidgets('cancels an open string-valued image URL sheet', (
        tester,
      ) async {
        await openEditor(tester);
        final urlResult = showImageUrlSheet(editorContext);
        await tester.pumpAndSettle();
        expect(find.text(l10n.profileSetupImageUrlTitle), findsWidgets);
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

        await completeSave(tester);

        expect(await urlResult, isNull);
        expect(find.text(l10n.profileSetupImageUrlTitle), findsNothing);
        verifyNever(() => editorBloc.add(any()));
      });

      testWidgets('drains editor local history before returning true', (
        tester,
      ) async {
        await openEditor(tester);
        var historyRemoved = false;
        ModalRoute.of(editorContext)!.addLocalHistoryEntry(
          LocalHistoryEntry(onRemove: () => historyRemoved = true),
        );

        await completeSave(tester);

        expect(historyRemoved, isTrue);
      });

      testWidgets(
        'returns a directly opened editor home after closing a sheet',
        (
          tester,
        ) async {
          await openEditor(tester, pushed: false);
          final urlResult = showImageUrlSheet(editorContext);
          await tester.pumpAndSettle();

          await completeSave(tester, pushed: false);

          expect(await urlResult, isNull);
        },
      );
    });

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
