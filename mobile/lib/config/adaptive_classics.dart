// ABOUTME: Build switch and per-account gate for adaptive Classics.
// ABOUTME: One definition so every call site agrees on when it is active.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/provider_identity_stream.dart';

/// Whether this build ships Adaptive Classics, which reads the private
/// recommendation endpoint and adapts to viewing feedback.
///
/// On by default. Build with `--dart-define=ADAPTIVE_CLASSICS_ENABLED=false`
/// to restore the archive-only Classics feed and grid. The Funnelcake
/// `CLASSIC_RECOMMENDATIONS_ENABLED` flag is the operational off switch:
/// when it is off the endpoint fails and the app falls back to the archive.
const bool adaptiveClassicsEnabled = bool.fromEnvironment(
  'ADAPTIVE_CLASSICS_ENABLED',
  defaultValue: true,
);

/// Whether Adaptive Classics is active for the current account.
///
/// Requires the build switch and a fresh, authenticated confirmation that the
/// account is not a protected minor. Protected, pending, unknown and
/// unavailable status stay on the archive path. Usage-data consent separately
/// gates the viewer identity and feedback each request carries.
final adaptiveClassicsEnabledProvider = Provider<bool>((ref) {
  if (!adaptiveClassicsEnabled) return false;
  return ref.watch(confirmedNotProtectedMinorProvider);
});

/// Seeded stream of [adaptiveClassicsEnabledProvider] transitions so Home's
/// [VideoFeedBloc] can attach or detach its adaptive Classics session when
/// protected-minor status resolves or changes, without resetting the feed.
final Provider<Stream<bool>> adaptiveClassicsEnabledStreamProvider =
    identityStreamOf<bool>(adaptiveClassicsEnabledProvider);
