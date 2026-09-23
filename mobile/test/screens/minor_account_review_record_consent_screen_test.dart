// ABOUTME: Tests for the in-app consent capture screen's confirm-and-submit
// ABOUTME: step, covering the accepted clip, the submitted email, and failures.

import 'dart:io' show Directory, File, SocketException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository implements MinorAccountReviewRepository {
  bool throwOnSubmit = false;
  Object? submitError;
  String? submittedCaseId;
  String? submittedEmail;
  String? submittedVideoPath;

  @override
  Future<MinorAccountReviewStatus> fetchCurrentStatus() async =>
      MinorAccountReviewStatus.active();

  @override
  Future<void> submitParentContact({
    required String caseId,
    required String email,
  }) async {}

  @override
  Future<void> submitParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
  }) async {
    if (throwOnSubmit) {
      throw Exception('submit failed');
    }
    final error = submitError;
    if (error != null) {
      throw error;
    }
    submittedCaseId = caseId;
    submittedEmail = email;
    submittedVideoPath = videoPath;
  }
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

/// Keeps both review-status providers listened so an invalidation re-reads
/// them, which is what the post-submit refresh depends on.
class _ProviderWatcher extends ConsumerWidget {
  const _ProviderWatcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentMinorAccountReviewStatusProvider);
    ref.watch(protectedMinorStatusProvider);
    return child;
  }
}

class _FakeRecorder implements MinorConsentRecorder {
  _FakeRecorder({this.stopResult = '/tmp/consent.mp4'});

  final String? stopResult;
  bool initialized = false;

  @override
  void Function(String? path)? onAutoStopped;

  void fireAutoStopped(String? path) => onAutoStopped?.call(path);

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) async => true;

  @override
  Future<String?> stop() async => stopResult;

  @override
  Future<void> dispose() async {}
}

class _FakePermissions implements PermissionsService {
  _FakePermissions({
    this.cameraStatus = PermissionStatus.granted,
    this.microphoneStatus = PermissionStatus.granted,
    this.throwOnCameraCheck = false,
  });

  PermissionStatus cameraStatus;
  PermissionStatus microphoneStatus;
  bool throwOnCameraCheck;

  @override
  Future<PermissionStatus> checkCameraStatus() async {
    if (throwOnCameraCheck) {
      throw Exception('permission check failed');
    }
    return cameraStatus;
  }

  @override
  Future<PermissionStatus> requestCameraPermission() async => cameraStatus;

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async => microphoneStatus;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async =>
      microphoneStatus;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionStatus> checkGalleryStatus() async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> requestGalleryPermission() async =>
      PermissionStatus.granted;
}

Future<void> _pumpFrames(WidgetTester tester) async {
  // The live preview keeps a camera listener alive, so park on a bounded set of
  // frames instead of pumpAndSettle, which would never quiesce.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Grows the test surface so the capture and review ListViews build their
/// controls instead of lazy-building only the on-screen prompt card.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpRecordConsentScreen(
  WidgetTester tester, {
  required _FakeRecorder recorder,
  required PermissionsService permissions,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const MinorAccountReviewRecordConsentScreen(),
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
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await _pumpFrames(tester);
  }
}

