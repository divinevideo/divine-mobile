// ABOUTME: File naming and error text shared by what the video DM store keeps,
// ABOUTME: so no name leaves its folder and no logged error carries a path.

import 'dart:io';

/// [value] reduced to its letters and digits, to name a kept file or folder:
/// a message id or a pubkey can then not reach outside its folder.
String dmVideoSafeName(String value) =>
    value.replaceAll(RegExp('[^A-Za-z0-9]'), '');

/// What went wrong with a kept file, without its path: file names carry the
/// account's pubkey and the message id.
String dmVideoFileErrorCause(FileSystemException error) =>
    error.osError?.toString() ?? 'no OS error';
