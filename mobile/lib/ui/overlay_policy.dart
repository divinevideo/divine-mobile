// ABOUTME: Injectable policy for controlling video overlay visibility in tests
// ABOUTME: Allows tests to force overlays on/off while preserving production auto behavior

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverlayPolicy { auto, alwaysOn, alwaysOff }

final overlayPolicyProvider = Provider<OverlayPolicy>(
  (_) => OverlayPolicy.auto,
);
