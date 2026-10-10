// ABOUTME: Repository for fetching the current account's parental consent /
// ABOUTME: minor-account review restriction status from the backend.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:unified_logger/unified_logger.dart';

class MinorAccountReviewRepository {
  MinorAccountReviewRepository({
    required ApiService apiService,
    required MinorAccountReviewOverrideService overrideService,
  }) : _apiService = apiService,
       _overrideService = overrideService;

  final ApiService _apiService;
  final MinorAccountReviewOverrideService _overrideService;

  Future<MinorAccountReviewStatus> fetchCurrentStatus() async {
    try {
      final response = await _apiService.getMinorAccountReviewStatus();
      return MinorAccountReviewStatus.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        Log.warning(
          'Minor account review endpoint unavailable, falling back to active',
          name: 'MinorAccountReviewRepository',
          category: LogCategory.api,
        );
        return MinorAccountReviewStatus.active();
      }
      rethrow;
    }
  }

  /// Submits the parent's contact email for [caseId].
  ///
  /// [localReceipt] is the copy written into the developer override when one
  /// is simulating this case locally; see [_completedLocally].
  Future<void> submitParentContact({
    required String caseId,
    required String email,
    MinorReviewInstructions? localReceipt,
  }) async {
    if (await _completedLocally(caseId, localReceipt)) return;
    await _apiService.submitMinorAccountReviewParentContact(
      caseId: caseId,
      email: email,
    );
  }

  /// Submits the recorded parent-consent clip at [videoPath] for [caseId].
  ///
  /// [localReceipt] is the copy written into the developer override when one
  /// is simulating this case locally; see [_completedLocally].
  Future<void> submitParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
    MinorReviewInstructions? localReceipt,
  }) async {
    if (await _completedLocally(caseId, localReceipt)) return;
    await _apiService.submitMinorAccountReviewParentConsent(
      caseId: caseId,
      email: email,
      videoPath: videoPath,
    );
  }

  /// Marks a locally simulated case submitted instead of calling the backend.
  ///
  /// A developer running against a local override has no server-side case to
  /// submit to, so the override is advanced in place. Returns whether that
  /// happened; in release builds, and for any case the override does not
  /// describe, it returns false and the caller goes to the API.
  ///
  /// This selection belongs here rather than at each call site: both consent
  /// paths need it, and duplicating it once per screen is how the two copies
  /// drift apart.
  Future<bool> _completedLocally(
    String caseId,
    MinorReviewInstructions? localReceipt,
  ) async {
    if (!kDebugMode || localReceipt == null) return false;
    final localOverride = _overrideService.getOverride();
    final localCase = localOverride?.currentCase;
    if (localCase == null || localCase.id != caseId) return false;

    await _overrideService.setOverride(
      localOverride!.copyWith(
        currentCase: localCase.copyWith(
          state: MinorReviewCaseState.submittedForReview,
          instructions: localReceipt,
        ),
      ),
    );
    return true;
  }
}
