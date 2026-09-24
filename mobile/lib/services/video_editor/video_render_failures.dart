// ABOUTME: Failure types for video render operations
// ABOUTME: Keeps render error telemetry stable across service refactors

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:openvine/models/video_editor/video_render_failure_reason.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

export 'package:openvine/models/video_editor/video_render_failure_reason.dart';

/// Thrown when a render finished without producing a video.
class VideoRenderFailedException implements Exception {
  const VideoRenderFailedException(this.reason, {this.cause});

  /// Classifies a failure thrown by the native pipeline or while preparing its
  /// local input.
  ///
  /// Out-of-storage failures get their own [reason] so callers can tell the
  /// user what to do; everything else is a [VideoRenderFailureReason.nativeRender]
  /// whose shape is named by [traceValue].
  factory VideoRenderFailedException.native(Object cause) =>
      VideoRenderFailedException(
        nativeRenderFailureLabel(cause) == _diskFullLabel
            ? VideoRenderFailureReason.insufficientStorage
            : VideoRenderFailureReason.nativeRender,
        cause: cause,
      );

  final VideoRenderFailureReason reason;
  final Object? cause;

  /// Compact telemetry label, e.g.
  /// `native_render:video_frame_processing_failed` or
  /// `insufficient_storage:disk_full`, ending in `:hdr` when the plugin
  /// reports an HDR source among the clips the failed render read.
  String get traceValue {
    final cause = this.cause;
    if (cause == null) return reason.traceValue;
    return '${reason.traceValue}:${nativeRenderFailureLabel(cause)}'
        '${_readHdrSource(cause) ? ':hdr' : ''}';
  }

  @override
  String toString() =>
      'VideoRenderFailedException(${reason.traceValue})'
      '${cause == null ? '' : ': $cause'}';
}

const _diskFullLabel = 'disk_full';

/// Whether the failed render read an HDR clip.
///
/// On Android an HDR clip takes its own GPU path, so the same error code can
/// hide two different failures (#9492). Only a render reports its sources,
/// and only on Android.
bool _readHdrSource(Object cause) =>
    cause is PlatformException &&
    (NativeFailureDetails.of(cause)?.hasHdrSource ?? false);

/// Names the shape of a native render failure for telemetry.
///
/// Reads the structured details `pro_video_editor` attaches to a failed job
/// rather than its message: the message is the platform's own description,
/// which AVFoundation localises ("Disk Full" on an English device, "Das
/// Volume ist voll." on a German one) and Media3 reduces to one line per error
/// code. A full disk is `disk_full` on either platform; a Media3 failure is its
/// error code (`video_frame_processing_failed`, `muxing_failed`); the plugin's
/// own stall watchdog is `stalled`; any other Apple failure keeps its domain
/// and code (`AVFoundationErrorDomain(-11828)`). A failure that carries no
/// details — a plugin argument error, or a code the plugin never details —
/// keeps the platform code, and a non-platform cause keeps its type, so a new
/// shape shows up as its own row rather than vanishing into a bucket.
///
/// Never includes the message itself: it can carry a device path (#7125).
String nativeRenderFailureLabel(Object cause) {
  if (cause is RenderEncoderException) {
    return cause.isTransient ? 'codec_exhausted' : 'encoder_unsupported';
  }
  if (cause is FileSystemException && cause.osError?.errorCode == 28) {
    return _diskFullLabel;
  }
  if (cause is! PlatformException) return cause.runtimeType.toString();

  final details = NativeFailureDetails.of(cause);
  if (details == null) return cause.code;
  if (details.isOutOfStorage) return _diskFullLabel;
  if (_isStall(details, cause)) return 'stalled';
  final codeName = details.codeName;
  if (codeName != null) {
    return codeName.replaceFirst(_media3CodePrefix, '').toLowerCase();
  }
  final code = details.code;
  return code == null ? details.domain : '${details.domain}($code)';
}

const _media3CodePrefix = 'ERROR_CODE_';

/// Whether the plugin's own stall watchdog ended the job.
///
/// Apple platforms fail a stalled export in the watchdog's own error domain.
/// Android has no domain of its own for it and throws a plain
/// `IllegalStateException` whose message — the plugin's constant, not the
/// platform's localised text — is the only mark it leaves.
bool _isStall(NativeFailureDetails details, PlatformException cause) =>
    details.domain == 'ExportWatchdog' ||
    (cause.message?.contains('stalled') ?? false);
