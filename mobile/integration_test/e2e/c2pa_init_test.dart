// ABOUTME: E2E test verifying C2PA signer initializes without crashing
// ABOUTME: Catches StrongBox fallback bug (issue #2019) where StrongBoxSigner
// ABOUTME: was used with a software-backed key on devices without StrongBox
// ABOUTME: Requires: NO Docker stack, and an Android device. c2pa_flutter
// ABOUTME: ships no desktop implementation, and on the iOS simulator the
// ABOUTME: cert is never produced, so the assertion below fails there.

@Tags(['service'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:path_provider/path_provider.dart';

import '../helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('C2PA Signer Initialization', () {
    testWidgets('C2PA hardware signer creates cert file on emulator', (
      tester,
    ) async {
      await runWithAppErrorHandlers(() async {
        final appDir = await getApplicationDocumentsDirectory();
        final certFile = File('${appDir.path}/c2pa_signing_divine.cert');

        // Force the test to validate fresh certificate creation on startup.
        if (certFile.existsSync()) {
          certFile.deleteSync();
        }

        // Launch the app — C2PA init runs async on Dispatchers.IO at startup.
        // pumpAndSettle never returns here: the app runs persistent polling
        // timers, so the tree never reaches a quiescent frame.
        launchAppGuarded(app.main);
        await pumpUntilSettled(tester, maxSeconds: 3);

        // Wait for C2PA init to complete (certificate enrollment + signing)
        // Poll for cert file (C2PA init runs async, may take a few seconds)
        var certExists = false;
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (certFile.existsSync()) {
            certExists = true;
            break;
          }
        }

        // The cert file is written by createHardwareSigner() only on success.
        // On the buggy path (StrongBoxSigner with software key), init crashes
        // and the cert file is never created.
        expect(
          certExists,
          isTrue,
          reason:
              'C2PA cert file should exist after successful signer init. '
              'If missing, createHardwareSigner() crashed — likely the '
              'StrongBox fallback bug (issue #2019) where StrongBoxSigner '
              'is used with a software-backed key.',
        );

        // Verify cert file has content (not empty/corrupt)
        final certContent = certFile.readAsStringSync();
        expect(
          certContent,
          contains('BEGIN CERTIFICATE'),
          reason: 'Cert file should contain a valid PEM certificate',
        );

        drainAsyncErrors(tester);
      });
    });
  });
}
