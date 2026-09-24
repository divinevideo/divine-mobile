// ABOUTME: Image goldens for the in-app parent-consent capture flow: the idle
// ABOUTME: preview, the recorded-clip review, and the confirm-and-submit step.
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:permissions_service/permissions_service.dart';

/// Boundary around the whole screen, so the scaffold surface is inside the
/// captured image rather than a transparent ring outside it.
const ValueKey<String> _goldenKey = ValueKey('minor-consent-golden');

/// Recorder whose [initialize] never completes.
///
/// The idle pane only reaches its placeholder preview — a native camera
/// preview cannot render in a widget test and its spinner would never settle.
/// Keeping initialization pending leaves the screen on the inert idle layout.
class _PendingInitRecorder implements MinorConsentRecorder {
  @override
  void Function(String? path)? onAutoStopped;

  @override
  Future<void> initialize() => Completer<void>().future;

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) async => true;

  @override
  Future<String?> stop() async => '/tmp/consent.mp4';

  @override
  Future<void> dispose() async {}
}

/// Recorder that reports a completed clip, so the screen can reach review.
class _ReviewRecorder implements MinorConsentRecorder {
  @override
  void Function(String? path)? onAutoStopped;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) async => true;

  @override
  Future<String?> stop() async => '/tmp/consent.mp4';

  @override
  Future<void> dispose() async {}
}

/// Stands in for the real repository so the submit pane can render without an
/// `ApiService`; the goldens never submit.
class _InertRepository implements MinorAccountReviewRepository {
  @override
  Future<MinorAccountReviewStatus> fetchCurrentStatus() async =>
      MinorAccountReviewStatus.active();

  @override
  Future<void> submitParentContact({
    required String caseId,
    required String email,
    MinorReviewInstructions? localReceipt,
  }) async {}

  @override
  Future<void> submitParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
    MinorReviewInstructions? localReceipt,
  }) async {}
}

class _FakePermissions implements PermissionsService {
  @override
  Future<PermissionStatus> checkCameraStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestCameraPermission() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async =>
      PermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionStatus> checkGalleryStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestGalleryPermission() async =>
      PermissionStatus.granted;
}

MinorAccountReviewStatus _statusWithCase() {
  return const MinorAccountReviewStatus(
    restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
    currentCase: MinorReviewCase(
      id: 'case-1',
      state: MinorReviewCaseState.restrictedPendingParentalConsent,
      suspectedAgeBand: SuspectedAgeBand.age13To15,
      allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
      instructions: MinorReviewInstructions(
        title: 'Account review required',
        body: 'We need parental consent information.',
      ),
      supportEmail: 'support@divine.video',
    ),
  );
}

void main() {
  group('minor consent capture goldens', () {
    testWidgets('idle capture pane', (tester) async {
      await _pumpRecordConsentScreen(
        tester,
        recorder: _PendingInitRecorder(),
        permissions: _FakePermissions(),
      );
      await _pumpFrames(tester);

      await _drainFonts(tester);

      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/minor_consent_capture_idle.png'),
      );
    }, tags: ['golden']);

    testWidgets('recorded clip review pane', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await _pumpRecordConsentScreen(
        tester,
        recorder: _ReviewRecorder(),
        permissions: _FakePermissions(),
      );
      await _pumpFrames(tester);

      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentRecordCta),
      );
      await _pumpFrames(tester);
      await tester.tap(find.text(l10n.minorAccountReviewRecordConsentStopCta));
      await _pumpFrames(tester);

      expect(
        find.text(l10n.minorAccountReviewRecordConsentReviewTitle),
        findsOneWidget,
      );

      await _drainFonts(tester);

      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/minor_consent_capture_review.png'),
      );
    }, tags: ['golden']);

    testWidgets('confirm and submit pane', (tester) async {
      tester.view.physicalSize = _surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => RepaintBoundary(
              key: _goldenKey,
              child: Scaffold(
                backgroundColor: _surfaceColor,
                body: const MinorConsentSubmitView(
                  videoPath: '/tmp/consent.mp4',
                  onUseEmailFallback: _noop,
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => _statusWithCase(),
            ),
            minorAccountReviewRepositoryProvider.overrideWithValue(
              _InertRepository(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _drainFonts(tester);

      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/minor_consent_submit.png'),
      );
    }, tags: ['golden']);
  });
}

const Size _surfaceSize = Size(390, 844);

Color get _surfaceColor => VineTheme.theme.colorScheme.surface;

void _noop() {}

/// Pumps [frames] frames with a short duration, advancing the screen's async
/// camera/permission chain without `pumpAndSettle`, which a running camera
/// spinner would never let terminate.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Drains google_fonts before a capture, which `VineTheme` resolves lazily per
/// variant; without it a golden silently captures Ahem blocks.
Future<void> _drainFonts(WidgetTester tester) async {
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pump();
}

Future<void> _pumpRecordConsentScreen(
  WidgetTester tester, {
  required MinorConsentRecorder recorder,
  required PermissionsService permissions,
}) async {
  tester.view.physicalSize = _surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RepaintBoundary(
          key: _goldenKey,
          child: MinorAccountReviewRecordConsentScreen(),
        ),
      ),
      GoRoute(
        path: MinorAccountReviewParentConsentScreen.path,
        builder: (context, state) =>
            const MinorAccountReviewParentConsentScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        minorConsentRecorderProvider.overrideWithValue(recorder),
        permissionsServiceProvider.overrideWithValue(permissions),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: VineTheme.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}
