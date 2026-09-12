import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_bridge.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  group('NostrAppSandboxScreen', () {
    WebViewPlatform? originalWebViewPlatform;

    setUp(() {
      originalWebViewPlatform = WebViewPlatform.instance;
    });

    tearDown(() {
      // WebViewPlatform's setter rejects null, so only restore a non-null
      // original (the local promotes inside the guard, no `!` needed).
      final original = originalWebViewPlatform;
      if (original != null) {
        WebViewPlatform.instance = original;
      }
    });

    testWidgets(
      'does not call setBackgroundColor on macOS WebView initialization',
      (tester) async {
        WebViewPlatform.instance = _ThrowOnBackgroundColorWebViewPlatform();
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('back button uses browser history before leaving the app', (
      tester,
    ) async {
      final platform = _HistoryAwareWebViewPlatform(canGoBackInitially: true);
      WebViewPlatform.instance = platform;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DivineAppBarIconButton));
      await tester.pump();

      expect(platform.controller.goBackCallCount, 1);
    });

    testWidgets('bootstraps the initial Android page through injected HTML', (
      tester,
    ) async {
      final platform = _BootstrapAwareWebViewPlatform();
      WebViewPlatform.instance = platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final bootstrapClient = MockClient(
        (_) async => http.Response(
          '<!doctype html><html><head><script src="/app.js"></script></head><body></body></html>',
          200,
          request: http.Request('GET', Uri.parse(_fixtureApp().launchUrl)),
          headers: const {'content-type': 'text/html'},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            bootstrapHttpClientOverride: bootstrapClient,
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;

      expect(platform.controller.loadRequestCallCount, 0);
      expect(platform.controller.loadedHtml, hasLength(1));
    });

    testWidgets(
      'includes the Divine bridge script in the initial Android bootstrap HTML',
      (tester) async {
        final platform = _BootstrapAwareWebViewPlatform();
        WebViewPlatform.instance = platform;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final bootstrapClient = MockClient(
          (_) async => http.Response(
            '<!doctype html><html><head><script src="/app.js"></script></head><body></body></html>',
            200,
            request: http.Request('GET', Uri.parse(_fixtureApp().launchUrl)),
            headers: const {'content-type': 'text/html'},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              bootstrapHttpClientOverride: bootstrapClient,
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(platform.controller.loadedHtml, hasLength(1));
        expect(
          platform.controller.loadedHtml.single,
          contains('window.__divineNostrBridgeInstalled'),
        );
      },
    );

    testWidgets(
      'bootstraps Android HTML app shells even when the route returns 404',
      (tester) async {
        final platform = _BootstrapAwareWebViewPlatform();
        WebViewPlatform.instance = platform;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final bootstrapClient = MockClient(
          (_) async => http.Response(
            '<!doctype html><html><head></head><body>App shell</body></html>',
            404,
            request: http.Request(
              'GET',
              Uri.parse('https://badges.divine.video/me'),
            ),
            headers: const {'content-type': 'text/html; charset=utf-8'},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureBadgesApp(),
              bootstrapHttpClientOverride: bootstrapClient,
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;

        expect(platform.controller.loadRequestCallCount, 0);
        expect(platform.controller.loadedHtml, hasLength(1));
        expect(
          platform.controller.loadedHtml.single,
          contains('window.__divineNostrBridgeInstalled'),
        );
      },
    );

    testWidgets(
      'shows a loading state before the integration finishes booting',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.appsSandboxLoadingTitle), findsOneWidget);
        expect(find.text(l10n.appsSandboxLoadingSubtitle), findsOneWidget);
      },
    );

    testWidgets('blocks off-origin navigation for safety', (tester) async {
      void Function(Uri uri)? navigationHandler;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            onNavigationHandlerReady: (handler) => navigationHandler = handler,
          ),
        ),
      );

      navigationHandler!(Uri.parse('https://evil.example/phish'));
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.appsSandboxBlockedTitle), findsOneWidget);
      expect(
        find.textContaining(l10n.appsSandboxBlockedSubtitle('').trim()),
        findsOneWidget,
      );
    });

    testWidgets(
      'allows navigation-only origins without showing the safety block',
      (tester) async {
        void Function(Uri uri)? navigationHandler;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureBadgesApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
              onNavigationHandlerReady: (handler) =>
                  navigationHandler = handler,
            ),
          ),
        );

        navigationHandler!(
          Uri.parse('https://login.divine.video/api/oauth/authorize'),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.appsSandboxBlockedTitle), findsNothing);
      },
    );

    testWidgets('handles bridge messages and emits JavaScript responses', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      final grantStore = NostrAppGrantStore(
        sharedPreferences: sharedPreferences,
      );
      final bridgeService = NostrAppBridgeService(
        authProvider: _FakeAuthProvider(),
        policy: NostrAppBridgePolicy(
          grantStore: grantStore,
          currentUserPubkey: 'f' * 64,
        ),
        signerFactory: _FakeNostrSigner.new,
      );

      Future<void> Function(String message)? bridgeHandler;
      final executedScripts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            bridgeServiceOverride: bridgeService,
            javaScriptRunnerOverride: (script) async {
              executedScripts.add(script);
            },
            onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
            bridgeNonceOverride: 'test-nonce',
          ),
        ),
      );

      await bridgeHandler!(
        jsonEncode({
          'id': 'req-1',
          'method': 'getPublicKey',
          'args': <String, dynamic>{},
          'nonce': 'test-nonce',
        }),
      );
      await tester.pump();

      expect(executedScripts, hasLength(1));
      expect(executedScripts.single, contains('req-1'));
      expect(executedScripts.single, contains('f' * 64));
    });

    testWidgets('rejects bridge messages with no nonce as unauthorized', (
      tester,
    ) async {
      Future<void> Function(String message)? bridgeHandler;
      final executedScripts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            javaScriptRunnerOverride: (script) async {
              executedScripts.add(script);
            },
            onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
            bridgeNonceOverride: 'expected-nonce',
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );

      await bridgeHandler!(
        jsonEncode({
          'id': 'subframe-1',
          'method': 'signEvent',
          'args': <String, dynamic>{
            'event': {'kind': 1},
          },
          // Note: no 'nonce' field — simulates an iframe calling
          // divineSandboxBridge.postMessage directly without the
          // main-frame bootstrap context.
        }),
      );
      await tester.pump();

      expect(executedScripts, hasLength(1));
      expect(executedScripts.single, contains('subframe-1'));
      expect(executedScripts.single, contains('subframe_or_unauthorized'));
      expect(
        executedScripts.single,
        isNot(contains('"success":true')),
      );
    });

    testWidgets('keeps static bridge request errors but hides exception text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      Future<void> Function(String message)? bridgeHandler;
      final executedScripts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrAppSandboxScreen(
            app: _fixtureApp(),
            sandboxBuilder: (_) => const SizedBox.shrink(),
            bridgeServiceOverride: _ThrowingBridgeService(sharedPreferences),
            javaScriptRunnerOverride: (script) async {
              executedScripts.add(script);
            },
            onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
            bridgeNonceOverride: 'test-nonce',
            currentUserPubkeyOverride: 'f' * 64,
          ),
        ),
      );

      await bridgeHandler!(
        jsonEncode({
          'id': 'missing-method',
          'args': <String, dynamic>{},
          'nonce': 'test-nonce',
        }),
      );
      await bridgeHandler!(
        jsonEncode({
          'id': 'service-error',
          'method': 'getPublicKey',
          'args': <String, dynamic>{},
          'nonce': 'test-nonce',
        }),
      );
      await bridgeHandler!('{bad json');
      await tester.pump();

      expect(executedScripts, hasLength(3));
      expect(executedScripts[0], contains('missing-method'));
      expect(executedScripts[0], contains('Bridge method is required'));

      expect(executedScripts[1], contains('service-error'));
      expect(executedScripts[1], contains('invalid_request'));
      expect(executedScripts[1], isNot(contains('secret internal failure')));
      expect(executedScripts[1], isNot(contains('"message"')));

      expect(executedScripts[2], contains('unknown'));
      expect(executedScripts[2], contains('invalid_request'));
      expect(executedScripts[2], isNot(contains('FormatException')));
      expect(executedScripts[2], isNot(contains('"message"')));
    });

    testWidgets(
      'rejects bridge messages with a mismatched nonce as unauthorized',
      (tester) async {
        Future<void> Function(String message)? bridgeHandler;
        final executedScripts = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
              javaScriptRunnerOverride: (script) async {
                executedScripts.add(script);
              },
              onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
              bridgeNonceOverride: 'expected-nonce',
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );

        await bridgeHandler!(
          jsonEncode({
            'id': 'subframe-2',
            'method': 'getPublicKey',
            'args': <String, dynamic>{},
            'nonce': 'attacker-guessed-nonce',
          }),
        );
        await tester.pump();

        expect(executedScripts, hasLength(1));
        expect(executedScripts.single, contains('subframe-2'));
        expect(executedScripts.single, contains('subframe_or_unauthorized'));
      },
    );

    testWidgets(
      'rejects nip44.decrypt bridge messages with a mismatched nonce as unauthorized',
      (tester) async {
        Future<void> Function(String message)? bridgeHandler;
        final executedScripts = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
              javaScriptRunnerOverride: (script) async {
                executedScripts.add(script);
              },
              onBridgeMessageHandlerReady: (handler) => bridgeHandler = handler,
              bridgeNonceOverride: 'expected-nonce',
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );

        await bridgeHandler!(
          jsonEncode({
            'id': 'subframe-3',
            'method': 'nip44.decrypt',
            'args': <String, dynamic>{
              'pubkey': 'f' * 64,
              'ciphertext': 'ciphertext',
            },
            'nonce': 'attacker-guessed-nonce',
          }),
        );
        await tester.pump();

        expect(executedScripts, hasLength(1));
        expect(executedScripts.single, contains('subframe-3'));
        expect(executedScripts.single, contains('subframe_or_unauthorized'));
      },
    );

    group('platform frame attestation', () {
      void Function(dynamic event)? attestedEventHandler;
      List<String> capturedScripts = <String>[];

      setUp(() {
        attestedEventHandler = null;
        capturedScripts = <String>[];
      });

      Future<void> pumpSandbox(WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NostrAppSandboxScreen(
              app: _fixtureApp(),
              sandboxBuilder: (_) => const SizedBox.shrink(),
              javaScriptRunnerOverride: (script) async {
                capturedScripts.add(script);
              },
              onAttestedEventHandlerReady: (handler) {
                attestedEventHandler = handler;
              },
              bridgeNonceOverride: 'test-nonce',
              currentUserPubkeyOverride: 'f' * 64,
            ),
          ),
        );
      }

      testWidgets('rejects non-main-frame events with subframe_rejected', (
        tester,
      ) async {
        await pumpSandbox(tester);

        attestedEventHandler!({
          'message': jsonEncode({
            'id': 'frame-1',
            'method': 'getPublicKey',
            'args': <String, dynamic>{},
            'nonce': 'test-nonce',
          }),
          'isMainFrame': false,
        });
        await tester.pump();

        expect(capturedScripts, hasLength(1));
        expect(capturedScripts.single, contains('frame-1'));
        expect(capturedScripts.single, contains('subframe_rejected'));
        expect(capturedScripts.single, isNot(contains('"success":true')));
      });

      testWidgets(
        'rejects non-main-frame events even when nonce is valid',
        (tester) async {
          await pumpSandbox(tester);

          attestedEventHandler!({
            'message': jsonEncode({
              'id': 'frame-2',
              'method': 'signEvent',
              'args': <String, dynamic>{
                'event': {'kind': 1},
              },
              'nonce': 'test-nonce',
            }),
            'isMainFrame': false,
          });
          await tester.pump();

          expect(capturedScripts.single, contains('subframe_rejected'));
          expect(capturedScripts.single, isNot(contains('"success":true')));
        },
      );

      testWidgets(
        'forwards main-frame events to _handleBridgeMessage',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final sharedPreferences = await SharedPreferences.getInstance();
          final grantStore = NostrAppGrantStore(
            sharedPreferences: sharedPreferences,
          );
          final bridgeService = NostrAppBridgeService(
            authProvider: _FakeAuthProvider(),
            policy: NostrAppBridgePolicy(
              grantStore: grantStore,
              currentUserPubkey: 'f' * 64,
            ),
            signerFactory: _FakeNostrSigner.new,
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: NostrAppSandboxScreen(
                app: _fixtureApp(),
                sandboxBuilder: (_) => const SizedBox.shrink(),
                bridgeServiceOverride: bridgeService,
                javaScriptRunnerOverride: (script) async {
                  capturedScripts.add(script);
                },
                onAttestedEventHandlerReady: (handler) {
                  attestedEventHandler = handler;
                },
                bridgeNonceOverride: 'test-nonce',
                currentUserPubkeyOverride: 'f' * 64,
              ),
            ),
          );

          attestedEventHandler!({
            'message': jsonEncode({
              'id': 'frame-3',
              'method': 'getPublicKey',
              'args': <String, dynamic>{},
              'nonce': 'test-nonce',
            }),
            'isMainFrame': true,
          });
          await tester.pump();

          expect(capturedScripts, hasLength(1));
          expect(capturedScripts.single, contains('frame-3'));
          // getPublicKey succeeds — nonce was valid and main-frame was true
          expect(capturedScripts.single, contains('"success":true'));
          expect(capturedScripts.single, contains('f' * 64));
        },
      );

      testWidgets(
        'main-frame events with wrong nonce still hit the nonce gate',
        (tester) async {
          await pumpSandbox(tester);

          attestedEventHandler!({
            'message': jsonEncode({
              'id': 'frame-4',
              'method': 'getPublicKey',
              'args': <String, dynamic>{},
              'nonce': 'attacker-guessed-nonce',
            }),
            'isMainFrame': true,
          });
          await tester.pump();

          expect(capturedScripts.single, contains('frame-4'));
          expect(capturedScripts.single, contains('subframe_or_unauthorized'));
        },
      );

      testWidgets(
        'non-main-frame event with unparseable message emits subframe_rejected with unknown id',
        (tester) async {
          await pumpSandbox(tester);

          attestedEventHandler!({
            'message': 'not-valid-json',
            'isMainFrame': false,
          });
          await tester.pump();

          expect(capturedScripts.single, contains('unknown'));
          expect(capturedScripts.single, contains('subframe_rejected'));
        },
      );
    });

    group('bridge bootstrap script', () {
      test('includes eager pubkey when provided', () {
        final script = buildBridgeBootstrapScript(
          nonce: 'n',
          pubkey: 'abc123',
        );
        expect(script, contains("_pubkey: 'abc123'"));
      });

      test('sets pubkey to null when not provided', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains("_pubkey: '' || null"));
      });

      test('includes provider metadata', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains("name: 'Divine'"));
        expect(script, contains("supports: ['nip44']"));
      });

      test('advertises only capabilities the bridge actually exposes', () {
        // nip04 is intentionally not advertised: the bridge exposes no
        // window.nostr.nip04 object and the host rejects nip04 methods, so
        // claiming support would mislead feature-detecting apps.
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, isNot(contains('nip04')));
      });

      test('dispatches nostr:ready event', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(
          script,
          contains("window.dispatchEvent(new Event('nostr:ready'))"),
        );
      });

      test('dispatches nlAuth event for nostr-login compat', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(
          script,
          contains("document.dispatchEvent(new CustomEvent('nlAuth'"),
        );
      });

      test('injects auto-login script with pubkey substituted', () {
        final script = buildBridgeBootstrapScript(
          nonce: 'n',
          pubkey: 'deadbeef',
          autoLoginScript: "localStorage.setItem('pubkey', '{{PUBKEY}}');",
        );
        expect(script, contains("localStorage.setItem('pubkey', 'deadbeef')"));
        expect(script, isNot(contains('{{PUBKEY}}')));
      });

      test('skips auto-login when script is null', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: 'abc');
        expect(script, isNot(contains('localStorage.setItem')));
      });

      test('escapes single quotes in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: "a'b");
        expect(script, contains(r"_pubkey: 'a\'b'"));
      });

      test('escapes backslashes in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: r'a\b');
        expect(script, contains(r"_pubkey: 'a\\b'"));
      });

      test('escapes backticks in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: 'a`b');
        expect(script, contains(r"_pubkey: 'a\`b'"));
      });

      test('escapes newlines in pubkey', () {
        final script = buildBridgeBootstrapScript(nonce: 'n', pubkey: 'a\nb');
        expect(script, contains(r"_pubkey: 'a\nb'"));
      });

      test('refuses to install in non-main frames', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains('window.top !== window.self'));
      });

      test('embeds the per-mount nonce in the bootstrap closure', () {
        final script = buildBridgeBootstrapScript(nonce: 'NONCE-XYZ');
        expect(
          script,
          contains("const __divineBridgeNonce = 'NONCE-XYZ';"),
        );
      });

      test('includes the nonce on every outgoing bridge request', () {
        final script = buildBridgeBootstrapScript(nonce: 'n');
        expect(script, contains('nonce: __divineBridgeNonce'));
      });

      test('escapes single quotes in the nonce', () {
        final script = buildBridgeBootstrapScript(nonce: "a'b");
        expect(
          script,
          contains(r"const __divineBridgeNonce = 'a\'b';"),
        );
      });
    });

    group('injectBridgeBootstrapIntoHtml', () {
      test('inserts bridge after head tag', () {
        final html = injectBridgeBootstrapIntoHtml(
          '<html><head></head><body></body></html>',
          nonce: 'n',
          pubkey: 'abc',
        );
        expect(html, contains('<!-- divine-nostr-bridge -->'));
        expect(html, contains('__divineNostrBridgeInstalled'));
        expect(html, contains("_pubkey: 'abc'"));
      });

      test('includes auto-login in injected HTML', () {
        final html = injectBridgeBootstrapIntoHtml(
          '<html><head></head><body></body></html>',
          nonce: 'n',
          pubkey: 'abc',
          autoLoginScript: "localStorage.setItem('loginType', 'extension');",
        );
        expect(
          html,
          contains("localStorage.setItem('loginType', 'extension')"),
        );
      });

      test('forwards the nonce into the embedded bootstrap script', () {
        final html = injectBridgeBootstrapIntoHtml(
          '<html><head></head><body></body></html>',
          nonce: 'NONCE-XYZ',
          pubkey: 'abc',
        );
        expect(
          html,
          contains("const __divineBridgeNonce = 'NONCE-XYZ';"),
        );
      });
    });

    group('webMessageAllowedOriginRules', () {
      test('normalises allowed origins to scheme://host[:port] rules', () {
        expect(
          webMessageAllowedOriginRules(const [
            'https://primal.net',
            'https://app.example.com:8080',
          ]),
          equals(['https://primal.net', 'https://app.example.com:8080']),
        );
      });

      test('strips paths and trailing slashes to the bare origin', () {
        expect(
          webMessageAllowedOriginRules(const ['https://primal.net/app/']),
          equals(['https://primal.net']),
        );
      });

      test('drops entries that cannot form an origin', () {
        expect(
          webMessageAllowedOriginRules(const [
            'https://primal.net',
            'nostrsigner:', // non-http(s) scheme — Uri.origin would throw
            'not a uri at all',
            '', // empty
          ]),
          equals(['https://primal.net']),
        );
      });

      test('drops ws/wss entries without throwing (Uri.origin is http(s) '
          'only)', () {
        // wss:// is valid in remote-sourced allowedOrigins (relay URLs) and
        // passes a naive scheme check, but Uri.origin throws a StateError for
        // any non-http(s) scheme. The rule set must filter these out rather
        // than let the error escape the unawaited attestation chain.
        expect(
          webMessageAllowedOriginRules(const [
            'https://primal.net',
            'wss://relay.example.com',
            'ws://relay.example.com',
          ]),
          equals(['https://primal.net']),
        );
      });

      test('returns empty when no origin can be formed', () {
        expect(
          webMessageAllowedOriginRules(const ['nostrsigner:', 'file:///x']),
          isEmpty,
        );
      });
    });
  });

  group('sandboxAndroidFileSelector', () {
    late _MockImagePicker picker;

    setUp(() {
      picker = _MockImagePicker();
    });

    FileSelectorParams params({
      List<String> acceptTypes = const ['image/*'],
      bool isCaptureEnabled = false,
      FileSelectorMode mode = FileSelectorMode.open,
    }) {
      return FileSelectorParams(
        isCaptureEnabled: isCaptureEnabled,
        acceptTypes: acceptTypes,
        mode: mode,
      );
    }

    Future<File> passthroughStripper(File imageFile) async => imageFile;

    test('returns a file:// URI picked from the gallery', () async {
      when(
        () => picker.pickImage(source: ImageSource.gallery),
      ).thenAnswer((_) async => XFile('/tmp/badge.png'));

      final result = await sandboxAndroidFileSelector(
        params(),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, equals(['file:///tmp/badge.png']));
    });

    test('strips image metadata before returning the file URI', () async {
      final strippedPaths = <String>[];
      when(
        () => picker.pickImage(source: ImageSource.gallery),
      ).thenAnswer((_) async => XFile('/tmp/badge.png'));

      final result = await sandboxAndroidFileSelector(
        params(),
        picker,
        metadataStripper: (imageFile) async {
          strippedPaths.add(imageFile.path);
          return File('/tmp/badge-stripped.jpg');
        },
      );

      expect(strippedPaths, equals(['/tmp/badge.png']));
      expect(result, equals(['file:///tmp/badge-stripped.jpg']));
    });

    test('uses the camera when the input requests capture', () async {
      when(
        () => picker.pickImage(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile('/tmp/shot.jpg'));

      final result = await sandboxAndroidFileSelector(
        params(isCaptureEnabled: true),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, equals(['file:///tmp/shot.jpg']));
      verifyNever(() => picker.pickImage(source: ImageSource.gallery));
    });

    test('returns empty when the user cancels the picker', () async {
      when(
        () => picker.pickImage(source: ImageSource.gallery),
      ).thenAnswer((_) async => null);

      final result = await sandboxAndroidFileSelector(
        params(),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, isEmpty);
    });

    test('picks multiple images in openMultiple mode', () async {
      when(() => picker.pickMultiImage()).thenAnswer(
        (_) async => [XFile('/tmp/a.png'), XFile('/tmp/b.png')],
      );

      final result = await sandboxAndroidFileSelector(
        params(mode: FileSelectorMode.openMultiple),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, equals(['file:///tmp/a.png', 'file:///tmp/b.png']));
    });

    test(
      'uses the camera for openMultiple when capture is requested',
      () async {
        when(
          () => picker.pickImage(source: ImageSource.camera),
        ).thenAnswer((_) async => XFile('/tmp/capture.jpg'));

        final result = await sandboxAndroidFileSelector(
          params(mode: FileSelectorMode.openMultiple, isCaptureEnabled: true),
          picker,
          metadataStripper: passthroughStripper,
        );

        expect(result, equals(['file:///tmp/capture.jpg']));
        verifyNever(() => picker.pickMultiImage());
        verifyNever(() => picker.pickImage(source: ImageSource.gallery));
      },
    );

    test('does not open the picker for save mode', () async {
      final result = await sandboxAndroidFileSelector(
        params(mode: FileSelectorMode.save),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, isEmpty);
      verifyNever(() => picker.pickImage(source: ImageSource.gallery));
      verifyNever(() => picker.pickImage(source: ImageSource.camera));
      verifyNever(() => picker.pickMultiImage());
    });

    test('does not open the picker for a non-image accept type', () async {
      final result = await sandboxAndroidFileSelector(
        params(acceptTypes: const ['application/pdf']),
        picker,
      );

      expect(result, isEmpty);
      verifyNever(() => picker.pickImage(source: ImageSource.gallery));
      verifyNever(() => picker.pickImage(source: ImageSource.camera));
      verifyNever(() => picker.pickMultiImage());
    });

    test('falls back to gallery images when no accept type is set', () async {
      when(
        () => picker.pickImage(source: ImageSource.gallery),
      ).thenAnswer((_) async => XFile('/tmp/any.webp'));

      final result = await sandboxAndroidFileSelector(
        params(acceptTypes: const []),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, equals(['file:///tmp/any.webp']));
    });

    // Android hands a plain `<input type="file">` (no accept attr) to the
    // selector as `['']`, `['*']`, or `['*/*']` — not `[]`. All mean
    // "accept anything" and must open the picker, not silently no-op.
    for (final anyToken in const ['', '*', '*/*']) {
      test('opens the gallery for the accept-anything token '
          '"$anyToken"', () async {
        when(
          () => picker.pickImage(source: ImageSource.gallery),
        ).thenAnswer((_) async => XFile('/tmp/any.png'));

        final result = await sandboxAndroidFileSelector(
          params(acceptTypes: [anyToken]),
          picker,
          metadataStripper: passthroughStripper,
        );

        expect(result, equals(['file:///tmp/any.png']));
      });
    }

    for (final extension in const ['.avif', '.bmp', '.heif', '.tif']) {
      test(
        'opens the gallery for image extension token "$extension"',
        () async {
          when(
            () => picker.pickImage(source: ImageSource.gallery),
          ).thenAnswer((_) async => XFile('/tmp/extension-image'));

          final result = await sandboxAndroidFileSelector(
            params(acceptTypes: [extension]),
            picker,
            metadataStripper: passthroughStripper,
          );

          expect(result, equals(['file:///tmp/extension-image']));
        },
      );
    }

    test('returns empty when picking throws', () async {
      when(
        () => picker.pickImage(source: ImageSource.gallery),
      ).thenThrow(Exception('picker exploded'));

      final result = await sandboxAndroidFileSelector(
        params(),
        picker,
        metadataStripper: passthroughStripper,
      );

      expect(result, isEmpty);
    });
  });
}

NostrAppDirectoryEntry _fixtureApp() {
  return NostrAppDirectoryEntry(
    id: 'primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'getRelays', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}

NostrAppDirectoryEntry _fixtureBadgesApp() {
  return NostrAppDirectoryEntry(
    id: 'bundled-badges',
    slug: 'badges',
    name: 'Divine Badges',
    tagline: 'Manage Nostr badge awards',
    description: 'Accept, reject, and issue Divine badges.',
    iconUrl: 'https://badges.divine.video/favicon.ico',
    launchUrl: 'https://badges.divine.video/me',
    allowedOrigins: const ['https://badges.divine.video'],
    allowedNavigationOrigins: const ['https://login.divine.video'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [3, 8, 10002, 10008, 30008, 30009],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 15,
    createdAt: DateTime.parse('2026-05-02T00:00:00Z'),
    updatedAt: DateTime.parse('2026-05-02T00:00:00Z'),
  );
}

class _ThrowOnBackgroundColorWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _ThrowOnBackgroundColorWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return _FakeCookieManager(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakeNavigationDelegate(params);
  }
}

class _HistoryAwareWebViewPlatform extends WebViewPlatform {
  _HistoryAwareWebViewPlatform({required this.canGoBackInitially});

  final bool canGoBackInitially;
  late final _HistoryAwareWebViewController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = _HistoryAwareWebViewController(
      params,
      canGoBackInitially: canGoBackInitially,
    );
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return _FakeCookieManager(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakeNavigationDelegate(params);
  }
}

class _BootstrapAwareWebViewPlatform extends WebViewPlatform {
  late final _BootstrapAwareWebViewController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = _BootstrapAwareWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return _FakeCookieManager(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakeNavigationDelegate(params);
  }
}

class _ThrowOnBackgroundColorWebViewController
    extends PlatformWebViewController {
  _ThrowOnBackgroundColorWebViewController(super.params)
    : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {
    throw UnimplementedError('opaque is not implemented on macOS');
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<String?> currentUrl() async => 'https://primal.net/app';
}

class _HistoryAwareWebViewController extends PlatformWebViewController {
  _HistoryAwareWebViewController(
    super.params, {
    required this.canGoBackInitially,
  }) : super.implementation();

  final bool canGoBackInitially;
  int goBackCallCount = 0;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<String?> currentUrl() async => 'https://primal.net/app';

  @override
  Future<bool> canGoBack() async => canGoBackInitially;

  @override
  Future<void> goBack() async {
    goBackCallCount += 1;
  }
}

class _BootstrapAwareWebViewController extends PlatformWebViewController {
  _BootstrapAwareWebViewController(super.params) : super.implementation();

  int loadRequestCallCount = 0;
  final loadedHtml = <String>[];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadRequestCallCount += 1;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    loadedHtml.add(html);
  }

  @override
  Future<String?> currentUrl() async => 'https://primal.net/app';
}

class _FakeCookieManager extends PlatformWebViewCookieManager {
  _FakeCookieManager(super.params) : super.implementation();
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback handler) async {}
}

class _FakeAuthProvider implements BridgeAuthProvider {
  @override
  String? get currentPublicKeyHex => 'f' * 64;

  @override
  List<BridgeRelay> get userRelays => const [];

  @override
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final event = Event('f' * 64, kind, tags, content, createdAt: createdAt);
    return BridgeSignedEvent(json: event.toJson());
  }
}

class _ThrowingBridgeService extends NostrAppBridgeService {
  _ThrowingBridgeService(SharedPreferences sharedPreferences)
    : super(
        authProvider: _FakeAuthProvider(),
        policy: NostrAppBridgePolicy(
          grantStore: NostrAppGrantStore(
            sharedPreferences: sharedPreferences,
          ),
          currentUserPubkey: 'f' * 64,
        ),
        signerFactory: _FakeNostrSigner.new,
      );

  @override
  Future<BridgeResult> handleRequest({
    required NostrAppDirectoryEntry app,
    required Uri origin,
    required String method,
    required Map<String, dynamic> args,
    BridgePermissionPrompter? promptForPermission,
  }) async {
    throw StateError('secret internal failure');
  }
}

class _FakeNostrSigner implements NostrSigner {
  @override
  void close() {}

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> getPublicKey() async => 'f' * 64;

  @override
  Future<Map<dynamic, dynamic>?> getRelays() async => null;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<Event?> signEvent(Event event) async => event;
}
