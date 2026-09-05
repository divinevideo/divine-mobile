// ABOUTME: State for UploadProgressCubit — current upload progress + status.

import 'package:equatable/equatable.dart';
import 'package:upload_repository/upload_repository.dart';

class UploadProgressState extends Equatable {
  const UploadProgressState({
    this.progress = 0.0,
    this.status = UploadStatus.pending,
  });

  final double progress;
  final UploadStatus status;

  UploadProgressState copyWith({double? progress, UploadStatus? status}) {
    return UploadProgressState(
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [progress, status];
}
