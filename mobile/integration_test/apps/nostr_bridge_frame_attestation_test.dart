// ABOUTME: End-to-end coverage for the iOS frame attestation channel.
// ABOUTME: Drives a real WKWebView through the live WKScriptMessage hop.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live channel coverage for `NostrBridgeAttestationPlugin`.
///
/// The widget tests in `test/screens/apps/nostr_app_sandbox_screen_test.dart`
/// exercise `_handleAttestedEvent` via the `onAttestedEventHandlerReady`
/// seam — they prove the Dart-side branching but never traverse the
/// `WKScriptMessage → FrameAttestingScriptMessageHandler → FlutterEventSink
/// → EventChannel → broadcast stream → _handleAttestedEvent` hop. A
/// channel-name typo, payload-key drift, or stream-lifecycle bug on either
/// side of the channel would silently degrade defence-in-depth to nonce-only
/// enforcement and leave every existing test green.
///
/// This test boots a loopback HTTP server, loads a same-origin main + iframe
/// pair into the sandbox WebView, and asserts the Dart-observable response
/// for each frame against captured `_runJavaScript` calls.
///
/// iOS-only: the native plugin lives in the Runner target; on every other
/// platform the early-return is the correct behaviour. Android per-frame
/// attestation parity is tracked separately (#4105).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NostrBridge frame attestation E2E', () {
    late HttpServer server;
    late String origin;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin = 'http://127.0.0.1:${server.port}';
      unawaited(server.forEach(_serveFixture));
    });

    tearDown(() async {
      await server.close(force: true);
    });

    testWidgets(
      'iframe-originated bridge traffic is rejected with subframe_rejected',
      (tester) async {
        if (defaultTargetPlatform != TargetPlatform.iOS) return;

        final captured = <String>[];
        await _pumpSandbox(
          tester,
          origin: origin,
          capturedScripts: captured,
        );

        await _pumpUntil(
          tester,
          () => captured.any((s) => s.contains('"id":"frame"')),
        );

        final frameResponse = captured.firstWhere(
          (s) => s.contains('"id":"frame"'),
        );
        expect(
          frameResponse,
          contains('subframe_rejected'),
          reason:
              'Iframe-originated postMessage must hit the platform-level '
              'rejection before the nonce gate.',
        );
        expect(frameResponse, isNot(contains('"success":true')));
      },
    );

    testWidgets(
      'main-frame bridge traffic reaches the bridge service',
      (tester) async {
        if (defaultTargetPlatform != TargetPlatform.iOS) return;

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

        final captured = <String>[];
        await _pumpSandbox(
          tester,
          origin: origin,
          capturedScripts: captured,
          bridgeService: bridgeService,
        );

        await _pumpUntil(
          tester,
          () => captured.any((s) => s.contains('"id":"main"')),
        );

        final mainResponse = captured.firstWhere(
          (s) => s.contains('"id":"main"'),
        );
        expect(mainResponse, isNot(contains('subframe_rejected')));
        expect(
          mainResponse,
          contains('"success":true'),
          reason:
              'Main-frame postMessage with a valid nonce must reach the '
              'bridge service and succeed.',
        );
        expect(mainResponse, contains('f' * 64));
      },
    );
  });
}

const _testNonce = 'test-nonce';
const _testPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

Future<void> _serveFixture(HttpRequest request) async {
  final path = request.uri.path;
  if (path == '/' || path == '/index.html') {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_mainPageHtml);
  } else if (path == '/iframe.html') {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_iframePageHtml);
  } else {
    request.response.statusCode = HttpStatus.notFound;
  }
  await request.response.close();
}

const _mainPageHtml =
    '''
<!doctype html>
<html><head></head><body>
<iframe src="/iframe.html" width="200" height="100"></iframe>
<script>
  // The pigeon-managed addJavaScriptChannel installs
  // window.divineSandboxBridge as an alias for
  // webkit.messageHandlers.divineSandboxBridge at document-start.
  // Poll until it is available, then post the main-frame request.
  function _postMain() {
    if (typeof divineSandboxBridge === 'undefined') {
      setTimeout(_postMain, 25);
      return;
    }
    divineSandboxBridge.postMessage(JSON.stringify({
      id: 'main',
      method: 'getPublicKey',
      args: {},
      nonce: '$_testNonce'
    }));
  }
  _postMain();
</script>
</body></html>
''';

const _iframePageHtml = '''
<!doctype html>
<html><body>
<script>
  // Iframe attempts to reach the bridge directly via the WebKit message
  // handler — bypassing window.divineSandboxBridge (which the pigeon
  // alias only exposes in the main frame). With per-frame attestation
  // in place the host must reject this with subframe_rejected before
  // the nonce gate runs.
  webkit.messageHandlers.divineSandboxBridge.postMessage(JSON.stringify({
    id: 'frame',
    method: 'getPublicKey',
    args: {}
  }));
</script>
</body></html>
''';

NostrAppDirectoryEntry _fixtureApp(String origin) {
  final timestamp = DateTime.parse('2026-05-08T00:00:00Z');
  return NostrAppDirectoryEntry(
    id: 'test-frame-attestation',
    slug: 'test-frame-attestation',
    name: 'Frame Attestation Test',
    tagline: 'Loopback fixture',
    description: 'Loopback HTTP fixture for iOS frame attestation E2E.',
    iconUrl: '$origin/icon.png',
    launchUrl: '$origin/',
    allowedOrigins: [origin],
    allowedMethods: const ['getPublicKey'],
    allowedSignEventKinds: const [],
    promptRequiredFor: const [],
    status: 'approved',
    sortOrder: 0,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Future<void> _pumpSandbox(
  WidgetTester tester, {
  required String origin,
  required List<String> capturedScripts,
  NostrAppBridgeService? bridgeService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NostrAppSandboxScreen(
          app: _fixtureApp(origin),
          bridgeServiceOverride: bridgeService,
          javaScriptRunnerOverride: (script) async {
            capturedScripts.add(script);
          },
          bridgeNonceOverride: _testNonce,
          currentUserPubkeyOverride: _testPubkey,
        ),
      ),
    ),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'Timed out waiting for captured response after ${timeout.inSeconds}s',
      );
    }
    await tester.pump(interval);
  }
}

class _FakeAuthProvider implements BridgeAuthProvider {
  @override
  String? get currentPublicKeyHex => _testPubkey;

  @override
  List<BridgeRelay> get userRelays => const [];

  @override
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final event = Event(_testPubkey, kind, tags, content, createdAt: createdAt);
    return BridgeSignedEvent(json: event.toJson());
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
  Future<String?> getPublicKey() async => _testPubkey;

  @override
  Future<Map<dynamic, dynamic>?> getRelays() async => null;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<Event?> signEvent(Event event) async => event;
}
