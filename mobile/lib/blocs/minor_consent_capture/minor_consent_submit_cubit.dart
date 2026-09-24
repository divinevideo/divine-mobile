// ABOUTME: Cubit owning the confirm-and-submit step of the in-app parent
// ABOUTME: consent flow: uploading the accepted clip and the parent's email.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';

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
  });

  /// Current upload phase.
  final MinorConsentSubmitStatus status;

  /// Email the accepted submission was made with, once it succeeded.
  final String? submittedEmail;

  /// Copy of this state with [status] replaced.
  MinorConsentSubmitState copyWith({MinorConsentSubmitStatus? status}) {
    return MinorConsentSubmitState(
      status: status ?? this.status,
      submittedEmail: submittedEmail,
    );
  }

  @override
  List<Object?> get props => [status, submittedEmail];
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
    void Function()? onUploadStarted,
    void Function()? onUploadFinished,
  }) : _repository = repository,
       _onSubmitted = onSubmitted,
       _onUploadStarted = onUploadStarted,
       _onUploadFinished = onUploadFinished,
       super(const MinorConsentSubmitState());

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
    required String caseId,
    required String email,
    required String videoPath,
    required MinorReviewInstructions localReceipt,
  }) async {
    if (state.status == MinorConsentSubmitStatus.submitting) return;
    emit(state.copyWith(status: MinorConsentSubmitStatus.submitting));
    _onUploadStarted?.call();

    try {
      await _repository.submitParentConsent(
        caseId: caseId,
        email: email,
        videoPath: videoPath,
        localReceipt: localReceipt,
      );
      _onSubmitted();
      emitIfOpen(
        MinorConsentSubmitState(
          status: MinorConsentSubmitStatus.success,
          submittedEmail: email,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: MinorConsentSubmitStatus.failure));
    } finally {
      _onUploadFinished?.call();
    }
  }
}
