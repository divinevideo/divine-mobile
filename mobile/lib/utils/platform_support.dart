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
/// Firebase is configured for Android, iOS, and macOS only. Linux and Windows
/// have no configured Firebase app (`DefaultFirebaseOptions.currentPlatform`
/// throws on Linux and holds placeholders on Windows), and `DefaultFirebaseOptions.web`
/// likewise holds placeholder credentials — initializing it on web only pulls
/// four Firebase JS SDKs during blocking startup and triggers failing HTTP 400
/// requests on every navigation.
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
