// ABOUTME: Cubit backing the feature request flow — Zendesk submission.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/feature_request/feature_request_state.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Submit-feature-request callable hidden behind a typedef so the Cubit
/// doesn't need to know about the static `ZendeskSupportService` surface
/// directly. Tests inject a fake; production wires
/// `ZendeskSupportService.createFeatureRequest`.
typedef SubmitFeatureRequestAction = Future<bool> Function({
  required String subject,
  required String description,
  required String usefulness,
  required String whenToUse,
  String? userPubkey,
});

/// Cubit backing the feature request flow. Owns only the submission
/// lifecycle (`idle / submitting / success / failure`); the four
/// `TextEditingController`s stay in the route's form state.
///
/// On `failure`, the cubit forwards the underlying error to
/// `DivineBlocObserver` via `addError` (unified-log observability) and
/// emits a status enum the View maps to the localized failure banner —
/// no error strings stored in state. A Zendesk/network failure is a
/// domain error, so it is intentionally not wrapped in `Reportable`
/// (not forwarded to Crashlytics) per the error-handling matrix.
class FeatureRequestCubit extends Cubit<FeatureRequestState> {
  FeatureRequestCubit({
    SubmitFeatureRequestAction submitFeatureRequest =
        ZendeskSupportService.createFeatureRequest,
  }) : _submit = submitFeatureRequest,
       super(const FeatureRequestState());

  final SubmitFeatureRequestAction _submit;

  Future<void> submit({
    required String subject,
    required String description,
    required String usefulness,
    required String whenToUse,
    String? userPubkey,
  }) async {
    final trimmedSubject = subject.trim();
    final trimmedDescription = description.trim();
    if (trimmedSubject.isEmpty || trimmedDescription.isEmpty) return;

    emit(state.copyWith(status: FeatureRequestStatus.submitting));
    try {
      final success = await _submit(
        subject: trimmedSubject,
        description: trimmedDescription,
        usefulness: usefulness.trim(),
        whenToUse: whenToUse.trim(),
        userPubkey: userPubkey,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: success
              ? FeatureRequestStatus.success
              : FeatureRequestStatus.failure,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'Error submitting feature request: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(status: FeatureRequestStatus.failure));
    }
  }
}
