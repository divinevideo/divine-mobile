// ABOUTME: Web-safe platform support checks that avoid `dart:io`.
// ABOUTME: Use these helpers from code that is compiled for web as well.

import 'package:flutter/foundation.dart';

/// Whether the app is running natively on Android or iOS.
bool get isNativeMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Whether Firebase Core config can initialize on the current platform.
///
/// This is a coarse platform gate used before touching
/// `DefaultFirebaseOptions.currentPlatform`. Service-specific callers may still
/// need additional checks; for example, app startup keeps Crashlytics gated off
/// on web even though Firebase Core itself supports web.
///
/// Firebase Core supports Android, iOS, macOS, and web. It does NOT support
/// Linux or Windows — `DefaultFirebaseOptions.currentPlatform` throws
/// `UnsupportedError` on those platforms.
///
/// Uses [defaultTargetPlatform] instead of `dart:io`'s `Platform` so the
/// check is safe on web builds.
bool get isFirebaseSupported =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows);

/// Whether the `divine_video_player` plugin has a native implementation on
/// the current platform.
///
/// The plugin only ships native code for Android, iOS, and macOS, so callers
/// must skip native-only startup work on web, Linux, and Windows.
bool get hasNativeVideoPlayer =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.windows;
