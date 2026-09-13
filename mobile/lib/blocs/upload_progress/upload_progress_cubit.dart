// ABOUTME: Cubit backing UploadProgressDialog — polls an upload manager for
// ABOUTME: progress + status and emits state. Auto-stops polling when the
// ABOUTME: status reaches readyToPublish.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/upload_progress/upload_progress_state.dart';
import 'package:upload_repository/upload_repository.dart'
    show PendingUpload, UploadStatus;

/// Lookup callable hiding the dynamically-typed `UploadManager.getUpload`
/// surface so the Cubit can be tested without standing up a real manager.
typedef UploadLookup = PendingUpload? Function(String uploadId);

/// Cubit backing `UploadProgressDialog`. Polls [pollInterval]ms (default
/// 500ms) via `Timer.periodic`; cancels the timer when the upload reaches
/// [UploadStatus.readyToPublish] so the View's listener can pop the
/// dialog.
class UploadProgressCubit extends Cubit<UploadProgressState> {
  UploadProgressCubit({
    required String uploadId,
    required UploadLookup lookup,
    Duration pollInterval = const Duration(milliseconds: 500),
  }) : _uploadId = uploadId,
       _lookup = lookup,
       _pollInterval = pollInterval,
       super(const UploadProgressState());

  final String _uploadId;
  final UploadLookup _lookup;
  final Duration _pollInterval;
  Timer? _pollTimer;

  /// Start polling. Emits an initial snapshot synchronously.
  void start() {
    _poll();
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _poll() {
    final upload = _lookup(_uploadId);
    if (upload == null) return;
    if (isClosed) return;
    emit(
      state.copyWith(
        progress: upload.uploadProgress ?? 0.0,
        status: upload.status,
      ),
    );
    if (upload.status == UploadStatus.readyToPublish) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Future<void> close() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    return super.close();
  }
}
