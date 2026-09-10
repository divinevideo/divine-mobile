// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';
import 'package:riverpod/misc.dart' show Override;

import '../helpers/test_provider_overrides.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('UsernameStatusIndicator', () {
    late _MockProfileEditorBloc mockBloc;

    setUp(() {
      mockBloc = _MockProfileEditorBloc();
      when(() => mockBloc.state).thenReturn(
        const ProfileEditorState(
          username: 'testuser',
          usernameStatus: UsernameStatus.reserved,
        ),
      );
    });

    Widget buildIndicator(
      UsernameStatus status, {
      UsernameValidationError? error,
      Locale locale = const Locale('en'),
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: UsernameStatusIndicator(status: status, error: error),
        ),
      );
    }

    Widget buildIndicatorWithBloc(
      UsernameStatus status, {
      UsernameValidationError? error,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ProfileEditorBloc>.value(
          value: mockBloc,
          child: Scaffold(
            body: UsernameStatusIndicator(status: status, error: error),
          ),
        ),
      );
    }

    testWidgets('shows nothing when status is idle', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.idle));

      expect(find.text('Checking availability...'), findsNothing);
      expect(find.text('Username available!'), findsNothing);
      expect(find.text('Username already taken'), findsNothing);
      expect(find.text('Username is reserved'), findsNothing);
    });

    testWidgets('shows spinner when checking', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.checking));

      expect(find.text('Checking availability...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows green checkmark when available', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.available));

      expect(find.text('Username available!'), findsOneWidget);
      expect(_divineIcon(DivineIconName.checkCircle), findsOneWidget);
    });

    testWidgets('shows red X when taken', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.taken));

      expect(find.text('Username already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('shows reserved indicator when status is reserved', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(_divineIcon(DivineIconName.lockSimple), findsOneWidget);
    });

    testWidgets('shows Contact support link when reserved', (tester) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('shows Check again link when reserved', (tester) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('Check again link adds $UsernameRechecked event', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const UsernameRechecked())).called(1);
    });

    testWidgets('shows error message when network error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.networkError,
        ),
      );

      expect(
        find.text('Could not check availability. Please try again.'),
        findsOneWidget,
      );
      expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
    });

    testWidgets('shows default error message when no error provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.error));

      expect(find.text('Failed to check availability'), findsOneWidget);
      expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
    });

    testWidgets('shows generic format error for an unclassified rejection', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.invalidFormat,
        ),
      );

      expect(
        find.text(l10n.profileSetupUsernameInvalidFormatGeneric),
        findsOneWidget,
      );
    });

    testWidgets('shows the localized invalid-character error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.invalidFormat,
          error: UsernameValidationError.invalidCharacters,
        ),
      );

      expect(
        find.text(l10n.profileSetupUsernameInvalidFormat),
        findsOneWidget,
      );
    });

    testWidgets('shows the localized edge-hyphen error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.invalidFormat,
          error: UsernameValidationError.invalidHyphenPlacement,
        ),
      );

      expect(
        find.text(l10n.profileSetupUsernameInvalidHyphenPlacement),
        findsOneWidget,
      );
    });

    testWidgets('shows the edge-hyphen error in German', (tester) async {
      final de = lookupAppLocalizations(const Locale('de'));
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.invalidFormat,
          error: UsernameValidationError.invalidHyphenPlacement,
          locale: const Locale('de'),
        ),
      );

      expect(
        find.text(de.profileSetupUsernameInvalidHyphenPlacement),
        findsOneWidget,
      );
      expect(
        find.text(l10n.profileSetupUsernameInvalidHyphenPlacement),
        findsNothing,
      );
    });

    testWidgets('shows length error message', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.invalidLength,
        ),
      );

      expect(
        find.text(l10n.profileSetupUsernameInvalidLength),
        findsOneWidget,
      );
    });
  });

  group('LowercaseTextInputFormatter', () {
    const formatter = LowercaseTextInputFormatter();

    TextEditingValue value(String text, {int? selection}) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection ?? text.length),
      );
    }

    test('lowercases newly typed uppercase letters', () {
      final result = formatter.formatEditUpdate(value(''), value('Alice'));

      expect(result.text, 'alice');
      expect(result.selection.baseOffset, 5);
    });

    test('preserves all-lowercase input unchanged (returns same instance)', () {
      final next = value('alice');
      final result = formatter.formatEditUpdate(value(''), next);

      expect(identical(result, next), isTrue);
    });

    test('preserves caret position when editing in the middle', () {
      // User has "abcde" with caret at offset 2, types capital "X" — newValue
      // is "abXcde" with caret at 3.
      final result = formatter.formatEditUpdate(
        value('abcde', selection: 2),
        value('abXcde', selection: 3),
      );

      expect(result.text, 'abxcde');
      expect(result.selection.baseOffset, 3);
    });

    test('lowercases pasted mixed-case text', () {
      final result = formatter.formatEditUpdate(value(''), value('MrBeast123'));

      expect(result.text, 'mrbeast123');
    });
  });

  group('username field input formatters', () {
    Widget buildField(TextEditingController controller) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: const [
              LowercaseTextInputFormatter(),
            ],
          ),
        ),
      );
    }

    testWidgets('uppercase typed by user is normalized to lowercase', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildField(controller));

      await tester.enterText(find.byType(TextField), 'Alice');

      expect(controller.text, 'alice');
    });

    testWidgets('disallowed characters stay visible, capitals are lowercased', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildField(controller));

      // Invalid characters remain available to the validator; capitals are
      // still normalized.
      await tester.enterText(find.byType(TextField), 'Mr Beast.123_xyz');

      expect(controller.text, 'mr beast.123_xyz');
    });
  });

  group('UsernameReservedDialog', () {
    late _MockProfileEditorBloc mockBloc;

    setUp(() {
      mockBloc = _MockProfileEditorBloc();
      when(() => mockBloc.state).thenReturn(
        const ProfileEditorState(
          username: 'reservedname',
          usernameStatus: UsernameStatus.reserved,
        ),
      );
    });

    Widget buildDialog(String username) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ProfileEditorBloc>.value(
          value: mockBloc,
          child: Scaffold(body: UsernameReservedDialog(username)),
        ),
      );
    }

    testWidgets('shows correct title', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.text('Username reserved'), findsOneWidget);
    });

    testWidgets('shows username in message content', (tester) async {
      const username = 'reservedname';
      await tester.pumpWidget(buildDialog(username));

      expect(
        find.text(
          'The name $username is reserved. Tell us why it should be yours.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has reason text field', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text("e.g. It's my brand name, stage name, etc."),
        findsOneWidget,
      );
    });

    testWidgets('has Close button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      final closeButton = find.widgetWithText(TextButton, 'Close');
      expect(closeButton, findsOneWidget);
    });

    testWidgets('has Send request button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    });

    testWidgets('has Check again button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.widgetWithText(TextButton, 'Check again'), findsOneWidget);
    });

    testWidgets('Close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider<ProfileEditorBloc>.value(
                      value: mockBloc,
                      child: const UsernameReservedDialog('testuser'),
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Username reserved'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Username reserved'), findsNothing);
    });

    testWidgets('Check again button adds $UsernameRechecked event', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider<ProfileEditorBloc>.value(
                      value: mockBloc,
                      child: const UsernameReservedDialog('testuser'),
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Check again'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const UsernameRechecked())).called(1);
    });

    testWidgets('shows hint about checking again after contacting support', (
      tester,
    ) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(
        find.text(
          'Already contacted support? Tap "Check again" to see if '
          "it's been released to you.",
        ),
        findsOneWidget,
      );
    });
  });

  group('profileSetupUploadErrorMessage', () {
    Future<AppLocalizations> loadL10n(WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      return l10n;
    }

    testWidgets('maps network case to network error string', (tester) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(l10n, AvatarUploadError.network),
        l10n.profileSetupUploadNetworkError,
      );
    });

    testWidgets('maps auth case to auth error string', (tester) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(l10n, AvatarUploadError.auth),
        l10n.profileSetupUploadAuthError,
      );
    });

    testWidgets('maps fileTooLarge case to file-size error string', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(l10n, AvatarUploadError.fileTooLarge),
        l10n.profileSetupUploadFileTooLarge,
      );
    });

    testWidgets('maps server case to server error string', (tester) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(l10n, AvatarUploadError.server),
        l10n.profileSetupUploadServerError,
      );
    });

    testWidgets('maps generic case to generic fallback string', (tester) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(l10n, AvatarUploadError.generic),
        l10n.profileSetupUploadFailedGeneric,
      );
    });
  });

  group('profileSetupUploadStaged copy', () {
    // Pin the staged-state copy to the contract the reviewer asked for:
    // "Uploaded — tap Save to apply" (or equivalent). The exact English wording
    // is verified verbatim so a silent product-copy change forces a deliberate
    // ARB edit instead of slipping through review.
    test('English copy reads as the staged-not-saved contract', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        l10n.profileSetupUploadStaged,
        equals('Uploaded — tap Save to apply'),
      );
    });

    // Spot-check one other locale to prove the key resolves through l10n
    // (not hardcoded English). German is dense enough to break a typo.
    test('German copy is translated, not falling back to English', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final de = lookupAppLocalizations(const Locale('de'));

      expect(
        de.profileSetupUploadStaged,
        isNot(equals(en.profileSetupUploadStaged)),
      );
      expect(de.profileSetupUploadStaged, contains('Speichern'));
    });
  });

  // #3933 demoted the npub to a bare link; the current design brings the
  // labeled field back, with copy as its one affordance.
  group('$ProfileSetupScreen public key', () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

    late MockAuthService mockAuthService;
    late MockProfileRepository mockProfileRepository;

    setUp(() {
      mockAuthService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: testPubkeyHex,
      );
      when(() => mockAuthService.currentNpub).thenReturn(testNpub);
      when(() => mockAuthService.hasExistingProfile).thenReturn(true);

      mockProfileRepository = createMockProfileRepository();
    });

    List<Override> baseOverrides() {
      return [
        authServiceProvider.overrideWithValue(mockAuthService),
        profileRepositoryProvider.overrideWith((ref) => mockProfileRepository),
        profileReadRepositoryProvider.overrideWith(
          (ref) => mockProfileRepository,
        ),
        fetchUserProfileProvider(
          testPubkeyHex,
        ).overrideWith((ref) async => null),
        userProfileReactiveProvider(
          testPubkeyHex,
        ).overrideWith((ref) => Stream<models.UserProfile?>.value(null)),
      ];
    }

    Widget buildSubject() {
      return testProviderScope(
        additionalOverrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const ProfileSetupScreen(isNewUser: false),
        ),
      );
    }

    testWidgets('renders the npub field with the whole identifier', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileSetupPublicKeyLabel), findsOneWidget);
      // Held whole: the row ellipsises on overflow but never shortens the
      // identifier itself.
      expect(find.text(testNpub), findsOneWidget);
    });

    testWidgets('copies the npub to the clipboard', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final copyButton = find.descendant(
        of: find.byType(PublicKeyRow),
        matching: find.byType(DivineIconButton),
      );
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pump();

      expect(copied, testNpub);
    });

    testWidgets('announces the copy button by its action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final announced = tester.getSemantics(
        find.descendant(
          of: find.byType(PublicKeyRow),
          matching: find.byType(DivineIconButton),
        ),
      );
      // Naming the field leaves a screen reader user with "Public key (npub)"
      // twice and no hint that the button copies; naming the confirmation
      // claims the copy already happened.
      expect(announced.label, contains(l10n.profileCopyPublicKey));
      expect(announced.label, isNot(contains(l10n.profilePublicKeyCopied)));
      expect(find.byTooltip(l10n.profileCopyPublicKey), findsOneWidget);

      handle.dispose();
    });
  });

  group(ProfileSetupScreen, () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

    late MockAuthService mockAuthService;
    late MockProfileRepository mockProfileRepository;
    late _MockProfileEditorBloc mockEditorBloc;
    late _MockMyProfileBloc mockMyProfileBloc;

    setUp(() {
      mockAuthService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: testPubkeyHex,
      );
      when(() => mockAuthService.currentNpub).thenReturn('npub-test-profile');
      when(() => mockAuthService.hasExistingProfile).thenReturn(true);

      mockProfileRepository = createMockProfileRepository();

      mockEditorBloc = _MockProfileEditorBloc();
      when(() => mockEditorBloc.state).thenReturn(const ProfileEditorState());
      when(() => mockEditorBloc.isClosed).thenReturn(false);

      mockMyProfileBloc = _MockMyProfileBloc();
      when(() => mockMyProfileBloc.state).thenReturn(const MyProfileInitial());
      when(() => mockMyProfileBloc.isClosed).thenReturn(false);
    });

    /// Pumps the screen with mocked blocs. The bloc state is owned by the
    /// caller (drive `mockEditorBloc.state` before / after `pumpScreen`).
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            profileRepositoryProvider.overrideWith(
              (ref) => mockProfileRepository,
            ),
            profileReadRepositoryProvider.overrideWith(
              (ref) => mockProfileRepository,
            ),
            fetchUserProfileProvider(
              testPubkeyHex,
            ).overrideWith((ref) async => null),
            userProfileReactiveProvider(
              testPubkeyHex,
            ).overrideWith((ref) => Stream<models.UserProfile?>.value(null)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<ProfileEditorBloc>.value(value: mockEditorBloc),
                BlocProvider<MyProfileBloc>.value(value: mockMyProfileBloc),
              ],
              child: const ProfileSetupScreenView(isNewUser: false),
            ),
          ),
        ),
      );
    }

    Future<void> pumpScreenWithRouter(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: ProfileSetupScreen.editPath,
        routes: [
          GoRoute(
            path: ProfileSetupScreen.editPath,
            name: ProfileSetupScreen.editRouteName,
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider<ProfileEditorBloc>.value(value: mockEditorBloc),
                BlocProvider<MyProfileBloc>.value(value: mockMyProfileBloc),
              ],
              child: const ProfileSetupScreenView(isNewUser: false),
            ),
          ),
          GoRoute(
            path: '/profile/:npub',
            builder: (context, state) => const Scaffold(
              body: Text('Profile destination'),
            ),
          ),
          GoRoute(
            path: '/home/:tab',
            builder: (context, state) => const Scaffold(
              body: Text('Home destination'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            profileRepositoryProvider.overrideWith(
              (ref) => mockProfileRepository,
            ),
            profileReadRepositoryProvider.overrideWith(
              (ref) => mockProfileRepository,
            ),
            fetchUserProfileProvider(
              testPubkeyHex,
            ).overrideWith((ref) async => null),
            userProfileReactiveProvider(
              testPubkeyHex,
            ).overrideWith((ref) => Stream<models.UserProfile?>.value(null)),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      );
    }

    /// A profile snapshot. [eventId] must differ between snapshots that stand
    /// for different kind-0 events — `UserProfile` equality is `pubkey` plus
    /// `eventId`, so same-id profiles compare equal whatever their content.
    models.UserProfile cachedProfile({
      String? displayName = 'Cached Name',
      String? picture = 'https://cdn.example.com/cached-avatar.jpg',
      String? banner,
      String eventId =
          'event111111111111111111111111111111111111111111111111111111111111',
    }) => models.UserProfile(
      pubkey: testPubkeyHex,
      displayName: displayName,
      about: 'Cached bio',
      picture: picture,
      banner: banner,
      rawData: const {},
      createdAt: DateTime(2024),
      eventId: eventId,
    );

    const freshEventId =
        'event222222222222222222222222222222222222222222222222222222222222';

    group('seeding the form', () {
      testWidgets('fills from the cached profile before the relay answers', (
        tester,
      ) async {
        // MyProfileLoading is what carries the cache; MyProfileLoaded only
        // arrives once fetchFreshProfile returns. Waiting for the latter left
        // the form blank for the whole round trip.
        whenListen(
          mockMyProfileBloc,
          Stream<MyProfileState>.fromIterable([
            MyProfileLoading(profile: cachedProfile()),
          ]),
          initialState: const MyProfileInitial(),
        );

        await pumpScreen(tester);
        await tester.pump();

        expect(find.text('Cached Name'), findsOneWidget);
        final seeded = verify(
          () => mockEditorBloc.add(captureAny()),
        ).captured.whereType<InitialPersistedPictureSet>();
        expect(seeded, hasLength(1));
        expect(
          seeded.single.pictureUrl,
          'https://cdn.example.com/cached-avatar.jpg',
        );
      });

      testWidgets('a later snapshot does not overwrite what the user typed', (
        tester,
      ) async {
        final controller = StreamController<MyProfileState>();
        addTearDown(controller.close);
        whenListen(
          mockMyProfileBloc,
          controller.stream,
          initialState: const MyProfileInitial(),
        );

        await pumpScreen(tester);
        controller.add(MyProfileLoading(profile: cachedProfile()));
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'My Own Name');
        await tester.pump();

        // The fresh profile lands while the user is mid-edit.
        controller.add(
          MyProfileLoaded(
            profile: cachedProfile(
              displayName: 'Relay Name',
              eventId: freshEventId,
            ),
            isFresh: true,
          ),
        );
        await tester.pump();

        expect(find.text('My Own Name'), findsOneWidget);
        expect(find.text('Relay Name'), findsNothing);
      });

      testWidgets('a fresher profile still refreshes an untouched field', (
        tester,
      ) async {
        final controller = StreamController<MyProfileState>();
        addTearDown(controller.close);
        whenListen(
          mockMyProfileBloc,
          controller.stream,
          initialState: const MyProfileInitial(),
        );

        await pumpScreen(tester);
        controller.add(MyProfileLoading(profile: cachedProfile()));
        await tester.pump();
        expect(find.text('Cached Name'), findsOneWidget);

        controller.add(
          MyProfileLoaded(
            profile: cachedProfile(
              displayName: 'Relay Name',
              eventId: freshEventId,
            ),
            isFresh: true,
          ),
        );
        await tester.pump();

        expect(find.text('Relay Name'), findsOneWidget);
      });

      testWidgets('seeds a NIP-05 the cached snapshot did not carry', (
        tester,
      ) async {
        // The cache can predate a NIP-05 set on another device. Keying the
        // one-shot on the first snapshot rather than on the value left the
        // editor in divine mode with no external address to preserve.
        final controller = StreamController<MyProfileState>();
        addTearDown(controller.close);
        whenListen(
          mockMyProfileBloc,
          controller.stream,
          initialState: const MyProfileInitial(),
        );

        await pumpScreen(tester);
        controller.add(MyProfileLoading(profile: cachedProfile()));
        await tester.pump();

        controller.add(
          MyProfileLoaded(
            profile: cachedProfile(eventId: freshEventId),
            isFresh: true,
            externalNip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        final captured = verify(
          () => mockEditorBloc.add(captureAny()),
        ).captured;
        expect(captured.whereType<InitialUsernameSet>(), isEmpty);
        expect(
          captured.whereType<InitialExternalNip05Set>().single.nip05,
          'alice@example.com',
        );
        expect(
          captured.whereType<Nip05ModeChanged>().where(
            (e) => e.mode == Nip05Mode.external_,
          ),
          hasLength(1),
        );
      });

      testWidgets(
        'a fresher Divine handle replaces a stale cached external NIP-05',
        (tester) async {
          final controller = StreamController<MyProfileState>();
          addTearDown(controller.close);
          whenListen(
            mockMyProfileBloc,
            controller.stream,
            initialState: const MyProfileInitial(),
          );

          await pumpScreen(tester);
          controller.add(
            MyProfileLoading(
              profile: cachedProfile(),
              externalNip05: 'alice@example.com',
            ),
          );
          await tester.pump();

          controller.add(
            MyProfileLoaded(
              profile: cachedProfile(eventId: freshEventId),
              isFresh: true,
              extractedUsername: 'bob',
            ),
          );
          await tester.pump();

          final captured = verify(
            () => mockEditorBloc.add(captureAny()),
          ).captured;
          expect(
            captured.whereType<InitialExternalNip05Set>().single.nip05,
            'alice@example.com',
          );
          expect(
            captured.whereType<InitialUsernameSet>().single.username,
            'bob',
          );
          expect(
            captured.whereType<Nip05ModeChanged>().map((e) => e.mode),
            containsAllInOrder([Nip05Mode.external_, Nip05Mode.divine]),
          );
        },
      );

      testWidgets(
        'a fresher Divine handle refreshes an untouched cached handle',
        (
          tester,
        ) async {
          final controller = StreamController<MyProfileState>();
          addTearDown(controller.close);
          whenListen(
            mockMyProfileBloc,
            controller.stream,
            initialState: const MyProfileInitial(),
          );

          await pumpScreen(tester);
          controller.add(
            MyProfileLoading(
              profile: cachedProfile(),
              extractedUsername: 'alice',
            ),
          );
          await tester.pump();

          controller.add(
            MyProfileLoaded(
              profile: cachedProfile(eventId: freshEventId),
              isFresh: true,
              extractedUsername: 'bob',
            ),
          );
          await tester.pump();

          final usernames = verify(
            () => mockEditorBloc.add(captureAny()),
          ).captured.whereType<InitialUsernameSet>().map((e) => e.username);
          expect(usernames, containsAllInOrder(['alice', 'bob']));
        },
      );

      testWidgets(
        'a fresher banner replaces an untouched cached colour banner',
        (tester) async {
          final controller = StreamController<MyProfileState>();
          addTearDown(controller.close);
          whenListen(
            mockMyProfileBloc,
            controller.stream,
            initialState: const MyProfileInitial(),
          );

          await pumpScreen(tester);
          controller.add(
            MyProfileLoading(
              profile: cachedProfile(banner: '0x33ccbf'),
            ),
          );
          await tester.pump();

          when(() => mockEditorBloc.state).thenReturn(
            const ProfileEditorState(
              persistedBanner: '0x33ccbf',
              pendingBannerColor: Color(0xFF33CCBF),
            ),
          );
          controller.add(
            MyProfileLoaded(
              profile: cachedProfile(
                banner: 'https://cdn.example.com/fresh-banner.jpg',
                eventId: freshEventId,
              ),
              isFresh: true,
            ),
          );
          await tester.pump();

          final seeded = verify(
            () => mockEditorBloc.add(captureAny()),
          ).captured.whereType<InitialPersistedBannerSet>().toList();
          expect(seeded, hasLength(2));
          expect(seeded.first.banner, '0x33ccbf');
          expect(
            seeded.last.banner,
            'https://cdn.example.com/fresh-banner.jpg',
          );
        },
      );

      testWidgets('seeds the NIP-05 once, not on every snapshot', (
        tester,
      ) async {
        final controller = StreamController<MyProfileState>();
        addTearDown(controller.close);
        whenListen(
          mockMyProfileBloc,
          controller.stream,
          initialState: const MyProfileInitial(),
        );

        await pumpScreen(tester);
        controller.add(
          MyProfileLoading(
            profile: cachedProfile(),
            externalNip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        controller.add(
          MyProfileLoaded(
            profile: cachedProfile(eventId: freshEventId),
            isFresh: true,
            externalNip05: 'alice@example.com',
          ),
        );
        await tester.pump();

        final captured = verify(
          () => mockEditorBloc.add(captureAny()),
        ).captured;
        expect(captured.whereType<InitialUsernameSet>(), isEmpty);
        expect(captured.whereType<InitialExternalNip05Set>(), hasLength(1));
      });
    });

    testWidgets('banner staged snackbar uses staged-save copy', (tester) async {
      whenListen(
        mockEditorBloc,
        Stream<ProfileEditorState>.fromIterable([
          const ProfileEditorState(
            pendingBannerStatus: PendingBannerStatus.staged,
          ),
        ]),
        initialState: const ProfileEditorState(),
      );

      await pumpScreen(tester);
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileSetupUploadStaged), findsOneWidget);
      expect(find.text('Banner updated'), findsNothing);
    });

    group('unsaved edit guard', () {
      const dirtyState = ProfileEditorState(
        displayName: 'Edited',
        initialDisplayName: 'Original',
      );

      testWidgets('system back with a dirty edit shows the prompt', (
        tester,
      ) async {
        when(() => mockEditorBloc.state).thenReturn(dirtyState);

        await pumpScreenWithRouter(tester);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.profileSetupUnsavedChangesTitle),
          findsOneWidget,
        );
        expect(find.text('Profile destination'), findsNothing);
      });

      testWidgets('keep editing dismisses the dirty prompt', (tester) async {
        when(() => mockEditorBloc.state).thenReturn(dirtyState);

        await pumpScreenWithRouter(tester);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.text(l10n.profileSetupUnsavedChangesKeepButton).last,
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.profileSetupUnsavedChangesTitle),
          findsNothing,
        );
        expect(find.byType(ProfileSetupScreenView), findsOneWidget);
      });

      testWidgets('discard clears edit state and leaves the screen', (
        tester,
      ) async {
        when(() => mockEditorBloc.state).thenReturn(dirtyState);

        await pumpScreenWithRouter(tester);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.text(l10n.profileSetupUnsavedChangesDiscardButton).last,
        );
        await tester.pumpAndSettle();

        verify(
          () => mockEditorBloc.add(const ProfileEditDiscarded()),
        ).called(1);
        expect(find.text('Profile destination'), findsOneWidget);
      });

      testWidgets('save from prompt dispatches ProfileSaved', (tester) async {
        when(() => mockEditorBloc.state).thenReturn(dirtyState);

        await pumpScreenWithRouter(tester);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'Edited');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.text(l10n.profileSetupUnsavedChangesSaveButton).last,
        );
        await tester.pumpAndSettle();

        final captured = verify(
          () => mockEditorBloc.add(captureAny(that: isA<ProfileSaved>())),
        ).captured;
        expect(captured.whereType<ProfileSaved>().last.displayName, 'Edited');
      });

      testWidgets('prompt does not offer save for an invalid username', (
        tester,
      ) async {
        when(() => mockEditorBloc.state).thenReturn(
          const ProfileEditorState(
            displayName: 'Edited',
            initialDisplayName: 'Original',
            username: 'last_outlaw',
            usernameStatus: UsernameStatus.invalidFormat,
            usernameError: UsernameValidationError.invalidCharacters,
          ),
        );

        await pumpScreenWithRouter(tester);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.profileSetupUnsavedChangesTitle),
          findsOneWidget,
        );
        expect(
          find.text(l10n.profileSetupUnsavedChangesSaveButton),
          findsNothing,
        );
        verifyNever(
          () => mockEditorBloc.add(any(that: isA<ProfileSaved>())),
        );
      });

      testWidgets('clean cancel leaves without showing prompt', (tester) async {
        when(() => mockEditorBloc.state).thenReturn(const ProfileEditorState());

        await pumpScreenWithRouter(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.profileSetupUnsavedChangesTitle),
          findsNothing,
        );
        expect(find.text('Profile destination'), findsOneWidget);
      });

      /// The guard compares each field against a baseline the seeding path
      /// supplies. Seeding runs more than once — the cache fills the form and
      /// the relay's copy refreshes whatever the user has not touched — so the
      /// baseline has to keep up with it.
      group('against the real editor bloc', () {
        late ProfileEditorBloc editorBloc;
        late StreamController<MyProfileState> profileStates;

        setUp(() {
          editorBloc = ProfileEditorBloc(
            profileRepository: mockProfileRepository,
            blossomUploadService: _MockBlossomUploadService(),
            hasExistingProfile: true,
            currentUserPubkey: testPubkeyHex,
          );
          addTearDown(editorBloc.close);

          profileStates = StreamController<MyProfileState>();
          addTearDown(profileStates.close);
          whenListen(
            mockMyProfileBloc,
            profileStates.stream,
            initialState: const MyProfileInitial(),
          );
        });

        Future<void> pumpRealBloc(WidgetTester tester) async {
          await tester.pumpWidget(
            testProviderScope(
              additionalOverrides: [
                authServiceProvider.overrideWithValue(mockAuthService),
                profileRepositoryProvider.overrideWith(
                  (ref) => mockProfileRepository,
                ),
                profileReadRepositoryProvider.overrideWith(
                  (ref) => mockProfileRepository,
                ),
                fetchUserProfileProvider(
                  testPubkeyHex,
                ).overrideWith((ref) async => null),
                userProfileReactiveProvider(
                  testPubkeyHex,
                ).overrideWith(
                  (ref) => Stream<models.UserProfile?>.value(null),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: MultiBlocProvider(
                  providers: [
                    BlocProvider<ProfileEditorBloc>.value(value: editorBloc),
                    BlocProvider<MyProfileBloc>.value(value: mockMyProfileBloc),
                  ],
                  child: const ProfileSetupScreenView(isNewUser: false),
                ),
              ),
            ),
          );
        }

        testWidgets('a seeded profile alone is not an unsaved change', (
          tester,
        ) async {
          await pumpRealBloc(tester);
          profileStates.add(MyProfileLoading(profile: cachedProfile()));
          await tester.pumpAndSettle();

          expect(editorBloc.state.hasUnsavedChanges, isFalse);
        });

        testWidgets(
          'a relay name that differs from the cache is not an unsaved change',
          (tester) async {
            await pumpRealBloc(tester);
            profileStates.add(MyProfileLoading(profile: cachedProfile()));
            await tester.pumpAndSettle();

            // Renamed on another device: the cache is stale and the relay's
            // copy refreshes the untouched field. The user has typed nothing,
            // so leaving must not claim there is anything to save.
            profileStates.add(
              MyProfileLoaded(
                profile: cachedProfile(
                  displayName: 'Relay Name',
                  eventId: freshEventId,
                ),
                isFresh: true,
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Relay Name'), findsOneWidget);
            expect(editorBloc.state.hasUnsavedChanges, isFalse);
          },
        );

        testWidgets('a fresher profile does not clear a typed edit', (
          tester,
        ) async {
          await pumpRealBloc(tester);
          profileStates.add(MyProfileLoading(profile: cachedProfile()));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField).first, 'My Own Name');
          await tester.pumpAndSettle();
          expect(editorBloc.state.hasUnsavedChanges, isTrue);

          profileStates.add(
            MyProfileLoaded(
              profile: cachedProfile(
                displayName: 'Relay Name',
                eventId: freshEventId,
              ),
              isFresh: true,
            ),
          );
          await tester.pumpAndSettle();

          expect(editorBloc.state.displayName, 'My Own Name');
          expect(editorBloc.state.hasUnsavedChanges, isTrue);
        });
      });
    });

    group('banner block', () {
      /// The colour swatches and Clear sit two sheets deep now: the banner
      /// pencil opens the source list, whose "Change color" row opens the
      /// picker.
      Future<void> openBannerColorSheet(WidgetTester tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileSetupBannerChangeColor));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'pre-filled hex banner shows color preview',
        (tester) async {
          when(() => mockEditorBloc.state).thenReturn(
            const ProfileEditorState(
              persistedBanner: '0x33ccbf',
              pendingBannerColor: Color(0xFF33CCBF),
            ),
          );

          await pumpScreen(tester);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('profile_banner_color_preview')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('profile_banner_image_preview')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'pre-filled URL banner shows image preview',
        (tester) async {
          when(() => mockEditorBloc.state).thenReturn(
            const ProfileEditorState(
              persistedBanner: 'https://cdn.example.com/banner.jpg',
            ),
          );

          await pumpScreen(tester);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('profile_banner_image_preview')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('profile_banner_color_preview')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'staged pendingBannerUrl shows image preview from that URL',
        (tester) async {
          when(() => mockEditorBloc.state).thenReturn(
            const ProfileEditorState(
              pendingBannerStatus: PendingBannerStatus.staged,
              pendingBannerUrl: 'https://cdn.example.com/uploaded.jpg',
            ),
          );

          await pumpScreen(tester);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('profile_banner_image_preview')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'staged pendingBannerColor shows color preview, no image',
        (tester) async {
          when(() => mockEditorBloc.state).thenReturn(
            const ProfileEditorState(
              pendingBannerColor: Color(0xFFFF0000),
            ),
          );

          await pumpScreen(tester);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('profile_banner_color_preview')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('profile_banner_image_preview')),
            findsNothing,
          );
        },
      );

      testWidgets('the banner sheet offers an image link', (tester) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupChangeBannerTitle), findsOneWidget);
        expect(find.text(l10n.profileSetupImagePasteLink), findsOneWidget);
        expect(find.text(l10n.profileSetupBannerChangeColor), findsOneWidget);
      });

      testWidgets('saving a pasted link stages it as the banner', (
        tester,
      ) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileSetupImagePasteLink));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'https://cdn.example.com/banner.jpg',
        );
        await tester.tap(find.text(l10n.profileSetupSaveButton).last);
        await tester.pumpAndSettle();

        final captured = verify(
          () => mockEditorBloc.add(captureAny()),
        ).captured;
        final staged = captured.whereType<ProfileBannerUrlSet>();
        expect(staged, hasLength(1));
        expect(staged.single.url, 'https://cdn.example.com/banner.jpg');
      });

      testWidgets('the link sheet opens on the persisted banner image', (
        tester,
      ) async {
        // Opening empty makes editing an existing banner a retype.
        when(() => mockEditorBloc.state).thenReturn(
          const ProfileEditorState(
            persistedBanner: 'https://cdn.example.com/banner.jpg',
          ),
        );

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileSetupImagePasteLink));
        await tester.pumpAndSettle();

        expect(
          find.text('https://cdn.example.com/banner.jpg'),
          findsOneWidget,
        );
      });

      testWidgets('the link sheet opens empty on a persisted colour', (
        tester,
      ) async {
        when(() => mockEditorBloc.state).thenReturn(
          const ProfileEditorState(
            persistedBanner: '0x33ccbf',
            pendingBannerColor: Color(0xFF33CCBF),
          ),
        );

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.profileSetupImagePasteLink));
        await tester.pumpAndSettle();

        expect(find.text('0x33ccbf'), findsNothing);
      });

      testWidgets('clearing hides a persisted banner from the preview', (
        tester,
      ) async {
        when(() => mockEditorBloc.state).thenReturn(
          const ProfileEditorState(
            persistedBanner: 'https://cdn.example.com/banner.jpg',
            bannerCleared: true,
          ),
        );

        await pumpScreen(tester);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('profile_banner_empty_preview')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('profile_banner_image_preview')),
          findsNothing,
        );
      });

      testWidgets('offers no clear row when there is no banner', (
        tester,
      ) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupBannerClearButton), findsNothing);
      });

      testWidgets('the colour row names the staged colour', (tester) async {
        when(() => mockEditorBloc.state).thenReturn(
          const ProfileEditorState(pendingBannerColor: VineTheme.accentYellow),
        );
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
        await tester.pumpAndSettle();

        // Label stays as the caption, with the chosen colour beneath it.
        expect(find.text(l10n.profileSetupBannerChangeColor), findsOneWidget);
        expect(find.text(l10n.profileSetupBannerColorYellow), findsOneWidget);
      });

      testWidgets(
        'tapping a color swatch dispatches ProfileBannerColorSelected',
        (tester) async {
          await pumpScreen(tester);
          await tester.pumpAndSettle();
          await openBannerColorSheet(tester);

          final swatch = find.byKey(
            const ValueKey('profile_banner_color_swatch_preset_0'),
          );
          await tester.ensureVisible(swatch);
          await tester.tap(swatch);
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockEditorBloc.add(
              captureAny(that: isA<ProfileBannerColorSelected>()),
            ),
          ).captured;
          expect(
            captured.whereType<ProfileBannerColorSelected>(),
            isNotEmpty,
          );
        },
      );

      testWidgets(
        'tapping Clear when a banner is staged dispatches '
        '$ProfileBannerCleared',
        (tester) async {
          when(() => mockEditorBloc.state).thenReturn(
            const ProfileEditorState(
              pendingBannerStatus: PendingBannerStatus.staged,
              pendingBannerUrl: 'https://cdn.example.com/uploaded.jpg',
            ),
          );

          await pumpScreen(tester);
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          await tester.tap(find.byTooltip(l10n.profileSetupEditBannerLabel));
          await tester.pumpAndSettle();
          final clearButton = find.text(l10n.profileSetupBannerClearButton);
          await tester.ensureVisible(clearButton);
          await tester.tap(clearButton);
          await tester.pumpAndSettle();

          verify(
            () => mockEditorBloc.add(const ProfileBannerCleared()),
          ).called(1);
        },
      );

      testWidgets(
        'Save dispatches $ProfileSaved without legacy banner field — '
        'bloc resolves it from state.effectiveBanner',
        (tester) async {
          await pumpScreen(tester);
          await tester.pumpAndSettle();

          // Provide a display name so the save proceeds.
          await tester.enterText(find.byType(TextField).first, 'Test User');
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          await tester.tap(find.text(l10n.profileSetupSaveButton));
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockEditorBloc.add(captureAny(that: isA<ProfileSaved>())),
          ).captured;
          expect(captured.whereType<ProfileSaved>(), isNotEmpty);
          expect(
            captured.whereType<ProfileSaved>().last.banner,
            isNull,
          );
        },
      );
    });
  });
}
