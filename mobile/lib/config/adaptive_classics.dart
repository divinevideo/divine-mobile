// ABOUTME: Build switch for adaptive Classics recommendations.
// ABOUTME: One definition so every call site agrees on the default.

/// Whether Classics reads the private recommendation endpoint and adapts to
/// viewing feedback. Off restores the archive-only Classics feed and grid.
///
/// Opt in with `--dart-define=ADAPTIVE_CLASSICS_ENABLED=true`.
const bool adaptiveClassicsEnabled = bool.fromEnvironment(
  'ADAPTIVE_CLASSICS_ENABLED',
  defaultValue: false,
);
