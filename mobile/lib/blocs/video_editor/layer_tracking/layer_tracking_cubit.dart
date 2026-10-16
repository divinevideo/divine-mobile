// ABOUTME: Runs object tracking for a layer and holds its progress and its
// ABOUTME: result until the editor pins the layer to the tracked path (#9848).

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/layer_tracking_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException, VideoObjectTrack;
import 'package:unified_logger/unified_logger.dart';

part 'layer_tracking_state.dart';

/// Follows an object through a clip for a layer, one layer at a time.
///
/// The editor's layers stay in the editor: this only reports the path, and
/// the editor turns it into the layer's keyframes once [state] says the
/// object was followed, then calls [resultHandled].
class LayerTrackingCubit extends Cubit<LayerTrackingState>
    with CloseGuardedEmit<LayerTrackingState> {
  LayerTrackingCubit({
    TrackLayerObjectFn? trackObject,
    CancelLayerTrackingFn? cancelTracking,
  }) : _trackObject = trackObject ?? LayerTrackingService.trackObject,
       _cancelTracking = cancelTracking ?? LayerTrackingService.cancel,
       super(const LayerTrackingState());

  static const _logName = 'LayerTrackingCubit';

  final TrackLayerObjectFn _trackObject;
  final CancelLayerTrackingFn _cancelTracking;

  /// Follows the object in [region] (fractions of the frame) of [target]'s
  /// clip for the layer [layerId]. Does nothing while another track runs.
  Future<void> track({
    required String layerId,
    required LayerTrackTarget target,
    required Rect region,
  }) async {
    if (state.isTracking) return;
    emit(
      LayerTrackingState(
        status: LayerTrackingStatus.tracking,
        layerId: layerId,
        target: target,
      ),
    );
    try {
      final track = await _trackObject(
        target: target,
        region: region,
        taskId: LayerTrackingService.taskIdFor(layerId),
        onProgress: (progress) {
          if (state.isTracking && state.layerId == layerId) {
            emitIfOpen(state.copyWith(progress: progress));
          }
        },
      );
      emitIfOpen(
        LayerTrackingState(
          status: track.isFollowed
              ? LayerTrackingStatus.followed
              : LayerTrackingStatus.notFollowed,
          progress: 1,
          layerId: layerId,
          target: target,
          track: track,
        ),
      );
    } on RenderCanceledException {
      emitIfOpen(const LayerTrackingState());
    } on PlatformException catch (error, stackTrace) {
      // The clip could not be decoded: an expected failure of the footage.
      Log.error(
        'Tracking could not read the clip: $error',
        name: _logName,
        category: LogCategory.video,
      );
      addError(error, stackTrace);
      emitIfOpen(_failed(layerId));
    } on VideoRenderFailedException catch (error, stackTrace) {
      // The watchdog gave up; it reported the timeout itself.
      addError(error, stackTrace);
      emitIfOpen(_failed(layerId));
    } catch (error, stackTrace) {
      Log.error(
        'Tracking failed: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      addError(Reportable(error, context: 'track'), stackTrace);
      emitIfOpen(_failed(layerId));
    }
  }

  static LayerTrackingState _failed(String layerId) =>
      LayerTrackingState(status: LayerTrackingStatus.failed, layerId: layerId);

  /// Stops the track that runs now; [state] then goes back to idle.
  Future<void> cancel() async {
    final layerId = state.layerId;
    if (!state.isTracking || layerId == null) return;
    await _cancelTracking(LayerTrackingService.taskIdFor(layerId));
  }

  /// Forgets the last result once the editor applied or reported it.
  void resultHandled() {
    if (state.isTracking || state.status == LayerTrackingStatus.idle) return;
    emit(const LayerTrackingState());
  }

  @override
  Future<void> close() {
    // The decoding and the analysis would run on for a closed editor.
    if (state.isTracking) {
      runDetached(
        cancel(),
        'cancel layer tracking',
        logName: _logName,
        category: LogCategory.video,
      );
    }
    return super.close();
  }
}
