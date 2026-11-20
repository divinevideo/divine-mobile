// ABOUTME: Pauses the recorder's remote record trigger (volume keys, Bluetooth
// ABOUTME: remotes) while a sheet covers the live preview.

import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';

/// Runs [showSheet] with remote record control paused, so a volume key or a
/// Bluetooth remote cannot start a take behind the sheet it shows.
///
/// Read [bloc] before the sheet opens: a take started meanwhile can swap the
/// caller out of the tree, and a lookup then would throw before the pause
/// lifts.
Future<T> showWithRemoteRecordPaused<T>(
  VideoRecorderBloc bloc,
  Future<T> Function() showSheet,
) async {
  bloc.add(const VideoRecorderRemoteRecordPaused());
  try {
    return await showSheet();
  } finally {
    bloc.addIfOpen(const VideoRecorderRemoteRecordResumed());
  }
}
