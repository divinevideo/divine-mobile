// ABOUTME: Riverpod provider for whether this build carries the Shorebird
// ABOUTME: updater engine — true only for artifacts built by `shorebird release`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the running build was produced by `shorebird release`.
///
/// Sampled once at startup from the updater `main.dart` constructs for the
/// recovery-critical patch check, and injected into every account container
/// via `DeviceScope.overrides`. A plain `flutter build` or `flutter run
/// --release` has no Shorebird engine and reads `false`, which is what lets
/// `PerformanceMonitoringService` keep local release builds out of the
/// production dataset (#7302).
///
/// Throws by default; `main.dart` overrides it before `runApp`. Reading it
/// before that is a programmer error, not a runtime condition to handle.
final shorebirdAvailableProvider = Provider<bool>(
  (ref) => throw StateError(
    'shorebirdAvailableProvider must be overridden at container creation',
  ),
);
