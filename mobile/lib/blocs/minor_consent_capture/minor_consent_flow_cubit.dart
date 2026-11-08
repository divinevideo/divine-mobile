// ABOUTME: Permission recovery and clip ownership for the consent flow.
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:unified_logger/unified_logger.dart';

/// Native permission result translated at the UI boundary.
enum ConsentPermission {
  loading,
  error,
  authorized,
  canRequest,
  requiresSettings,
}

/// Observable permission, camera and accepted-clip state.
class MinorConsentFlowState extends Equatable {
  const MinorConsentFlowState({
    this.cameraReady = false,
    this.accessDenied = false,
    this.requiresSettings = false,
    this.autoRequested = false,
    this.requestAfterRefresh = false,
    this.wasInBackground = false,
    this.initializingCamera = false,
    this.videoPath,
    this.accepted = false,
    this.uploadInFlight = false,
    this.disposed = false,
  });

  final bool cameraReady;
  final bool accessDenied;
  final bool requiresSettings;
  final bool autoRequested;
  final bool requestAfterRefresh;
  final bool wasInBackground;
  final bool initializingCamera;
  final String? videoPath;
  final bool accepted;
  final bool uploadInFlight;
  final bool disposed;

  MinorConsentFlowState copyWith({
    bool? cameraReady,
    bool? accessDenied,
    bool? requiresSettings,
    bool? autoRequested,
    bool? requestAfterRefresh,
    bool? wasInBackground,
    bool? initializingCamera,
    String? videoPath,
    bool? accepted,
    bool? uploadInFlight,
    bool? disposed,
  }) => MinorConsentFlowState(
    cameraReady: cameraReady ?? this.cameraReady,
    accessDenied: accessDenied ?? this.accessDenied,
    requiresSettings: requiresSettings ?? this.requiresSettings,
    autoRequested: autoRequested ?? this.autoRequested,
    requestAfterRefresh: requestAfterRefresh ?? this.requestAfterRefresh,
    wasInBackground: wasInBackground ?? this.wasInBackground,
    initializingCamera: initializingCamera ?? this.initializingCamera,
    videoPath: videoPath ?? this.videoPath,
    accepted: accepted ?? this.accepted,
    uploadInFlight: uploadInFlight ?? this.uploadInFlight,
    disposed: disposed ?? this.disposed,
  );

  @override
  List<Object?> get props => [
    cameraReady,
    accessDenied,
    requiresSettings,
    autoRequested,
    requestAfterRefresh,
    wasInBackground,
    initializingCamera,
    videoPath,
    accepted,
    uploadInFlight,
    disposed,
  ];
}

/// Owns the clip until the form and any outstanding upload have finished.
class MinorConsentFlowCubit extends Cubit<MinorConsentFlowState> {
  MinorConsentFlowCubit({
    required Future<void> Function() initializeCamera,
    required Future<void> Function() releaseCamera,
    required Future<void> Function(String) deleteClip,
    required void Function() refreshPermissions,
    required void Function() requestPermissions,
  }) : _initializeCamera = initializeCamera,
       _releaseCamera = releaseCamera,
       _deleteClip = deleteClip,
       _refreshPermissions = refreshPermissions,
       _requestPermissions = requestPermissions,
       super(const MinorConsentFlowState());

  final Future<void> Function() _initializeCamera;
  final Future<void> Function() _releaseCamera;
  final Future<void> Function(String) _deleteClip;
  final void Function() _refreshPermissions;
  final void Function() _requestPermissions;

  void permissionChanged(ConsentPermission permission) {
    if (isClosed) return;
    final requestAfterRefresh = state.requestAfterRefresh;
    switch (permission) {
      case ConsentPermission.loading || ConsentPermission.error:
        emit(state.copyWith(accessDenied: true));
      case ConsentPermission.authorized:
        emit(
          state.copyWith(
            accessDenied: false,
            requiresSettings: false,
            requestAfterRefresh: false,
          ),
        );
        unawaited(initialize());
      case ConsentPermission.canRequest:
        emit(
          state.copyWith(requiresSettings: false, requestAfterRefresh: false),
        );
        if (!state.autoRequested || requestAfterRefresh) {
          emit(state.copyWith(autoRequested: true));
          _requestPermissions();
        } else {
          emit(state.copyWith(accessDenied: true));
        }
      case ConsentPermission.requiresSettings:
        emit(
          state.copyWith(
            accessDenied: true,
            requiresSettings: true,
            requestAfterRefresh: false,
          ),
        );
    }
  }

  Future<void> initialize() async {
    if (isClosed || state.cameraReady || state.initializingCamera) return;
    emit(state.copyWith(initializingCamera: true));
    try {
      await _initializeCamera();
      if (!isClosed) emit(state.copyWith(cameraReady: true));
    } catch (error, stack) {
      addError(error, stack);
      if (!isClosed) emit(state.copyWith(accessDenied: true));
    } finally {
      if (!isClosed) emit(state.copyWith(initializingCamera: false));
    }
  }

  void retryPermissions({required bool canRequest}) {
    if (isClosed) return;
    if (canRequest) {
      _requestPermissions();
    } else {
      emit(state.copyWith(requestAfterRefresh: true));
      _refreshPermissions();
    }
  }

  void visibilityChanged({required bool background, required bool resumed}) {
    if (isClosed) return;
    if (background) emit(state.copyWith(wasInBackground: true));
    if (resumed && state.wasInBackground) {
      emit(state.copyWith(wasInBackground: false));
      if (state.accessDenied) _refreshPermissions();
    }
  }

  void recorded(String path) {
    if (!isClosed) emit(state.copyWith(videoPath: path));
  }

  Future<void> accept(String path) async {
    recorded(path);
    try {
      await _releaseCamera();
    } catch (error, stack) {
      addError(error, stack);
    }
    if (!isClosed) emit(state.copyWith(accepted: true));
  }

  void uploadStarted() {
    if (!isClosed) emit(state.copyWith(uploadInFlight: true));
  }

  void uploadFinished() {
    if (isClosed) {
      unawaited(_discard());
    } else {
      emit(state.copyWith(uploadInFlight: false));
    }
  }

  Future<void> _discard() async {
    final path = state.videoPath;
    if (path == null) return;
    try {
      await _deleteClip(path);
    } catch (_) {
      Log.warning(
        'Could not remove private consent recording',
        name: 'MinorConsentFlowCubit',
      );
    }
  }

  @override
  Future<void> close() async {
    emit(state.copyWith(disposed: true));
    if (!state.uploadInFlight) await _discard();
    await super.close();
  }
}
