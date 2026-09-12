// ABOUTME: Pre-navigation camera permission check for camera routes
// ABOUTME: Fires the native permission dialog on the current page

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Bumped by every camera permission request so a stale flow — one left
/// awaiting a hung native `request()` — can't navigate once a newer camera tap
/// has superseded it. Only the latest generation is allowed to act on its
/// result.
int _cameraRequestGeneration = 0;

/// Extension for camera navigation with pre-flight permission check.
extension CameraPermissionNavigation on BuildContext {
  /// Resolves camera/microphone permission and navigates to
  /// [VideoRecorderScreen] once it makes sense to.
  ///
  /// A still-requestable permission triggers the native OS dialog *on the
  /// current page* — no pre-navigation screen or loading page. Navigation
  /// happens only for a terminal status: [CameraPermissionStatus.authorized]
  /// opens the camera and [CameraPermissionStatus.requiresSettings] lands on
  /// the gate's settings prompt. A denial — including a dialog dismissed with
  /// the back button — keeps the user here so the next camera tap re-prompts.
  ///
  /// Returns `true` if navigation occurred.
  Future<bool> pushToCameraWithPermission({
    String entryPoint = CreationEntryPoint.cameraFab,
  }) async {
    final bloc = read<CameraPermissionBloc>();
    final recorderPath = VideoRecorderScreen.pathForEntryPoint(entryPoint);

    if (kIsWeb) {
      await pushWithVideoPause(recorderPath);
      return true;
    }

    final resolved = await _resolveStatus(bloc);
    if (!mounted) return false;

    if (resolved == CameraPermissionStatus.canRequest) {
      // Fire the native dialog while still on the current page.
      final requested = await _requestPermission(bloc);
      if (!mounted) return false;
      // Denied-but-requestable, or superseded by a newer tap → stay put so the
      // next camera tap re-prompts.
      if (requested != CameraPermissionStatus.authorized &&
          requested != CameraPermissionStatus.requiresSettings) {
        return false;
      }
    }

    // Navigate for a terminal status (authorized opens the camera,
    // requiresSettings shows the settings prompt) or when the entry check
    // couldn't settle (`resolved == null`: an errored/stalled pre-nav check) so
    // the gate surfaces its Error + Retry screen instead of dead-waiting here.
    await pushWithVideoPause(recorderPath);
    return true;
  }
}

/// Reads the [CameraPermissionStatus] from a bloc state, or `null` when the
/// state carries no status (initial/loading/error).
CameraPermissionStatus? _statusOf(CameraPermissionState state) =>
    state is CameraPermissionLoaded ? state.status : null;

/// Returns the current permission status, forcing a fresh (non-hanging) status
/// check when the bloc isn't already sitting on a settled
/// [CameraPermissionLoaded] — e.g. after a previous request left it stuck in
/// [CameraPermissionLoading]. The status check never triggers the OS dialog,
/// so it can't hang the way a request can.
Future<CameraPermissionStatus?> _resolveStatus(
  CameraPermissionBloc bloc,
) async {
  final current = bloc.state;
  if (current is CameraPermissionLoaded) return current.status;

  bloc.add(const CameraPermissionRefresh());
  final settled = await bloc.stream
      .firstWhere(
        (s) => s is CameraPermissionLoaded || s is CameraPermissionError,
      )
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => const CameraPermissionError(),
      );
  return _statusOf(settled);
}

/// Dispatches the permission request and resolves to the resulting status.
///
/// The request is `restartable()`, so this tap supersedes any prior in-flight
/// request (a back-dismissed dialog can leave one hung). Only the latest
/// generation acts on its result, so a stale awaiting flow can't navigate
/// after a newer tap took over.
Future<CameraPermissionStatus?> _requestPermission(
  CameraPermissionBloc bloc,
) async {
  final generation = ++_cameraRequestGeneration;
  bloc.add(const CameraPermissionRequest());
  final result = await bloc.stream
      .firstWhere(
        (s) => s is CameraPermissionLoaded || s is CameraPermissionError,
      )
      .timeout(
        const Duration(seconds: 30),
        onTimeout: () => const CameraPermissionError(),
      );
  if (generation != _cameraRequestGeneration) return null;
  return _statusOf(result);
}
