// ABOUTME: Widget tests for KeyManagementScreen public key and export capability UI
// ABOUTME: Verifies public key copy plus Keycast local-vs-remote signing states

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';

class _FakeKeyManagementAuthService extends Fake implements AuthService {
  _FakeKeyManagementAuthService({
    required this.currentNpub,
    required this.authenticationSource,
    required this.canExportLocalNsec,
  });

  @override
  final String currentNpub;

  @override
  final AuthenticationSource authenticationSource;

  @override
  final bool canExportLocalNsec;

  @override
  bool get isAuthenticated => true;

  @override
  AuthState get authState => AuthState.authenticated;

  @override
  Stream<AuthState> get authStateStream => const Stream<AuthState>.empty();

  @override
  String? get currentPublicKeyHex => null;

  @override
  bool get isNip07Available => false;

  @override
  Future<String?> exportNsec({String? biometricPrompt}) async => null;

  /// What [exportKeycastNsec] returns. Defaults to a refusal so a test that
  /// forgets to set it cannot accidentally assert on a fabricated key.
  ExportKeyResult exportKeycastResult = ExportKeyResult.failure(
    ExportKeyFailure.unknown,
  );

  /// Passwords handed to [exportKeycastNsec], in call order.
  final List<String> exportKeycastPasswords = <String>[];

  @override
  Future<ExportKeyResult> exportKeycastNsec(String password) async {
    exportKeycastPasswords.add(password);
    return exportKeycastResult;
  }

  int importFromNsecCallCount = 0;

  @override
  Future<AuthResult> importFromNsec(
    String nsec, {
    String? biometricPrompt,
  }) async {
    importFromNsecCallCount++;
    return const AuthResult(success: true);
  }
}

