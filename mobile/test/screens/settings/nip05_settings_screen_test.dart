import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group(Nip05SettingsView, () {
    late _MockProfileRepository mockProfileRepository;
    late _MockBlossomUploadService mockBlossomUploadService;
    final l10n = lookupAppLocalizations(const Locale('en'));
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    UserProfile createProfile({String? nip05}) {
      return UserProfile(
        pubkey: testPubkey,
        displayName: 'Test User',
        about: 'Still making weird loops',
        picture: 'https://example.com/avatar.png',
        nip05: nip05,
        rawData: {'display_name': 'Test User', 'nip05': ?nip05},
        createdAt: DateTime(2024),
        eventId:
            'event123456789012345678901234567890123456789012345678901234567890',
      );
    }

    setUpAll(() {
      registerFallbackValue(
        UserProfile(
          pubkey: testPubkey,
          displayName: 'Fallback User',
          rawData: const {'display_name': 'Fallback User'},
          createdAt: DateTime(2024),
          eventId:
              'fallback123456789012345678901234567890123456789012345678901234',
        ),
      );
      registerFallbackValue(
        const PendingProfileSave(pubkey: testPubkey, displayName: 'fallback'),
      );
    });

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlossomUploadService = _MockBlossomUploadService();
      when(
        () => mockProfileRepository.checkUsernameAvailability(
          username: any(named: 'username'),
          currentUserPubkey: any(named: 'currentUserPubkey'),
        ),
      ).thenAnswer((_) async => const UsernameAvailable());
      when(
        () => mockProfileRepository.claimUsername(
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => const UsernameClaimSuccess());
      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject({
      required UserProfile profile,
      bool hasExistingProfile = true,
    }) {
      when(
        () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
      ).thenAnswer((_) async => profile);

      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ProfileEditorBloc(
                profileRepository: mockProfileRepository,
                blossomUploadService: mockBlossomUploadService,
                hasExistingProfile: hasExistingProfile,
                currentUserPubkey: testPubkey,
              ),
            ),
            BlocProvider(
              create: (_) => MyProfileBloc(
                profileRepository: mockProfileRepository,
                pubkey: testPubkey,
              )..add(const MyProfileLoadRequested()),
            ),
          ],
          child: const Nip05SettingsView(),
        ),
      );
    }

    testWidgets('keeps invalid username characters visible and explains them', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: createProfile()));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupUsernameHelper), findsOneWidget);

      final usernameField = find.byType(TextFormField).first;
      await tester.enterText(usernameField, 'Last_Outlaw');
      await tester.pump(const Duration(milliseconds: 600));

      final field = tester.widget<TextFormField>(usernameField);
      expect(field.controller?.text, 'last_outlaw');
      expect(find.text(l10n.profileSetupUsernameInvalidFormat), findsOneWidget);
      verifyNever(
        () => mockProfileRepository.checkUsernameAvailability(
          username: any(named: 'username'),
          currentUserPubkey: any(named: 'currentUserPubkey'),
        ),
      );
    });

    testWidgets('prefills an existing external NIP-05 value', (tester) async {
      const existingNip05 = 'alice@example.com';

      await tester.pumpWidget(
        buildSubject(profile: createProfile(nip05: existingNip05)),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05AddressLabel), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.controller?.text == existingNip05,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a confirm dialog before switching to external NIP-05', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: createProfile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05ConfirmTitle), findsOneWidget);
      expect(find.text(l10n.profileSetupNip05ConfirmBody), findsOneWidget);

      await tester.tap(find.text(l10n.profileSetupNip05ConfirmContinue));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05AddressLabel), findsOneWidget);
    });

    testWidgets('confirm dialog cancel leaves NIP-05 on divine mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: createProfile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
      await tester.pumpAndSettle();
      expect(find.text(l10n.profileSetupNip05ConfirmTitle), findsOneWidget);

      await tester.tap(find.text(l10n.profileSetupNip05ConfirmCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05ConfirmTitle), findsNothing);
      expect(find.text(l10n.profileSetupNip05AddressLabel), findsNothing);
    });

    testWidgets(
      'toggle off switches from external NIP-05 back to divine mode',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(profile: createProfile(nip05: 'alice@example.com')),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupNip05AddressLabel), findsOneWidget);

        await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupNip05ConfirmTitle), findsNothing);
        expect(find.text(l10n.profileSetupNip05AddressLabel), findsNothing);
      },
    );

    testWidgets('shows validation error for invalid external NIP-05', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: createProfile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileSetupNip05ConfirmContinue));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'not-a-handle');
      await tester.pump();

      expect(
        find.text(l10n.profileSetupExternalNip05InvalidFormat),
        findsOneWidget,
      );
    });

    testWidgets(
      'queues the NIP-05 save optimistically even when the publish fails',
      (tester) async {
        final profile = createProfile(nip05: 'alice@example.com');
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => profile);
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => profile);
        when(
          () => mockProfileRepository.enqueuePendingSave(
            any(),
            claimConfirmed: any(named: 'claimConfirmed'),
          ),
        ).thenAnswer((_) async => 'gen-test');
        when(
          () => mockProfileRepository.drivePendingSave(
            any(),
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);

        // Nip05SettingsView calls `context.pop()` on optimistic success, which
        // requires a GoRouter ancestor. Push it onto a minimal router (rather
        // than using buildSubject's bare MaterialApp) so that pop succeeds
        // instead of throwing "No GoRouter found in context".
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/nip05',
              builder: (context, state) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => ProfileEditorBloc(
                      profileRepository: mockProfileRepository,
                      blossomUploadService: mockBlossomUploadService,
                      hasExistingProfile: true,
                      currentUserPubkey: testPubkey,
                    ),
                  ),
                  BlocProvider(
                    create: (_) => MyProfileBloc(
                      profileRepository: mockProfileRepository,
                      pubkey: testPubkey,
                    )..add(const MyProfileLoadRequested()),
                  ),
                ],
                child: const Nip05SettingsView(),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        router.push('/nip05');
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).last,
          'bob@example.com',
        );
        await tester.pump();

        await tester.tap(find.text(l10n.nostrSettingsNip05SaveAction));
        await tester.pumpAndSettle();

        // A transient publish failure is retried in the background by
        // ProfileEditorBloc's optimistic save flow, so it must NOT surface
        // as a save-failure snackbar.
        expect(find.text(l10n.nostrSettingsNip05SaveFailed), findsNothing);

        final captured = verify(
          () => mockProfileRepository.enqueuePendingSave(
            captureAny(),
            claimConfirmed: captureAny(named: 'claimConfirmed'),
          ),
        ).captured;
        final payload = captured[0] as PendingProfileSave;
        expect(payload.nip05, 'bob@example.com');
      },
    );

    testWidgets(
      'sends a profile-less user to Profile Setup and reloads on return',
      (tester) async {
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => null);
        var fetchCount = 0;
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenAnswer((_) async {
          fetchCount++;
          return fetchCount == 1 ? null : createProfile();
        });
        when(
          () => mockProfileRepository.isConfirmedMissing(testPubkey),
        ).thenReturn(true);

        final router = GoRouter(
          initialLocation: '/nip05',
          routes: [
            GoRoute(
              path: '/nip05',
              builder: (context, state) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => ProfileEditorBloc(
                      profileRepository: mockProfileRepository,
                      blossomUploadService: mockBlossomUploadService,
                      hasExistingProfile: false,
                      currentUserPubkey: testPubkey,
                    ),
                  ),
                  BlocProvider(
                    create: (_) => MyProfileBloc(
                      profileRepository: mockProfileRepository,
                      pubkey: testPubkey,
                    )..add(const MyProfileLoadRequested()),
                  ),
                ],
                child: const Nip05SettingsView(),
              ),
            ),
            GoRoute(
              path: ProfileSetupScreen.setupPath,
              builder: (context, state) => TextButton(
                onPressed: context.pop,
                child: const Text('create-profile-route'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.nostrSettingsNip05CreateProfileAction),
          findsOneWidget,
        );
        expect(find.text(l10n.profileSetupEditProfileTitle), findsNothing);

        await tester.tap(find.text(l10n.nostrSettingsNip05CreateProfileAction));
        await tester.pumpAndSettle();

        expect(find.text('create-profile-route'), findsOneWidget);

        await tester.tap(find.text('create-profile-route'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupUsernameLabel), findsOneWidget);
        expect(
          find.text(l10n.nostrSettingsNip05ProfileRequired),
          findsNothing,
        );
        expect(find.text(l10n.profileRetryButton), findsNothing);
        verify(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).called(2);
      },
    );

    testWidgets(
      'shows retry UI instead of spinning forever when profile load fails',
      (tester) async {
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileRepository.isConfirmedMissing(testPubkey),
        ).thenReturn(false);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ProfileEditorBloc(
                    profileRepository: mockProfileRepository,
                    blossomUploadService: mockBlossomUploadService,
                    hasExistingProfile: true,
                    currentUserPubkey: testPubkey,
                  ),
                ),
                BlocProvider(
                  create: (_) => MyProfileBloc(
                    profileRepository: mockProfileRepository,
                    pubkey: testPubkey,
                  )..add(const MyProfileLoadRequested()),
                ),
              ],
              child: const Nip05SettingsView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.profilePleaseTryAgain), findsOneWidget);
        expect(find.text(l10n.profileRetryButton), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text(l10n.profileRetryButton));
        await tester.pumpAndSettle();

        verify(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).called(2);
      },
    );
  });
}
