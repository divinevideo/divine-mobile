// ABOUTME: Unit tests for UploadProgressCubit — polling, progress emit,
// ABOUTME: auto-stop on readyToPublish.

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/upload_progress/upload_progress_cubit.dart';
import 'package:openvine/blocs/upload_progress/upload_progress_state.dart';
import 'package:upload_repository/upload_repository.dart';

void main() {
  group(UploadProgressCubit, () {
    PendingUpload fakeUpload({
      double progress = 0.0,
      UploadStatus status = UploadStatus.pending,
    }) {
      return PendingUpload(
        id: 'u1',
        localVideoPath: '/tmp/v.mp4',
        nostrPubkey: 'pk',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        status: status,
        uploadProgress: progress,
      );
    }

    test('polls and emits progress + status', () {
      fakeAsync((async) {
        var progress = 0.0;
        var status = UploadStatus.pending;
        final cubit = UploadProgressCubit(
          uploadId: 'u1',
          lookup: (id) => id == 'u1'
              ? fakeUpload(progress: progress, status: status)
              : null,
          pollInterval: const Duration(milliseconds: 100),
        )..start();

        async.elapse(Duration.zero);
        expect(cubit.state.progress, 0.0);

        progress = 0.5;
        async.elapse(const Duration(milliseconds: 100));
        expect(cubit.state.progress, 0.5);

        progress = 1.0;
        status = UploadStatus.readyToPublish;
        async.elapse(const Duration(milliseconds: 100));
        expect(cubit.state.status, UploadStatus.readyToPublish);
        expect(cubit.state.progress, 1.0);

        // Polling should now be stopped. Further elapses don't change state.
        final lastState = cubit.state;
        async.elapse(const Duration(milliseconds: 500));
        expect(cubit.state, lastState);

        cubit.close();
      });
    });

    blocTest<UploadProgressCubit, UploadProgressState>(
      'start with unknown upload id is a no-op (no emit)',
      build: () => UploadProgressCubit(
        uploadId: 'missing',
        lookup: (_) => null,
        pollInterval: const Duration(seconds: 1),
      ),
      act: (cubit) => cubit.start(),
      expect: () => const <UploadProgressState>[],
    );
  });
}
