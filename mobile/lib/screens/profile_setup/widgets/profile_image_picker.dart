import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether the host is a desktop OS for image-picker routing.
///
/// Always returns false on web — `defaultTargetPlatform` reports the host OS
/// in a desktop browser, but a browser is not desktop for picker-routing
/// purposes (no real filesystem access).
bool isDesktopImagePickerPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Picks a single image, returning the picker's [XFile] without resolving it
/// to a `dart:io File`.
///
/// The returned XFile may have a blob-URL `path` on web; callers must use
/// [XFile.readAsBytes] there rather than constructing a `File`. On native
/// desktop gallery picks, `file_selector` is used for a richer file-type
/// filter UX; everything else goes through `image_picker`.
Future<XFile?> pickProfileXFile(
  ImageSource source,
  ImagePicker picker,
  BuildContext context,
) async {
  if (!kIsWeb &&
      source == ImageSource.gallery &&
      isDesktopImagePickerPlatform()) {
    return _pickXFileFromDesktop(context);
  }

  try {
    return await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  } catch (e) {
    Log.error(
      'image_picker error: $e',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    rethrow;
  }
}

/// A picker result that has been checked for content and resolved into a
/// source the crop editor can decode.
///
/// Exactly one of [file] / [bytes] is set: native picks stay a file, web picks
/// are read eagerly because the blob URL can be revoked once the picker is
/// left behind.
@immutable
class ProfileImageSelection {
  /// Wraps a native file that exists and holds at least one byte.
  const ProfileImageSelection.file(File this.file) : bytes = null;

  /// Wraps non-empty bytes read from a web blob.
  const ProfileImageSelection.bytes(Uint8List this.bytes) : file = null;

  /// The native source file, or `null` on web.
  final File? file;

  /// The web blob's bytes, or `null` on native.
  final Uint8List? bytes;
}

/// Validates [picked] and resolves it into a crop-editor source.
///
/// Returns `null` when the picker handed back nothing usable — a missing file,
/// a zero-byte file (iOS occasionally returns an empty temporary JPEG), an
/// empty web blob, or an I/O failure while checking. Callers must surface a
/// recoverable selection failure instead: the crop editor decodes its source
/// through image providers, so an empty source throws "file is empty" and
/// "invalid image data" as fatal errors before the user can crop anything.
Future<ProfileImageSelection?> resolveProfileImageSelection(
  XFile picked,
) async {
  try {
    if (kIsWeb) {
      // Read the blob here — its URL can be revoked once we navigate away.
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _logEmptySelection();
        return null;
      }
      return ProfileImageSelection.bytes(bytes);
    }

    final file = File(picked.path);
    // Sync stat: one syscall on a local temp file, and it keeps the check off
    // the event loop. It throws PathNotFoundException when the picker's
    // temporary file is already gone, which lands in the rejection below.
    if (file.lengthSync() == 0) {
      _logEmptySelection();
      return null;
    }
    return ProfileImageSelection.file(file);
  } on PathNotFoundException {
    _logEmptySelection();
    return null;
  } catch (e) {
    // The message stays free of the path: it names a user's temporary file.
    Log.error(
      'Could not read the picked image (${e.runtimeType})',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    return null;
  }
}

/// Tells the user their pick could not be used and points at the URL sheet.
///
/// Shared by the avatar and banner flows so a rejected pick never looks like a
/// silent no-op on either surface.
void showProfileImageSelectionFailed(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      context.l10n.profileSetupImageSelectionFailed,
      error: true,
      duration: const Duration(seconds: 5),
      actionLabel: context.l10n.profileSetupGotItButton,
      onActionPressed: () {},
    ),
  );
}

void _logEmptySelection() {
  Log.warning(
    'Picked image is missing or empty; not opening the crop editor',
    name: 'ProfileSetupScreen',
    category: LogCategory.ui,
  );
}

Future<XFile?> _pickXFileFromDesktop(BuildContext context) async {
  try {
    Log.info(
      '🖥️ Starting desktop file picker...',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );

    final typeGroup = XTypeGroup(
      label: context.l10n.profileSetupImagesTypeGroup,
      extensions: const <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (file == null) {
      Log.info(
        '❌ Desktop file picker: User cancelled or no file selected',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      return null;
    }

    Log.info(
      '✅ Desktop file selected: ${file.name}',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    return file;
  } catch (e) {
    Log.error(
      'Desktop file picker error: $e',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    rethrow;
  }
}
