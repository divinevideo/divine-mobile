// ABOUTME: Tests for KeyImportScreen including NIP-49 ncryptsec1 support
// ABOUTME: Verifies password field visibility, validation, and import delegation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthService mockAuthService;

  // A real ncryptsec1 string from the NIP-49 spec
  const ncryptsecKey =
      'ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p';
  const nsecKey =
      'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k3lvr'
      'paxge38re5qf6vm6j';

  setUp(() {
    mockAuthService = _MockAuthService();
    registerFallbackValue(AuthState.unauthenticated);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        ...getStandardTestOverrides(mockAuthService: mockAuthService),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        routerConfig: GoRouter(
          initialLocation: KeyImportScreen.path,
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Scaffold()),
            GoRoute(
              path: KeyImportScreen.path,
              builder: (_, _) => const KeyImportScreen(),
            ),
          ],
        ),
      ),
    );
  }

  group(KeyImportScreen, () {
    group('renders', () {
      testWidgets('renders $KeyImportScreen', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(KeyImportScreen), findsOneWidget);
      });

      testWidgets('password field is not visible initially', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsNothing,
        );
      });
    });

    group('ncryptsec1 detection', () {
      testWidgets('password field appears when ncryptsec1 is entered', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          ncryptsecKey,
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsOneWidget,
        );
      });

      testWidgets('password field disappears when key changes to nsec', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // First type an ncryptsec1 key
        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          ncryptsecKey,
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsOneWidget,
        );

        // Switch to a regular nsec
        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          nsecKey,
        );
        await tester.pump();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsNothing,
        );
      });
    });

    group('validation', () {
      testWidgets(
        'shows password error when ncryptsec1 submitted without password',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          await tester.enterText(
            find.widgetWithText(
              DivineAuthTextField,
              'Private key or bunker URL',
            ),
            ncryptsecKey,
          );
          await tester.pump();

          await tester.tap(find.text('Import Nostr key'));
          await tester.pump();

          expect(
            find.text('Please enter the password for this encrypted key'),
            findsOneWidget,
          );
        },
      );
    });

    group('import', () {
      testWidgets('does not render service exception text on failure', (
        tester,
      ) async {
        const serviceError =
            'Failed to import identity: PlatformException(secret details)';
        when(
          () => mockAuthService.importFromNsec(any()),
        ).thenAnswer((_) async => AuthResult.failure(serviceError));
        when(() => mockAuthService.clearError()).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          nsecKey,
        );
        await tester.tap(find.text('Import Nostr key'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.keyImportFailedToImport), findsOneWidget);
        expect(find.text(serviceError), findsNothing);
      });

      testWidgets('calls importFromNcryptsec with key and password', (
        tester,
      ) async {
        when(
          () => mockAuthService.importFromNcryptsec(any(), any()),
        ).thenAnswer((_) async => AuthResult.failure('Incorrect password'));
        when(() => mockAuthService.clearError()).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          ncryptsecKey,
        );
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          'mypassword',
        );
        await tester.pump();

        await tester.tap(find.text('Import Nostr key'));
        await tester.pumpAndSettle();

        verify(
          () => mockAuthService.importFromNcryptsec(ncryptsecKey, 'mypassword'),
        ).called(1);
      });

      testWidgets('shows a localized error for an incorrect password', (
        tester,
      ) async {
        when(
          () => mockAuthService.importFromNcryptsec(any(), any()),
        ).thenAnswer((_) async => AuthResult.incorrectPassword());
        when(() => mockAuthService.clearError()).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          ncryptsecKey,
        );
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          'wrong password',
        );
        await tester.tap(find.text('Import Nostr key'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.keyManagementKeycastWrongPassword),
          findsOneWidget,
        );
        expect(find.text('Incorrect password'), findsNothing);
        expect(find.text(l10n.keyImportFailedToImport), findsNothing);
      });

      testWidgets('does not call importFromNcryptsec for regular nsec', (
        tester,
      ) async {
        when(
          () => mockAuthService.importFromNsec(any()),
        ).thenAnswer((_) async => AuthResult.failure('Invalid nsec'));
        when(() => mockAuthService.clearError()).thenReturn(null);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(DivineAuthTextField, 'Private key or bunker URL'),
          nsecKey,
        );
        await tester.pump();

        await tester.tap(find.text('Import Nostr key'));
        await tester.pumpAndSettle();

        verifyNever(() => mockAuthService.importFromNcryptsec(any(), any()));
      });
    });
  });
}
