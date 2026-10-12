// ABOUTME: Opens the platform picker for one audio file to import.
// ABOUTME: Android uses the app's own channel, which never loads the file.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/audio_picker_extensions.dart';

/// The `file_selector` picker used off Android; `openFile` by default.
typedef AudioFileOpener = Future<XFile?> Function({
  List<XTypeGroup> acceptedTypeGroups,
});

/// Picks one audio file and returns a readable local copy of it.
///
/// On Android the pick goes through `AudioFilePickerPlugin`, not
/// `file_selector`: `file_selector_android` reads the whole file into the Java
/// heap and sends its bytes over the channel, which crashes the app on a file
/// of a few hundred megabytes (#10065). Every caller only needs the path, so
/// the native side streams the file into the cache instead. Other platforms
/// keep `file_selector`, whose result there carries no bytes.
class AudioFilePickerService {
  const AudioFilePickerService({
    MethodChannel? channel,
    AudioFileOpener fileOpener = openFile,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _fileOpener = fileOpener;

  static const _channelName = 'divine/audio_file_picker';

  final MethodChannel _channel;
  final AudioFileOpener _fileOpener;

  /// Opens the picker on the formats of [audioPickerTypeGroup].
  ///
  /// [typeGroupLabel] names the filter on platforms that show one. Returns
  /// null when the user cancels.
  ///
  /// Throws a [PlatformException] when the picked file cannot be copied.
  Future<XFile?> pickAudioFile({required String typeGroupLabel}) async {
    final typeGroup = audioPickerTypeGroup(label: typeGroupLabel);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _fileOpener(acceptedTypeGroups: [typeGroup]);
    }

    final path = await _channel.invokeMethod<String>('pickAudioFile', {
      'mimeTypes': typeGroup.mimeTypes,
      'extensions': typeGroup.extensions,
      'initialUri': androidAudioPickerInitialUri,
    });
    // The copy is named like `file_selector` names it, so `XFile.name` (the
    // path's last segment) carries the type and title callers read.
    return path == null || path.isEmpty ? null : XFile(path);
  }
}
