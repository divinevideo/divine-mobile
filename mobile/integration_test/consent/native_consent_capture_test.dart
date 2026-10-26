// ABOUTME: Native camera and production consent-screen submission acceptance.
// ABOUTME: Uses a synthetic identity and the isolated local Worker, never live accounts.
import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/consent_acceptance_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('native consent capture interactions', () {
    testWidgets('native consent capture submits to the local review backend', (
      tester,
    ) async {
      // adb reverse tcp:48787 tcp:48787 keeps signed URLs identical on both ends.
      const endpoint = 'http://127.0.0.1:48787';
      final signer = SyntheticConsentSigner(
        '0000000000000000000000000000000000000000000000000000000000000002',
      );
      final auth = Nip98AuthService(authService: signer);
      final api = ApiService(
        relayManagerBaseUrl: endpoint,
        appVersion: 'local-camera-acceptance',
        authService: auth,
      );
      addTearDown(auth.dispose);
      addTearDown(api.dispose);
      debugPrint('CONSENT_NATIVE: opening local review case');
      final caseId = MinorAccountReviewStatus.fromJson(
        await api.startGreenlight(),
      ).currentCase!.id;
      debugPrint('CONSENT_NATIVE: local review case opened');
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 20),
      );
      debugPrint('CONSENT_NATIVE: preferences ready');
      final l10n = lookupAppLocalizations(const Locale('en'));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const MinorAccountReviewRecordConsentScreen(),
          ),
          GoRoute(
            path: MinorAccountReviewParentConsentScreen.path,
            builder: (_, _) => const MinorAccountReviewParentConsentScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(signer),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            apiServiceProvider.overrideWithValue(api),
            sharedPreferencesProvider.overrideWithValue(prefs),
            isFeatureEnabledProvider(FeatureFlag.minorConsentInAppRecording)
                .overrideWithValue(true),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      debugPrint('CONSENT_NATIVE: production capture screen mounted');
      Future<void> waitFor(bool Function() ready, String description) async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue, reason: description);
      }

      final record = find.widgetWithText(
        DivineButton,
        l10n.minorAccountReviewRecordConsentRecordCta,
      );
      await waitFor(
        () =>
            record.evaluate().isNotEmpty &&
            tester.widget<DivineButton>(record).onPressed != null,
        'native camera initialization and permissions',
      );
      await tester.ensureVisible(record);
      await tester.tap(record);
      await waitFor(
        () => find
            .text(l10n.minorAccountReviewRecordConsentStopCta)
            .evaluate()
            .isNotEmpty,
        'native recording starts',
      );
      // Produce a real two-second emulator-camera clip, rather than a canned file.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.tap(find.text(l10n.minorAccountReviewRecordConsentStopCta));
      final useVideo = find.text(
        l10n.minorAccountReviewRecordConsentUseVideoCta,
      );
      await waitFor(
        () => useVideo.evaluate().isNotEmpty,
        'native recorder returns a reviewable clip',
      );
      await tester.ensureVisible(useVideo);
      await tester.tap(useVideo);
      await waitFor(
        () => find.byType(TextFormField).evaluate().isNotEmpty,
        'confirm-email form',
      );
      await tester.enterText(find.byType(TextFormField), 'parent@example.test');
      final path = tester
          .widget<MinorConsentSubmitView>(find.byType(MinorConsentSubmitView))
          .videoPath;
      final recordedBytes = await File(path).readAsBytes();
      expect(recordedBytes.length, greaterThan(1024));
      final submit = find.text(l10n.minorAccountReviewRecordConsentSubmitCta);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await waitFor(
        () => find
            .text(l10n.minorAccountReviewVideoSubmittedTitle)
            .evaluate()
            .isNotEmpty,
        'recorded clip accepted by the real local backend',
      );
      final client = http.Client();
      addTearDown(client.close);
      final state = jsonDecode(
        (await client.get(Uri.parse('$endpoint/__test/state'))).body,
      ) as Map<String, dynamic>;
      final submission = (state['submissions']! as List<dynamic>).singleWhere(
        (dynamic row) => row['case_id'] == caseId,
      );
      final reviewCase = (state['cases']! as List<dynamic>).singleWhere(
        (dynamic row) => row['id'] == caseId,
      );
      expect(reviewCase['pubkey'], signer.currentPublicKeyHex);
      expect(reviewCase['state'], 'submitted_for_review');
      expect(submission['status'], 'commented');
      expect(submission['size_bytes'], recordedBytes.length);
      final token =
          jsonDecode(
                (await client.get(Uri.parse('$endpoint/__test/token'))).body,
              )['token']
              as String;
      final playback = await client.get(
        Uri.parse(
          '$endpoint/api/age-review/consent-video/${submission['receipt_id']}',
        ),
        headers: {'Cf-Access-Jwt-Assertion': token},
      );
      expect(playback.statusCode, 200);
      expect(playback.bodyBytes, recordedBytes);
      expect(state['unexpected'], isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
