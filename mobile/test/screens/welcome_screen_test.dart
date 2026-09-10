// ABOUTME: Tests for WelcomeScreen
// ABOUTME: Verifies default variant, returning-user variant, button interactions,
// ABOUTME: terms notice, error display, and loading states

import 'package:db_client/db_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/invite_availability_harness.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

const _testPubkeyHex =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

final _testProfile = UserProfile(
  pubkey: _testPubkeyHex,
  displayName: 'Test User',
  picture: 'https://example.com/avatar.png',
  nip05: 'testuser@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8',
);

final _testKnownAccount = KnownAccount(
  pubkeyHex: _testPubkeyHex,
  authSource: AuthenticationSource.automatic,
  addedAt: DateTime(2024),
  lastUsedAt: DateTime(2024, 6),
);

const _testPubkeyHex2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

final _testKnownAccount2 = KnownAccount(
  pubkeyHex: _testPubkeyHex2,
  authSource: AuthenticationSource.amber,
  addedAt: DateTime(2024),
  lastUsedAt: DateTime(2024, 5),
);

void main() {
  late _MockAuthService mockAuthService;
  late _MockAppDatabase mockDb;
  late _MockUserProfilesDao mockUserProfilesDao;
  late SharedPreferences sharedPreferences;

  setUpAll(() async {
    registerFallbackValue(AuthenticationSource.none);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
    mockAuthService = _MockAuthService();
    mockDb = _MockAppDatabase();
    mockUserProfilesDao = _MockUserProfilesDao();

    when(() => mockDb.userProfilesDao).thenReturn(mockUserProfilesDao);
    when(
      () => mockUserProfilesDao.getProfile(any()),
    ).thenAnswer((_) async => null);

    // Default stubs
    when(() => mockAuthService.lastError).thenReturn(null);
    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockAuthService.getKnownAccounts()).thenAnswer((_) async => []);
    when(
      () => mockAuthService.getSessionRecoveryAnchorNpub(),
    ).thenAnswer((_) async => null);
    when(() => mockAuthService.acceptTerms()).thenAnswer((_) async {});
    when(
      () => mockAuthService.signInForAccount(any(), any()),
    ).thenAnswer((_) async {});
  });

  Widget createTestWidget({
    AuthState authState = AuthState.unauthenticated,
    String? initialSelectedPubkeyHex,
    InviteAvailabilityCubit? availabilityCubit,
  }) {
    Widget app = MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: VineTheme.theme,
      routerConfig: GoRouter(
        initialLocation: WelcomeScreen.path,
        routes: [
          GoRoute(
            path: WelcomeScreen.path,
            builder: (context, state) => WelcomeScreen(
              initialSelectedPubkeyHex: initialSelectedPubkeyHex,
            ),
            routes: [
              GoRoute(
                path: 'invite',
                builder: (context, state) =>
                    const Scaffold(body: Text('Invite Gate')),
              ),
              GoRoute(
                path: 'create-account',
                builder: (context, state) =>
                    const Scaffold(body: Text('Create Account')),
              ),
              GoRoute(
                path: 'login-options',
                builder: (context, state) =>
                    const Scaffold(body: Text('Sign in')),
              ),
            ],
          ),
          GoRoute(
            path: MinorAccountReviewScreen.welcomePath,
            builder: (context, state) =>
                const Scaffold(body: Text('Family Guide Page')),
          ),
          GoRoute(
            path: RoutePaths.accountDeletionRecovery,
            builder: (context, state) =>
                const Scaffold(body: Text('Deletion Recovery')),
          ),
        ],
      ),
    );
    if (availabilityCubit != null) {
      app = BlocProvider<InviteAvailabilityCubit>.value(
        value: availabilityCubit,
        child: app,
      );
    }
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        currentAuthStateProvider.overrideWithValue(authState),
        databaseProvider.overrideWithValue(mockDb),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: app,
    );
  }

  group(WelcomeScreen, () {
    group('default variant', () {
      // The fresh-install hero column overflows the default 800x600 test
      // surface by 13px, but only when it lays out with the wide fallback
      // font: VineTheme's GoogleFonts.inter registers its asset into the
      // process-global font collection asynchronously, so the first test in
      // an isolate to render this screen misses real Inter metrics. Under
      // randomized ordering that is whichever test the seed sorts first, so
      // every test here takes the headroom rather than the four that
      // happened to hit it. Width stays 800 so nothing re-wraps. This cannot
      // move into setUp — setSurfaceSize asserts it runs inside a test.
      Future<void> useTallSurface(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }

      testWidgets('displays $AuthHeroSection', (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthHeroSection), findsOneWidget);
      });

      testWidgets('displays create account button', (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Create a new Divine account'), findsOneWidget);
      });

      testWidgets('displays login button', (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Sign in with an existing account'), findsOneWidget);
      });

      testWidgets('primary actions carry stable test anchors', (tester) async {
        // This one wants a phone viewport rather than the headroom above.
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // The E2E suite targets these ids instead of the button copy, which
        // has changed twice since the flows were written.
        expect(
          find.bySemanticsIdentifier(SemanticIds.authCreateAccountButton),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.authSignInButton),
          findsOneWidget,
        );
      });

      testWidgets('displays terms notice with legal links', (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final richTextFinder = find.byWidgetPredicate((widget) {
          if (widget is RichText) {
            final text = widget.text.toPlainText();
            return text.contains('Terms of Service') &&
                text.contains('Privacy Policy') &&
                text.contains('Safety Standards');
          }
          return false;
        });
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets(
        'renders Greenlight label, under-16 link, and terms above the auth buttons',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await useTallSurface(tester);
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final greenlightLabel = find.text(l10n.authMinAgeNotice);
          final under16Link = find.byWidgetPredicate((widget) {
            if (widget is RichText) {
              final text = widget.text.toPlainText();
              return text.contains("Not 16 yet? That's OK. ") &&
                  text.contains('Here are your choices.');
            }
            return false;
          });
          final termsNotice = find.byWidgetPredicate((widget) {
            if (widget is RichText) {
              final text = widget.text.toPlainText();
              return text.contains('By selecting an option below') &&
                  text.contains(
                    'at least 16 years old (or have completed '
                    'Divine age authorization) and agree',
                  ) &&
                  text.contains('Terms of Service');
            }
            return false;
          });
          final createButton = find.widgetWithText(
            DivineButton,
            'Create a new Divine account',
          );
          final loginButton = find.widgetWithText(
            DivineButton,
            'Sign in with an existing account',
          );

          expect(greenlightLabel, findsOneWidget);
          expect(under16Link, findsOneWidget);
          expect(termsNotice, findsOneWidget);
          expect(createButton, findsOneWidget);
          expect(loginButton, findsOneWidget);

          final greenlightTop = tester.getTopLeft(greenlightLabel).dy;
          final under16Top = tester.getTopLeft(under16Link).dy;
          final termsTop = tester.getTopLeft(termsNotice).dy;
          final createTop = tester.getTopLeft(createButton).dy;
          final loginTop = tester.getTopLeft(loginButton).dy;

          expect(under16Top, greaterThan(greenlightTop));
          expect(termsTop, greaterThan(under16Top));
          expect(createTop, greaterThan(termsTop));
          expect(loginTop, greaterThan(createTop));
        },
      );

      testWidgets(
        'tapping create account defaults to skipping the invite gate',
        (tester) async {
          await useTallSurface(tester);
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Create a new Divine account'));
          await tester.pumpAndSettle();

          verify(() => mockAuthService.acceptTerms()).called(1);
          expect(find.text('Create Account'), findsOneWidget);
          expect(find.text('Invite Gate'), findsNothing);
        },
      );

      testWidgets(
        'tapping create account skips the invite gate while config resolves',
        (tester) async {
          await useTallSurface(tester);
          final availabilityCubit = seededInviteAvailabilityCubit(
            serverMode: null,
            hasResolved: false,
          );
          addTearDown(availabilityCubit.close);

          await tester.pumpWidget(
            createTestWidget(availabilityCubit: availabilityCubit),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Create a new Divine account'));
          await tester.pumpAndSettle();

          expect(find.text('Create Account'), findsOneWidget);
          expect(find.text('Invite Gate'), findsNothing);
        },
      );

      testWidgets(
        'tapping create account skips the invite gate when invites are disabled',
        (tester) async {
          await useTallSurface(tester);
          final availabilityCubit = seededInviteAvailabilityCubit(
            serverMode: OnboardingMode.open,
          );
          addTearDown(availabilityCubit.close);

          await tester.pumpWidget(
            createTestWidget(availabilityCubit: availabilityCubit),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Create a new Divine account'));
          await tester.pumpAndSettle();

          expect(find.text('Create Account'), findsOneWidget);
          expect(find.text('Invite Gate'), findsNothing);
        },
      );

      testWidgets('tapping login button calls acceptTerms and navigates', (
        tester,
      ) async {
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign in with an existing account'));
        await tester.pumpAndSettle();

        verify(() => mockAuthService.acceptTerms()).called(1);
        expect(find.text('Sign in'), findsOneWidget);
      });

      testWidgets(
        'tapping "Divine age authorization" navigates to the public family guide',
        (tester) async {
          await useTallSurface(tester);
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final termsRichText = find.byWidgetPredicate((widget) {
            if (widget is RichText) {
              final text = widget.text.toPlainText();
              return text.contains('Divine age authorization') &&
                  text.contains('Terms of Service');
            }
            return false;
          });
          expect(termsRichText, findsOneWidget);

          final richText = tester.widget<RichText>(termsRichText);
          final fullText = richText.text.toPlainText();
          final linkStart = fullText.indexOf('Divine age authorization');
          expect(linkStart, isNonNegative);
          final renderParagraph = tester.renderObject<RenderParagraph>(
            termsRichText,
          );
          final linkBoxes = renderParagraph.getBoxesForSelection(
            TextSelection(
              baseOffset: linkStart,
              extentOffset: linkStart + 'Divine age authorization'.length,
            ),
          );
          expect(linkBoxes, isNotEmpty);
          final linkCenter = renderParagraph.localToGlobal(
            linkBoxes.first.toRect().center,
          );
          await tester.tapAt(linkCenter);
          await tester.pumpAndSettle();

          expect(find.text('Family Guide Page'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping "Here are your choices." navigates to the public family guide',
        (tester) async {
          await useTallSurface(tester);
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final ctaRichText = find.byWidgetPredicate((widget) {
            if (widget is RichText) {
              final text = widget.text.toPlainText();
              return text.contains("Not 16 yet? That's OK. ") &&
                  text.contains('Here are your choices.');
            }
            return false;
          });
          expect(ctaRichText, findsOneWidget);

          // Tap the right edge of the RichText, where the green CTA span sits.
          final ctaRect = tester.getRect(ctaRichText);
          await tester.tapAt(Offset(ctaRect.right - 24, ctaRect.center.dy));
          await tester.pumpAndSettle();

          expect(find.text('Family Guide Page'), findsOneWidget);
        },
      );

      testWidgets('shows error when lastError is set', (tester) async {
        await useTallSurface(tester);
        when(() => mockAuthService.lastError).thenReturn('Auth failed');

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ErrorMessage), findsOneWidget);
        expect(find.text('Auth failed'), findsOneWidget);
      });

      testWidgets('does not show error when lastError is null', (tester) async {
        await useTallSurface(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ErrorMessage), findsNothing);
      });

      testWidgets('hides action buttons when auth state is checking', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(authState: AuthState.checking),
        );
        await tester.pump();

        expect(find.text('Create a new Divine account'), findsNothing);
        expect(find.text('Sign in with an existing account'), findsNothing);
      });

      testWidgets('hides action buttons when auth state is authenticating', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(authState: AuthState.authenticating),
        );
        await tester.pump();

        expect(find.text('Create a new Divine account'), findsNothing);
        expect(find.text('Sign in with an existing account'), findsNothing);
      });

      testWidgets('does not call acceptTerms when auth state is checking', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(authState: AuthState.checking),
        );
        await tester.pump();

        verifyNever(() => mockAuthService.acceptTerms());
      });
    });

    group('returning user variant', () {
      setUp(() {
        when(
          () => mockAuthService.getKnownAccounts(),
        ).thenAnswer((_) async => [_testKnownAccount]);
        when(
          () => mockUserProfilesDao.getProfile(_testPubkeyHex),
        ).thenAnswer((_) async => _testProfile);
      });

      testWidgets('shows user avatar', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('shows display name', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Test User'), findsOneWidget);
      });

      testWidgets('shows NIP-05 identifier', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('testuser@example.com'), findsOneWidget);
      });

      testWidgets('does not show $AuthHeroSection', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthHeroSection), findsNothing);
      });

      testWidgets('app bar close control announces a localized label', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.bySemanticsLabel(l10n.commonClose), findsOneWidget);
        // The divine_ui default. Reaching a user means the call site forgot
        // to pass a label, and it ships untranslated to every locale.
        expect(find.bySemanticsLabel('Leading action'), findsNothing);
      });

      testWidgets('shows explicit returning-user action labels', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Continue as Test User'), findsOneWidget);
        expect(find.text('Use another account'), findsOneWidget);
        expect(find.text('Create new account'), findsOneWidget);
        expect(find.text('Sign back in'), findsNothing);
      });

      testWidgets('returning-user action labels fit on a phone viewport', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Continue as Test User'), findsOneWidget);
        expect(find.text('Use another account'), findsOneWidget);
        expect(find.text('Create new account'), findsOneWidget);
      });

      testWidgets('shows terms notice above returning-user action buttons', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(900, 1748));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final termsNotice = find.byWidgetPredicate((widget) {
          if (widget is RichText) {
            final text = widget.text.toPlainText();
            return text.contains('By selecting an option below') &&
                text.contains(
                  'at least 16 years old (or have completed '
                  'Divine age authorization) and agree',
                ) &&
                text.contains('Terms of Service');
          }
          return false;
        });
        final continueButton = find.widgetWithText(
          DivineButton,
          'Continue as Test User',
        );
        final useAnotherButton = find.widgetWithText(
          DivineButton,
          'Use another account',
        );
        final createButton = find.widgetWithText(
          DivineButton,
          'Create new account',
        );

        expect(termsNotice, findsOneWidget);
        expect(continueButton, findsOneWidget);
        expect(useAnotherButton, findsOneWidget);
        expect(createButton, findsOneWidget);

        final termsTop = tester.getTopLeft(termsNotice).dy;
        final continueTop = tester.getTopLeft(continueButton).dy;
        final useAnotherTop = tester.getTopLeft(useAnotherButton).dy;
        final createTop = tester.getTopLeft(createButton).dy;

        expect(continueTop, greaterThan(termsTop));
        expect(useAnotherTop, greaterThan(continueTop));
        expect(createTop, greaterThan(useAnotherTop));
      });

      testWidgets(
        'shows the recovery owner banner when the selected account matches the anchor',
        (tester) async {
          final anchorNpub = NostrKeyUtils.encodePubKey(_testPubkeyHex);
          when(
            () => mockAuthService.getSessionRecoveryAnchorNpub(),
          ).thenAnswer((_) async => anchorNpub);

          final announcements = <Map<Object?, Object?>>[];
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                (Object? message) async {
                  if (message is Map) announcements.add(message);
                  return null;
                },
              );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockDecodedMessageHandler<Object?>(
                  SystemChannels.accessibility,
                  null,
                ),
          );

          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          expect(
            find.text('Your drafts and clips are saved for this account'),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIcon &&
                  widget.icon == DivineIconName.warningCircle,
            ),
            findsOneWidget,
          );

          final announceCalls = announcements.where(
            (message) => message['type'] == 'announce',
          );
          expect(announceCalls, isNotEmpty);
          expect(
            announceCalls
                .map((message) => (message['data'] as Map?)?['message'])
                .toList(),
            contains('Your drafts and clips are saved for this account'),
          );
        },
      );

      testWidgets(
        'shows the cross-account warning when selection differs from the anchor',
        (tester) async {
          final anchorNpub = NostrKeyUtils.encodePubKey(_testPubkeyHex);
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount, _testKnownAccount2]);
          when(
            () => mockAuthService.getSessionRecoveryAnchorNpub(),
          ).thenAnswer((_) async => anchorNpub);

          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            createTestWidget(initialSelectedPubkeyHex: _testPubkeyHex2),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Signing in here will hide those drafts and clips'),
            findsOneWidget,
          );
        },
      );

      testWidgets('tapping "Continue as Test User" calls signInForAccount', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue as Test User'));
        await tester.pump();

        verify(
          () => mockAuthService.signInForAccount(
            _testPubkeyHex,
            AuthenticationSource.automatic,
          ),
        ).called(1);
      });

      testWidgets('continuing a pending deletion account opens recovery', (
        tester,
      ) async {
        final seedContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
        );
        await seedContainer
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: _testPubkeyHex,
              attempt: const AccountDeletionAttempt(
                id: 'attempt-id',
                status: AccountDeletionAttemptStatus.processing,
              ),
              vanishEventId: 'vanish-event-id',
            );
        seedContainer.dispose();

        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue as Test User'));
        await tester.pumpAndSettle();

        expect(find.text('Deletion Recovery'), findsOneWidget);
        verifyNever(() => mockAuthService.signInForAccount(any(), any()));
      });

      testWidgets('navigates to login options when session is expired', (
        tester,
      ) async {
        when(
          () => mockAuthService.signInForAccount(any(), any()),
        ).thenThrow(SessionExpiredException());

        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue as Test User'));
        await tester.pumpAndSettle();

        verify(() => mockAuthService.acceptTerms()).called(1);
        expect(find.text('Sign in'), findsOneWidget);
      });

      testWidgets(
        'tapping "Create new account" defaults to skipping the invite gate',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Create new account'));
          await tester.pumpAndSettle();

          verify(() => mockAuthService.acceptTerms()).called(1);
          expect(find.text('Create Account'), findsOneWidget);
          expect(find.text('Invite Gate'), findsNothing);
        },
      );

      testWidgets('tapping login button calls acceptTerms and navigates', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Use another account'));
        await tester.pumpAndSettle();

        verify(() => mockAuthService.acceptTerms()).called(1);
        expect(find.text('Sign in'), findsOneWidget);
      });
    });
  });
}
