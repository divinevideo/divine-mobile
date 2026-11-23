// ABOUTME: Web-safe platform support checks that avoid `dart:io`.
// ABOUTME: Use these helpers from code that is compiled for web as well.

import 'package:flutter/foundation.dart';

/// Whether the app is running natively on Android or iOS.
bool get isNativeMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Whether this app has a real Firebase project on the current platform.
///
/// Only Android, iOS and macOS do. `DefaultFirebaseOptions.currentPlatform`
/// throws on Linux and returns placeholders on Windows and web; initializing
/// Firebase with the web placeholders loads the Firebase JS SDKs during
/// startup and fails their requests with HTTP 400.
///
/// Uses [defaultTargetPlatform] instead of `dart:io`'s `Platform` so the
/// check is safe on web builds.
bool get isFirebaseSupported =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.windows;

/// Whether the `divine_video_player` plugin has a native implementation on
/// the current platform.
///
/// The plugin only ships native code for Android, iOS, and macOS, so callers
/// must skip native-only startup work on web, Linux, and Windows.
bool get hasNativeVideoPlayer =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.windows;