void main() {
  group(KeyManagementScreen, () {
    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

    late _FakeKeyManagementAuthService authService;

    setUp(() {
      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.importedKeys,
        canExportLocalNsec: false,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> pumpSubject(
      WidgetTester tester, {
      bool restricted = false,
    }) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const KeyManagementScreen(),
          mockAuthService: authService,
          additionalOverrides: [
            isKeyManagementRestrictedProvider.overrideWithValue(restricted),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the public key label', (tester) async {
      await pumpSubject(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.keyManagementYourPublicKeyLabel), findsOneWidget);
    });

    testWidgets('renders the user npub somewhere on the screen', (
      tester,
    ) async {
      await pumpSubject(tester);
      expect(find.text(testNpub), findsOneWidget);
    });

    testWidgets('copies npub to clipboard when copy button is tapped', (
      tester,
    ) async {
      String? clipboardPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardPayload = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await pumpSubject(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byTooltip(l10n.keyManagementCopyPublicKeyTooltip));
      await tester.pumpAndSettle();

      expect(clipboardPayload, equals(testNpub));
      expect(find.text(l10n.keyManagementPublicKeyCopied), findsOneWidget);
    });

    testWidgets(
      'shows private key copy action when Keycast account has a local nsec',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: true,
        );

        await pumpSubject(tester);

        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(
            SemanticIds.keyManagementCopyNsecButton,
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.keyManagementKeycastRemoteSigning,
            skipOffstage: false,
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'offers the copy action for an RPC-only Keycast account, explained as '
      'service-held',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: false,
        );

        await pumpSubject(tester);

        // Same label as the local path — the key arrives from Keycast rather
        // than off the device, which is what the explanation above it says.
        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.keyManagementKeycastRemoteSigning,
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      },
    );

    /// Installs a platform clipboard, returning the list of values it kept.
    ///
    /// When [accepts] is false the write is answered with success and dropped —
    /// what a device or enterprise policy that blocks the clipboard looks like
    /// to Flutter, since neither engine implementation reports a failed write.
    List<String> mockClipboard({required bool accepts}) {
      final kept = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            switch (call.method) {
              case 'Clipboard.setData':
                final text = (call.arguments as Map)['text'] as String;
                if (accepts) kept.add(text);
                return null;
              case 'Clipboard.getData':
                return kept.isEmpty ? null : {'text': kept.last};
            }
            return null;
          });
      return kept;
    }

    /// Pump an RPC-only Keycast account on a surface tall enough for the card's
    /// button to be on-stage, then open the password sheet.
    Future<AppLocalizations> openPasswordSheet(WidgetTester tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      // The screen is a long ListView; on the default 800x600 the button
      // renders offstage and cannot be tapped.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpSubject(tester);

      await tester.ensureVisible(find.text(l10n.keyManagementCopyNsec));
      await tester.tap(find.text(l10n.keyManagementCopyNsec));
      await tester.pumpAndSettle();

      return l10n;
    }

    testWidgets(
      'asks for the account password before fetching a Keycast-held key',
      (tester) async {
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: false,
        );

        final l10n = await openPasswordSheet(tester);

        expect(find.text(l10n.keyManagementKeycastPasswordPrompt), findsOne);
        expect(find.text(l10n.authPasswordLabel), findsOne);
        // Confirming copies, so the button says so.
        expect(find.text(l10n.keyManagementKeycastCopyKey), findsOne);
        // The warning stands ahead of the copy, as it does on the local path.
        expect(find.text(l10n.keyManagementNeverShare), findsOne);
        // Nothing is fetched until the user confirms.
        expect(authService.exportKeycastPasswords, isEmpty);
      },
    );

    testWidgets('copies the fetched key and closes without ever showing it', (
      tester,
    ) async {
      const fetchedNsec =
          'nsec1testkeymaterialthatisnotarealkey00000000000000000000000000';
      final copied = mockClipboard(accepts: true);

      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.divineOAuth,
        canExportLocalNsec: false,
      )..exportKeycastResult = ExportKeyResult.success(fetchedNsec);

      final l10n = await openPasswordSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(authService.exportKeycastPasswords, equals(['hunter2']));
      expect(copied, equals([fetchedNsec]));

      // The sheet closed itself, and the confirmation outlived it — the
      // snackbar belongs to the app's messenger, not the sheet's subtree.
      expect(find.text(l10n.keyManagementKeycastPasswordPrompt), findsNothing);
      expect(find.byType(DivineAuthTextField), findsNothing);
      expect(find.text(l10n.keyManagementExportSuccess), findsOne);

      // The regression guard for the removed reveal step: `find.text` matches
      // an EditableText by its controller's contents whether or not the field
      // obscures them, so a reinstated read-only key field fails here even
      // while hidden.
      expect(find.text(fetchedNsec, skipOffstage: false), findsNothing);
      expect(
        find.textContaining('testkeymaterial', skipOffstage: false),
        findsNothing,
      );
      expect(find.text(l10n.keyManagementKeycastCopyBlocked), findsNothing);
    });

    // Neither platform reports a refused clipboard write — Android's
    // setPrimaryClip returns void, iOS assigns pasteboard.string, and the
    // engine answers success either way. Without reading the value back the
    // user is told they have a backup of the one thing they cannot re-derive.
    testWidgets('does not claim a copy the device refused', (tester) async {
      const fetchedNsec =
          'nsec1testkeymaterialthatisnotarealkey00000000000000000000000000';
      final copied = mockClipboard(accepts: false);

      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.divineOAuth,
        canExportLocalNsec: false,
      )..exportKeycastResult = ExportKeyResult.success(fetchedNsec);

      final l10n = await openPasswordSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(copied, isEmpty, reason: 'the clipboard refused the write');
      expect(find.text(l10n.keyManagementExportSuccess), findsNothing);
      expect(find.text(l10n.keyManagementKeycastCopyBlocked), findsOne);

      // Still closes, and still never renders the key.
      expect(find.text(l10n.keyManagementKeycastPasswordPrompt), findsNothing);
      expect(find.text(fetchedNsec, skipOffstage: false), findsNothing);
    });

    testWidgets('lifts the sheet clear of the keyboard', (tester) async {
      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.divineOAuth,
        canExportLocalNsec: false,
      );

      final l10n = await openPasswordSheet(tester);

      // Raise a keyboard the size of the one in the report: without the sheet
      // reacting to viewInsets it sat entirely underneath, so the field and both
      // actions were unreachable and typing was blind.
      const keyboardHeight = 900.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final visibleBottom = tester.view.physicalSize.height - keyboardHeight;
      final mustStayVisible = {
        'password field': find.byType(DivineAuthTextField),
        'copy action': find.text(l10n.keyManagementKeycastCopyKey),
        'cancel action': find.text(l10n.commonCancel),
      };
      for (final entry in mustStayVisible.entries) {
        expect(entry.value, findsOne);
        expect(
          tester.getRect(entry.value).bottom,
          lessThanOrEqualTo(visibleBottom),
          reason: '${entry.key} must stay above the keyboard',
        );
      }
    });

    testWidgets('keeps the sheet open on a wrong password', (tester) async {
      authService =
          _FakeKeyManagementAuthService(
              currentNpub: testNpub,
              authenticationSource: AuthenticationSource.divineOAuth,
              canExportLocalNsec: false,
            )
            ..exportKeycastResult = ExportKeyResult.failure(
              ExportKeyFailure.wrongPassword,
            );

      final l10n = await openPasswordSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.keyManagementKeycastWrongPassword), findsOne);
      // Still open, so the retry costs one keystroke rather than a reopen.
      expect(find.text(l10n.keyManagementKeycastPasswordPrompt), findsOne);
    });

    // Keycast does not rate-limit export-key, so the sheet is the only thing
    // standing between a borrowed unlocked phone and an unlimited guessing
    // loop that pays out the nsec.
    testWidgets('stops taking passwords after too many wrong ones', (
      tester,
    ) async {
      authService =
          _FakeKeyManagementAuthService(
              currentNpub: testNpub,
              authenticationSource: AuthenticationSource.divineOAuth,
              canExportLocalNsec: false,
            )
            ..exportKeycastResult = ExportKeyResult.failure(
              ExportKeyFailure.wrongPassword,
            );

      final l10n = await openPasswordSheet(tester);

      for (var attempt = 1; attempt <= 5; attempt++) {
        await tester.enterText(find.byType(TextField).last, 'guess$attempt');
        await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
        await tester.pumpAndSettle();
      }

      expect(authService.exportKeycastPasswords, hasLength(5));
      expect(find.text(l10n.keyManagementKeycastTooManyAttempts), findsOne);

      // A sixth guess must not reach the server, and editing the field must
      // not clear the lockout the way it clears a plain wrong-password error.
      await tester.enterText(find.byType(TextField).last, 'guess6');
      await tester.pumpAndSettle();
      expect(find.text(l10n.keyManagementKeycastTooManyAttempts), findsOne);

      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();
      expect(authService.exportKeycastPasswords, hasLength(5));
    });

    // The server's prose is English, untranslated, and for a transport failure
    // it is the raw exception — none of it belongs on screen.
    testWidgets('reports a transport failure in localized copy', (
      tester,
    ) async {
      authService =
          _FakeKeyManagementAuthService(
              currentNpub: testNpub,
              authenticationSource: AuthenticationSource.divineOAuth,
              canExportLocalNsec: false,
            )
            ..exportKeycastResult = ExportKeyResult.failure(
              ExportKeyFailure.network,
              message: 'Network error: ClientException: Connection reset',
            );

      final l10n = await openPasswordSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.keyManagementKeycastGenericFailure), findsOne);
      expect(find.textContaining('ClientException'), findsNothing);
    });

    testWidgets('reports a refusal that a retry cannot clear', (tester) async {
      authService =
          _FakeKeyManagementAuthService(
              currentNpub: testNpub,
              authenticationSource: AuthenticationSource.divineOAuth,
              canExportLocalNsec: false,
            )
            ..exportKeycastResult = ExportKeyResult.failure(
              ExportKeyFailure.needsSignIn,
            );

      final l10n = await openPasswordSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.keyManagementKeycastSignInAgain), findsOne);
      expect(find.text(l10n.keyManagementKeycastPasswordPrompt), findsNothing);
    });

    // The login service answered, and its answer was that there is nothing to
    // hand over. Reporting that as a connection problem invites a retry that
    // can never succeed.
    testWidgets('does not report a missing key as an unreachable service', (
      tester,
    ) async {
      authService =
          _FakeKeyManagementAuthService(
              currentNpub: testNpub,
              authenticationSource: AuthenticationSource.divineOAuth,
              canExportLocalNsec: false,
            )
            ..exportKeycastResult = ExportKeyResult.failure(
              ExportKeyFailure.noKey,
              message: 'No account found with this email.',
            );

      final l10n = await openPasswordSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.keyManagementKeycastNoKey), findsOne);
      expect(
        find.textContaining(l10n.keyManagementKeycastGenericFailure),
        findsNothing,
      );
      expect(find.textContaining('No account found'), findsNothing);
    });

    testWidgets('does not fetch when the password field is empty', (
      tester,
    ) async {
      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.divineOAuth,
        canExportLocalNsec: false,
      );

      final l10n = await openPasswordSheet(tester);

      await tester.tap(find.text(l10n.keyManagementKeycastCopyKey));
      await tester.pumpAndSettle();

      expect(authService.exportKeycastPasswords, isEmpty);
      expect(find.text(l10n.authPasswordRequired), findsOne);
      expect(find.text(l10n.keyManagementKeycastPasswordPrompt), findsOne);
    });

    testWidgets('hides nsec export and key import for a protected minor', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      // Local, exportable key: without the gate the copy-nsec action would
      // show, so this proves the gate — not canExportLocalNsec — hides it.
      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.divineOAuth,
        canExportLocalNsec: true,
      );

      await pumpSubject(tester, restricted: true);

      expect(find.text(l10n.keyManagementRestrictedTitle), findsOneWidget);
      expect(find.text(l10n.keyManagementRestrictedBody), findsOneWidget);

      expect(
        find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(l10n.keyManagementBackupTitle, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(l10n.keyManagementImportButton, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(l10n.keyManagementImportTitle, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets(
      'hides the Keycast key export for a protected minor with an RPC-only '
      'account',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        // RPC-only Keycast key: without the gate this is exactly the account
        // that renders the export card, so this proves the gate removes it.
        // Keycast refuses a verified_minor export server-side as well, so this
        // is the affordance being removed rather than the only thing stopping
        // it.
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.divineOAuth,
          canExportLocalNsec: false,
        );

        await pumpSubject(tester, restricted: true);

        expect(find.text(l10n.keyManagementRestrictedTitle), findsOneWidget);
        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text(
            l10n.keyManagementKeycastRemoteSigning,
            skipOffstage: false,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('shows nsec export and key import for a normal account', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      authService = _FakeKeyManagementAuthService(
        currentNpub: testNpub,
        authenticationSource: AuthenticationSource.divineOAuth,
        canExportLocalNsec: true,
      );

      await pumpSubject(tester);

      expect(
        find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(l10n.keyManagementImportButton, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text(l10n.keyManagementRestrictedTitle), findsNothing);
    });

    testWidgets(
      'does not import the key when the gate flips to restricted while the '
      'confirmation dialog is open',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final restrictedFlip = StateProvider<bool>((ref) => false);
        authService = _FakeKeyManagementAuthService(
          currentNpub: testNpub,
          authenticationSource: AuthenticationSource.importedKeys,
          canExportLocalNsec: true,
        );

        // Tall surface so the import button is fully hittable (the screen is a
        // long ListView; on the default 800x600 it sits at the viewport edge).
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The import-confirm dialog pops via go_router's context.pop, so the
        // screen must be hosted inside a GoRouter, not a plain MaterialApp.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const KeyManagementScreen(),
            ),
          ],
        );
        await tester.pumpWidget(
          testProviderScope(
            mockAuthService: authService,
            additionalOverrides: [
              isKeyManagementRestrictedProvider.overrideWith(
                (ref) => ref.watch(restrictedFlip),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
              theme: ThemeData.dark(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start the import: enter an nsec and open the confirmation dialog.
        await tester.enterText(find.byType(TextField), 'nsec1${'0' * 58}');
        await tester.ensureVisible(find.text(l10n.keyManagementImportButton));
        await tester.tap(find.text(l10n.keyManagementImportButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.keyManagementConfirmImportTitle), findsOneWidget);

        // Gate flips to restricted while the dialog is still open.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(KeyManagementScreen)),
        );
        container.read(restrictedFlip.notifier).state = true;
        await tester.pump();

        // Confirm the already-open dialog; the raw-key call must be gated.
        await tester.tap(find.text(l10n.keyManagementImportConfirm));
        await tester.pumpAndSettle();

        expect(authService.importFromNsecCallCount, isZero);
      },
    );
  });
}
