part of 'camera_permission_bloc.dart';

/// Permission status for camera and microphone access.
enum CameraPermissionStatus {
  /// Both camera and microphone permissions are granted.
  authorized,

  /// Permissions not yet granted but can request via native OS dialog.
  canRequest,

  /// Permanently denied - user must enable in Settings.
  requiresSettings,
}

/// State for camera permission bloc.
sealed class CameraPermissionState extends Equatable {
  const CameraPermissionState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any permission check.
class CameraPermissionInitial extends CameraPermissionState {
  const CameraPermissionInitial();
}

/// Permission request in progress.
class CameraPermissionLoading extends CameraPermissionState {
  const CameraPermissionLoading();
}

/// Permission status loaded.
class CameraPermissionLoaded extends CameraPermissionState {
  const CameraPermissionLoaded(this.status);

  final CameraPermissionStatus status;

  @override
  List<Object?> get props => [status];
}

/// Error checking or requesting permissions.
class CameraPermissionError extends CameraPermissionState {
  const CameraPermissionError();

  @override
  List<Object?> get props => [];
}
