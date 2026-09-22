// ABOUTME: Repository for fetching the current account's parental consent /
// ABOUTME: minor-account review restriction status from the backend.

import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/services/api_service.dart';
import 'package:unified_logger/unified_logger.dart';

class MinorAccountReviewRepository {
  MinorAccountReviewRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

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

  Future<void> submitParentContact({
    required String caseId,
    required String email,
  }) async {
    await _apiService.submitMinorAccountReviewParentContact(
      caseId: caseId,
      email: email,
    );
  }

  Future<void> submitParentConsent({
    required String caseId,
    required String email,
    required String videoPath,
  }) async {
    await _apiService.submitMinorAccountReviewParentConsent(
      caseId: caseId,
      email: email,
      videoPath: videoPath,
    );
  }
}
