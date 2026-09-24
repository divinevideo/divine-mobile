import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MinorAccountReviewRepository', () {
    late MockApiService apiService;
    late MinorAccountReviewOverrideService overrideService;
    late MinorAccountReviewRepository repository;

    setUp(() async {
      apiService = MockApiService();
      SharedPreferences.setMockInitialValues({});
      overrideService = MinorAccountReviewOverrideService(
        prefs: await SharedPreferences.getInstance(),
      );
      repository = MinorAccountReviewRepository(
        apiService: apiService,
        overrideService: overrideService,
      );
    });

    test('returns parsed restricted status from API', () async {
      when(
        () => apiService.getMinorAccountReviewStatus(),
      ).thenAnswer(
        (_) async => {
          'restriction': {'status': 'restricted_minor_review'},
          'minorReviewCase': {
            'id': 'mar_123',
            'state': 'restricted_pending_user_response',
            'suspectedAgeBand': 'age_13_15',
            'allowedResolution': 'parent_video_or_email',
            'supportEmail': 'support@divine.video',
            'instructions': {
              'title': 'We need to review this account',
              'body': 'Follow the parental consent steps.',
            },
          },
        },
      );

      final result = await repository.fetchCurrentStatus();

      expect(result.isRestricted, isTrue);
      expect(result.currentCase, isNotNull);
      expect(result.currentCase!.id, 'mar_123');
      expect(
        result.currentCase!.allowedResolution,
        MinorReviewResolutionType.parentVideoOrEmail,
      );
    });

    test('falls back to active when endpoint is unavailable', () async {
      when(() => apiService.getMinorAccountReviewStatus()).thenThrow(
        const ApiException('not found', statusCode: 404),
      );

      final result = await repository.fetchCurrentStatus();

      expect(result.restrictionStatus, AccountRestrictionStatus.active);
      expect(result.currentCase, isNull);
    });

    test('rethrows when endpoint request has no HTTP status', () async {
      when(() => apiService.getMinorAccountReviewStatus()).thenThrow(
        const ApiException('Network error during moderation status request'),
      );

      await expectLater(
        repository.fetchCurrentStatus(),
        throwsA(isA<ApiException>()),
      );
    });

    test('keeps HTTP server failures visible', () async {
      when(() => apiService.getMinorAccountReviewStatus()).thenThrow(
        const ApiException('server error', statusCode: 500),
      );

      await expectLater(
        repository.fetchCurrentStatus(),
        throwsA(isA<ApiException>()),
      );
    });

    test('submits parent contact through api service', () async {
      when(
        () => apiService.submitMinorAccountReviewParentContact(
          caseId: any(named: 'caseId'),
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async {});

      await repository.submitParentContact(
        caseId: 'mar_123',
        email: 'parent@example.com',
      );

      verify(
        () => apiService.submitMinorAccountReviewParentContact(
          caseId: 'mar_123',
          email: 'parent@example.com',
        ),
      ).called(1);
    });

    group('submitParentConsent', () {
      test('forwards caseId, email and videoPath to ApiService', () async {
        when(
          () => apiService.submitMinorAccountReviewParentConsent(
            caseId: any(named: 'caseId'),
            email: any(named: 'email'),
            videoPath: any(named: 'videoPath'),
          ),
        ).thenAnswer((_) async {});

        await repository.submitParentConsent(
          caseId: 'case-1',
          email: 'parent@example.com',
          videoPath: '/tmp/consent.mp4',
        );

        verify(
          () => apiService.submitMinorAccountReviewParentConsent(
            caseId: 'case-1',
            email: 'parent@example.com',
            videoPath: '/tmp/consent.mp4',
          ),
        ).called(1);
      });

      test(
        'advances a matching developer override instead of the API',
        () async {
          await overrideService.setOverride(_overrideForCase('case-1'));

          await repository.submitParentConsent(
            caseId: 'case-1',
            email: 'parent@example.com',
            videoPath: '/tmp/consent.mp4',
            localReceipt: const MinorReviewInstructions(
              title: 'Received',
              body: 'We have your video.',
            ),
          );

          final stored = overrideService.getOverride()!.currentCase!;
          expect(stored.state, MinorReviewCaseState.submittedForReview);
          expect(stored.instructions.title, 'Received');
          verifyNever(
            () => apiService.submitMinorAccountReviewParentConsent(
              caseId: any(named: 'caseId'),
              email: any(named: 'email'),
              videoPath: any(named: 'videoPath'),
            ),
          );
        },
      );

      test('calls the API when the override describes another case', () async {
        when(
          () => apiService.submitMinorAccountReviewParentConsent(
            caseId: any(named: 'caseId'),
            email: any(named: 'email'),
            videoPath: any(named: 'videoPath'),
          ),
        ).thenAnswer((_) async {});
        await overrideService.setOverride(_overrideForCase('some-other-case'));

        await repository.submitParentConsent(
          caseId: 'case-1',
          email: 'parent@example.com',
          videoPath: '/tmp/consent.mp4',
          localReceipt: const MinorReviewInstructions(
            title: 'Received',
            body: 'We have your video.',
          ),
        );

        expect(
          overrideService.getOverride()!.currentCase!.state,
          MinorReviewCaseState.restrictedPendingParentalConsent,
        );
        verify(
          () => apiService.submitMinorAccountReviewParentConsent(
            caseId: 'case-1',
            email: 'parent@example.com',
            videoPath: '/tmp/consent.mp4',
          ),
        ).called(1);
      });
    });

    test('parent contact advances a matching developer override', () async {
      await overrideService.setOverride(_overrideForCase('mar_123'));

      await repository.submitParentContact(
        caseId: 'mar_123',
        email: 'parent@example.com',
        localReceipt: const MinorReviewInstructions(
          title: 'Received',
          body: 'We have your email.',
        ),
      );

      expect(
        overrideService.getOverride()!.currentCase!.state,
        MinorReviewCaseState.submittedForReview,
      );
      verifyNever(
        () => apiService.submitMinorAccountReviewParentContact(
          caseId: any(named: 'caseId'),
          email: any(named: 'email'),
        ),
      );
    });
  });
}

MinorAccountReviewStatus _overrideForCase(String caseId) {
  return MinorAccountReviewStatus(
    restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
    currentCase: MinorReviewCase(
      id: caseId,
      state: MinorReviewCaseState.restrictedPendingParentalConsent,
      suspectedAgeBand: SuspectedAgeBand.age13To15,
      allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
      instructions: const MinorReviewInstructions(
        title: 'Account review required',
        body: 'We need parental consent information.',
      ),
      supportEmail: 'support@divine.video',
    ),
  );
}
