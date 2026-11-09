// ABOUTME: Cubit owning the confirm-and-submit step of the in-app parent
// ABOUTME: consent flow: uploading the accepted clip and the parent's email.

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/services/api_service.dart';

/// Where the confirm-and-submit step is in its upload.
enum MinorConsentSubmitStatus {
  /// Waiting for the parent to confirm their email and submit.
  editing,

  /// The clip and email are uploading.
  submitting,

  /// The upload succeeded; the receipt is shown.
  success,

  /// The upload failed; the submit control stays available as a retry.
  failure,
}

/// State of the confirm-and-submit step.
class MinorConsentSubmitState extends Equatable {
  /// Creates the state for [status], carrying [submittedEmail] once accepted.
  const MinorConsentSubmitState({
    this.status = MinorConsentSubmitStatus.editing,
    this.submittedEmail,
    this.submissionEmail,
    this.rejectionStatus,
  });

  /// Current upload phase.
  final MinorConsentSubmitStatus status;

  final String? submissionEmail;
  final int? rejectionStatus;

  bool get canEditEmail =>
      status == MinorConsentSubmitStatus.editing || rejectionStatus != null;

  /// Email the accepted submission was made with, once it succeeded.
  final String? submittedEmail;

  /// Copy of this state with [status] replaced.
  MinorConsentSubmitState copyWith({
    MinorConsentSubmitStatus? status,
    String? submissionEmail,
  }) {
    return MinorConsentSubmitState(
      status: status ?? this.status,
      submittedEmail: submittedEmail,
      submissionEmail: submissionEmail ?? this.submissionEmail,
    );
  }

  @override
  List<Object?> get props => [
    status,
    submittedEmail,
    submissionEmail,
    rejectionStatus,
  ];
}

/// Submits the accepted consent clip and the parent's email.
///
/// The clip is never discarded here: a failure leaves [videoPath]'s file in
/// place so the same submission can be retried.
class MinorConsentSubmitCubit extends Cubit<MinorConsentSubmitState>
    with CloseGuardedEmit<MinorConsentSubmitState> {
  /// Creates the cubit against [repository].
  ///
  /// [onSubmitted] refreshes the review-status providers after a successful
  /// upload. [onUploadStarted] and [onUploadFinished] bracket the upload so the
  /// owning screen can retain the local clip while it is in flight — they fire
  /// even when that screen has already unmounted, which is exactly the case
  /// where the clip must not be deleted early.
  MinorConsentSubmitCubit({
    required MinorAccountReviewRepository repository,
    required void Function() onSubmitted,
    required ParentConsentSubmission submission,
    void Function()? onUploadStarted,
    void Function()? onUploadFinished,
  }) : _session = submission,
       _repository = repository,
       _onSubmitted = onSubmitted,
       _onUploadStarted = onUploadStarted,
       _onUploadFinished = onUploadFinished,
       super(const MinorConsentSubmitState());

  final ParentConsentSubmission _session;
  final MinorAccountReviewRepository _repository;
  final void Function() _onSubmitted;
  final void Function()? _onUploadStarted;
  final void Function()? _onUploadFinished;

  /// Uploads [videoPath] with [email] against [caseId].
  ///
  /// [localReceipt] carries the localized receipt copy the developer override
  /// writes when a case is being simulated locally; the repository decides
  /// whether that path applies.
  Future<void> submit({
    required String? caseId,
    required String email,
    required String videoPath,
    required MinorReviewInstructions localReceipt,
  }) async {
    if (isClosed ||
        state.status == MinorConsentSubmitStatus.submitting ||
        state.status == MinorConsentSubmitStatus.success) {
      return;
    }
    final submissionEmail = state.canEditEmail
        ? email
        : state.submissionEmail ?? email;
    emit(
      state.copyWith(
        status: MinorConsentSubmitStatus.submitting,
        submissionEmail: submissionEmail,
      ),
    );
    _onUploadStarted?.call();

    try {
      await _repository.submitParentConsent(
        caseId: caseId,
        email: submissionEmail,
        videoPath: videoPath,
        localReceipt: localReceipt,
        submission: _session,
      );
      await _session.dispose();
      _onSubmitted();
      emitIfOpen(
        MinorConsentSubmitState(
          status: MinorConsentSubmitStatus.success,
          submittedEmail: submissionEmail,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      final status = error is ApiException ? error.statusCode : null;
      // A definite client refusal did not accept this body. A timeout or 5xx
      // keeps the original session because the transport may have succeeded.
      final rejected =
          status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429;
      if (rejected) await _session.resetAfterRejection();
      emitIfOpen(
        MinorConsentSubmitState(
          status: MinorConsentSubmitStatus.failure,
          submissionEmail: submissionEmail,
          rejectionStatus: rejected ? status : null,
        ),
      );
    } finally {
      _onUploadFinished?.call();
    }
  }

  @override
  Future<void> close() async {
    await _session.dispose();
    return super.close();
  }
}
