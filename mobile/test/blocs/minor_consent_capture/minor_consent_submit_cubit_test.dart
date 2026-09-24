// ABOUTME: Tests for MinorConsentSubmitCubit, which uploads the accepted
// ABOUTME: consent clip and drives the confirm-and-submit pane's state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_submit_cubit.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';

const _receipt = MinorReviewInstructions(
  title: 'Received',
  body: 'We have your video.',
);

class _FakeRepository implements MinorAccountReviewRepository {
  Object? failWith;
  Completer<void>? gate;

  String? submittedCaseId;
  String? submittedEmail;
  String? submittedVideoPath;
  MinorReviewInstructions? submittedReceipt;
  int submitCount = 0;

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
  }) async {
    submitCount++;
    await gate?.future;
    final error = failWith;
    if (error != null) throw error;
    submittedCaseId = caseId;
    submittedEmail = email;
    submittedVideoPath = videoPath;
    submittedReceipt = localReceipt;
  }
}

MinorConsentSubmitCubit _buildCubit(
  _FakeRepository repository, {
  void Function()? onSubmitted,
  void Function()? onUploadStarted,
  void Function()? onUploadFinished,
}) {
  return MinorConsentSubmitCubit(
    repository: repository,
    onSubmitted: onSubmitted ?? () {},
    onUploadStarted: onUploadStarted,
    onUploadFinished: onUploadFinished,
  );
}

Future<void> _submit(MinorConsentSubmitCubit cubit) => cubit.submit(
  caseId: 'case-1',
  email: 'parent@example.com',
  videoPath: '/tmp/consent.mp4',
  localReceipt: _receipt,
);

void main() {
  group(MinorConsentSubmitCubit, () {
    group('submit', () {
      test('forwards the clip and email, then reports success', () async {
        final repository = _FakeRepository();
        final cubit = _buildCubit(repository);

        expect(cubit.state.status, MinorConsentSubmitStatus.editing);
        await _submit(cubit);

        expect(repository.submittedCaseId, 'case-1');
        expect(repository.submittedEmail, 'parent@example.com');
        expect(repository.submittedVideoPath, '/tmp/consent.mp4');
        expect(repository.submittedReceipt, _receipt);
        expect(cubit.state.status, MinorConsentSubmitStatus.success);
        expect(cubit.state.submittedEmail, 'parent@example.com');
        await cubit.close();
      });

      test('refreshes the review status only after a success', () async {
        final repository = _FakeRepository()..failWith = Exception('nope');
        var refreshes = 0;
        final cubit = _buildCubit(repository, onSubmitted: () => refreshes++);

        await _submit(cubit);
        expect(cubit.state.status, MinorConsentSubmitStatus.failure);
        expect(refreshes, 0);

        repository.failWith = null;
        await _submit(cubit);

        expect(cubit.state.status, MinorConsentSubmitStatus.success);
        expect(refreshes, 1);
        await cubit.close();
      });

      test('a failure keeps the same clip submittable on retry', () async {
        final repository = _FakeRepository()..failWith = Exception('offline');
        final cubit = _buildCubit(repository);

        await _submit(cubit);
        expect(cubit.state.status, MinorConsentSubmitStatus.failure);
        expect(cubit.state.submittedEmail, isNull);

        repository.failWith = null;
        await _submit(cubit);

        expect(repository.submittedVideoPath, '/tmp/consent.mp4');
        expect(cubit.state.status, MinorConsentSubmitStatus.success);
        await cubit.close();
      });

      test('brackets the upload for the clip-retention owner', () async {
        final repository = _FakeRepository()..failWith = Exception('offline');
        final events = <String>[];
        final cubit = _buildCubit(
          repository,
          onUploadStarted: () => events.add('start'),
          onUploadFinished: () => events.add('finish'),
        );

        await _submit(cubit);

        // Reported even though the upload failed, so a screen that unmounted
        // mid-upload can stop retaining the clip.
        expect(events, ['start', 'finish']);
        await cubit.close();
      });

      test('drops a second submit while one is in flight', () async {
        final repository = _FakeRepository()..gate = Completer<void>();
        final cubit = _buildCubit(repository);

        final first = _submit(cubit);
        await pumpEventQueue();
        expect(cubit.state.status, MinorConsentSubmitStatus.submitting);

        await _submit(cubit);
        expect(repository.submitCount, 1);

        repository.gate!.complete();
        await first;

        expect(cubit.state.status, MinorConsentSubmitStatus.success);
        await cubit.close();
      });

      test('a submit that returns after close does not throw', () async {
        final repository = _FakeRepository()..gate = Completer<void>();
        final cubit = _buildCubit(repository);

        final pending = _submit(cubit);
        await pumpEventQueue();
        await cubit.close();

        repository.gate!.complete();

        await expectLater(pending, completes);
      });
    });
  });
}
