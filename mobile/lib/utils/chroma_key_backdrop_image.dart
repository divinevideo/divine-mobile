// ABOUTME: Shoots a photo to stand behind a chroma-keyed subject and keeps
// ABOUTME: an upright copy of it in the documents directory.

import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';
import 'package:openvine/utils/image_orientation.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// Shoots a photo for a chroma-key backdrop and returns the path of the copy
/// written for it, or `null` when the user backed out of the camera.
///
/// Camera only, deliberately: the gallery is a route for AI-generated imagery
/// to enter a Divine video, and a backdrop the user photographs on the spot
/// cannot be one.
///
/// `image_picker` hands back a cache path the OS may prune, while clip state
/// persists as a documents-relative basename — so the photo is copied into the
/// documents directory, named after [ownerId]. The copy is normalized rather
/// than byte-for-byte: a photo shot in portrait is stored as landscape pixels
/// plus an EXIF orientation tag, and the renderer decodes raw bytes, so it
/// would show the backdrop rotated. Baking the rotation in also caps the photo
/// to a sane size for a backdrop that is stretched to the video frame anyway.
///
/// The caller owns the returned file and deletes it if nothing ends up using
/// it — no clip, draft or library row points at it yet.
///
/// Throws whatever the picker, the decode or the write throws.
Future<String?> captureChromaKeyBackdropImage({
  required String ownerId,
  ImagePicker? picker,
}) async {
  final picked = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.camera,
  );
  if (picked == null) return null;

  final documentsPath = await getDocumentsPath();
  final target = p.join(
    documentsPath,
    'chroma_bg_${ownerId}_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  final normalized = await compute(
    bakeImageOrientation,
    await File(picked.path).readAsBytes(),
  );
  await File(target).writeAsBytes(normalized, flush: true);
  return target;
}
