import 'dart:io'
    if (dart.library.js_interop) 'package:openvine/utils/platform_io_web.dart'
    as io;

/// `ENOSPC`, the errno for "No space left on device" on Android, iOS and
/// macOS.
const _noSpaceLeftOnDevice = 28;

/// Whether [error] is a file operation that failed because the device has no
/// storage left.
bool isDiskFullFileSystemError(Object error) =>
    error is io.FileSystemException &&
    error.osError?.errorCode == _noSpaceLeftOnDevice;