void main() {
  group('MinorAccountReviewRecordConsentScreen permissions', () {
    testWidgets('camera denial offers the email fallback', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final recorder = _FakeRecorder();

      await _pumpRecordConsentScreen(
        tester,
        recorder: recorder,
        permissions: _FakePermissions(
          cameraStatus: PermissionStatus.requiresSettings,
        ),
      );

      expect(
        find.text(l10n.minorAccountReviewRecordConsentDeniedTitle),
        findsOneWidget,
      );
      expect(recorder.initialized, isFalse);

      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentEmailInsteadCta),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(MinorAccountReviewParentConsentScreen),
        findsOneWidget,
      );
    });

    testWidgets('microphone denial offers the email fallback', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final recorder = _FakeRecorder();

      await _pumpRecordConsentScreen(
        tester,
        recorder: recorder,
        permissions: _FakePermissions(
          microphoneStatus: PermissionStatus.requiresSettings,
        ),
      );

      expect(
        find.text(l10n.minorAccountReviewRecordConsentDeniedTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewRecordConsentEmailInsteadCta),
        findsOneWidget,
      );
      expect(recorder.initialized, isFalse);
    });

    testWidgets('a failing permission check offers the email fallback', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final recorder = _FakeRecorder();

      await _pumpRecordConsentScreen(
        tester,
        recorder: recorder,
        permissions: _FakePermissions(throwOnCameraCheck: true),
      );

      expect(
        find.text(l10n.minorAccountReviewRecordConsentDeniedTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewRecordConsentEmailInsteadCta),
        findsOneWidget,
      );
    });
  });

  group('MinorConsentSubmitView', () {
    testWidgets('submits the accepted clip with the confirmed email', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final repository = _FakeRepository();
      var fallbackTapped = false;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            minorAccountReviewOverrideServiceProvider.overrideWithValue(
              MinorAccountReviewOverrideService(prefs: prefs),
            ),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => _statusWithCase(),
            ),
            minorAccountReviewRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MinorConsentSubmitView(
                videoPath: '/tmp/consent.mp4',
                onUseEmailFallback: () => fallbackTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'parent@example.com',
      );
      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
      );
      await tester.pumpAndSettle();

      expect(repository.submittedCaseId, 'case-1');
      expect(repository.submittedEmail, 'parent@example.com');
      expect(repository.submittedVideoPath, '/tmp/consent.mp4');
      expect(
        find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
        findsOneWidget,
      );
      expect(fallbackTapped, isFalse);
    });

    testWidgets('keeps the clip and offers retry when submit fails', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final repository = _FakeRepository()..throwOnSubmit = true;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            minorAccountReviewOverrideServiceProvider.overrideWithValue(
              MinorAccountReviewOverrideService(prefs: prefs),
            ),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => _statusWithCase(),
            ),
            minorAccountReviewRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MinorConsentSubmitView(
                videoPath: '/tmp/consent.mp4',
                onUseEmailFallback: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'parent@example.com',
      );
      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.minorAccountReviewRecordConsentSubmitError),
        findsOneWidget,
      );
      // The retry (submit) control and the email fallback stay visible.
      expect(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewRecordConsentEmailInsteadCta),
        findsOneWidget,
      );
      expect(
        find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
        findsNothing,
      );

      // Retrying resubmits the same accepted clip, proving it was never
      // discarded when the first attempt failed.
      repository.throwOnSubmit = false;
      await tester.tap(
        find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
      );
      await tester.pumpAndSettle();

      expect(repository.submittedVideoPath, '/tmp/consent.mp4');
      expect(
        find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
        findsOneWidget,
      );
    });

    testWidgets(
      'an offline submit surfaces retry without discarding the clip',
      (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repository = _FakeRepository()
          ..submitError = const SocketException('network is unreachable');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              minorAccountReviewOverrideServiceProvider.overrideWithValue(
                MinorAccountReviewOverrideService(prefs: prefs),
              ),
              currentMinorAccountReviewStatusProvider.overrideWith(
                (ref) async => _statusWithCase(),
              ),
              minorAccountReviewRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MinorConsentSubmitView(
                  videoPath: '/tmp/consent.mp4',
                  onUseEmailFallback: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'parent@example.com',
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.minorAccountReviewRecordConsentSubmitError),
          findsOneWidget,
        );
        expect(
          find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
          findsOneWidget,
        );
        expect(
          find.text(l10n.minorAccountReviewRecordConsentEmailInsteadCta),
          findsOneWidget,
        );

        // Back online: the retry submits the retained clip.
        repository.submitError = null;
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
        );
        await tester.pumpAndSettle();

        expect(repository.submittedVideoPath, '/tmp/consent.mp4');
        expect(
          find.text(l10n.minorAccountReviewSubmissionReceivedTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'invalidates both review status providers after a successful submit',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repository = _FakeRepository();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var reviewStatusReads = 0;
        var protectedStatusReads = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              minorAccountReviewOverrideServiceProvider.overrideWithValue(
                MinorAccountReviewOverrideService(prefs: prefs),
              ),
              currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
                reviewStatusReads++;
                return _statusWithCase();
              }),
              protectedMinorStatusProvider.overrideWith((ref) async {
                protectedStatusReads++;
                return ProtectedMinorStatus.notProtected();
              }),
              minorAccountReviewRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: _ProviderWatcher(
                  child: MinorConsentSubmitView(
                    videoPath: '/tmp/consent.mp4',
                    onUseEmailFallback: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reviewReadsBefore = reviewStatusReads;
        final protectedReadsBefore = protectedStatusReads;
        expect(reviewReadsBefore, greaterThan(0));
        expect(protectedReadsBefore, greaterThan(0));

        await tester.enterText(
          find.byType(TextFormField),
          'parent@example.com',
        );
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentSubmitCta),
        );
        await tester.pumpAndSettle();

        expect(reviewStatusReads, greaterThan(reviewReadsBefore));
        expect(protectedStatusReads, greaterThan(protectedReadsBefore));
      },
    );
  });

  group('MinorAccountReviewRecordConsentScreen clip cleanup', () {
    late Directory tempDir;
    late File clip;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('minor-consent-test');
      clip = File('${tempDir.path}/consent.mp4')..writeAsBytesSync([0, 1, 2]);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'auto-stop reaches review without a manual stop tap',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final recorder = _FakeRecorder();
        _useTallSurface(tester);

        await _pumpRecordConsentScreen(
          tester,
          recorder: recorder,
          permissions: _FakePermissions(),
          settle: false,
        );

        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentRecordCta),
        );
        await _pumpFrames(tester);

        recorder.fireAutoStopped(clip.path);
        await _pumpFrames(tester);

        expect(
          find.text(l10n.minorAccountReviewRecordConsentReviewTitle),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await _pumpFrames(tester);
      },
    );

    testWidgets(
      'discards the recorded clip when the screen is disposed before accepting',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final recorder = _FakeRecorder(stopResult: clip.path);
        _useTallSurface(tester);

        await _pumpRecordConsentScreen(
          tester,
          recorder: recorder,
          permissions: _FakePermissions(),
          settle: false,
        );

        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentRecordCta),
        );
        await _pumpFrames(tester);
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentStopCta),
        );
        await _pumpFrames(tester);

        expect(
          find.text(l10n.minorAccountReviewRecordConsentReviewTitle),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await _pumpFrames(tester);

        expect(clip.existsSync(), isFalse);
      },
    );

    testWidgets(
      'discards the accepted clip when the screen is disposed without submitting',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final recorder = _FakeRecorder(stopResult: clip.path);
        _useTallSurface(tester);

        await _pumpRecordConsentScreen(
          tester,
          recorder: recorder,
          permissions: _FakePermissions(),
          settle: false,
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith(
              (ref) async => _statusWithCase(),
            ),
          ],
        );

        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentRecordCta),
        );
        await _pumpFrames(tester);
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentStopCta),
        );
        await _pumpFrames(tester);
        await tester.tap(
          find.text(l10n.minorAccountReviewRecordConsentUseVideoCta),
        );
        await _pumpFrames(tester);

        expect(
          find.text(l10n.minorAccountReviewRecordConsentConfirmEmailTitle),
          findsOneWidget,
        );
        expect(clip.existsSync(), isTrue);

        await tester.pumpWidget(const SizedBox());
        await _pumpFrames(tester);

        expect(clip.existsSync(), isFalse);
      },
    );
  });
}
