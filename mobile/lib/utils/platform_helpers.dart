// ABOUTME: Platform detection helpers for consistent desktop/mobile checks.
// ABOUTME: Centralizes platform logic to avoid scattered inline checks.

import 'package:flutter/foundation.dart';

/// Whether the current platform is a desktop OS (macOS, Windows, or Linux).
///
/// Returns `false` on web regardless of the underlying OS. Reads
/// [defaultTargetPlatform] rather than `dart:io`, so a widget test runs as the
/// platform it emulates, not the machine it runs on.
bool get isDesktopPlatform =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
