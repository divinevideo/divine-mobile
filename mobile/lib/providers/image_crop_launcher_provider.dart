import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';

/// Signature of the function that launches the crop editor and resolves to the
/// cropped JPEG bytes (or `null` when cancelled).
typedef ImageCropLauncher = Future<Uint8List?> Function(
  BuildContext context, {
  required ImageCropKind kind,
  File? file,
  Uint8List? bytes,
});

/// Injectable seam for [showImageCropEditor].
///
/// Picker widgets read the launcher from here instead of calling
/// [showImageCropEditor] directly, so widget tests can override it with a fake
/// that returns canned bytes / `null` without pumping the real editor (which
/// needs a decodable image).
final imageCropLauncherProvider = Provider<ImageCropLauncher>(
  (ref) => showImageCropEditor,
);
