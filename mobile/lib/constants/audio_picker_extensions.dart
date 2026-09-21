// ABOUTME: The file types the audio file pickers offer.
// ABOUTME: Shared by the editor's import row and the standalone sound upload.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// Extensions the audio file pickers offer.
///
/// A subset of what `LocalAudioImportService` accepts, chosen for the
/// platform pickers: `weba` is unknown to Android's `MimeTypeMap` and `webm`
/// maps to `video/webm`, which would list every video, so both are left
/// out. A file with either extension arriving by another route is still
/// accepted by the import service.
const audioPickerExtensions = ['aac', 'm4a', 'mp3', 'wav'];

/// The type group every audio picker passes to `openFile`.
///
/// `file_selector` rather than `file_picker`: on Android the latter (10.x)
/// sends `EXTRA_MIME_TYPES` as a `String` for `FileType.audio`, which the
/// system picker reads as "accept everything" and opens on images, and drops
/// the filter to `*/*` outright when any custom extension is unmapped.
/// `file_selector` sends a proper `String[]`, so `audio/*` holds. iOS needs
/// the UTI, desktop the extensions.
XTypeGroup audioPickerTypeGroup({required String label}) => XTypeGroup(
  label: label,
  extensions: audioPickerExtensions,
  mimeTypes: const ['audio/*'],
  uniformTypeIdentifiers: const ['public.audio'],
);

/// Where the Android document picker opens: the device's audio library
/// (MediaStore's audio root, grouped by artist).
///
/// Left to itself the picker opens on "Recent", which under an audio-only
/// filter is usually empty — the user's music was not modified this week —
/// and reads as "no audio on this phone" until they find the Audio root in
/// the drawer. `EXTRA_INITIAL_URI` skips that. Other platforms take a
/// filesystem path here, so it is Android-only.
const androidAudioPickerInitialUri =
    'content://com.android.providers.media.documents/root/audio_root';

/// The `initialDirectory` for `openFile`: the audio root on Android, none
/// elsewhere.
String? audioPickerInitialDirectory() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? androidAudioPickerInitialUri
    : null;
