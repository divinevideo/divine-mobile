// ABOUTME: Shared go_router page-name resolution for analytics route settings.
// ABOUTME: Keeps ShellRoute pages from falling back to unknown_route.

import 'package:go_router/go_router.dart';

/// Returns the stable page name go_router would put on a regular [GoRoute].
///
/// Shell route states do not receive [GoRouterState.name] or
/// [GoRouterState.path], so fall back to the matched leaf route exposed through
/// [GoRouterState.topRoute].
String? goRouterPageName(GoRouterState state) {
  final explicitName = _nonEmpty(state.name);
  if (explicitName != null) return explicitName;

  return _shellSurfaceNameForPath(state.path) ??
      _nonEmpty(state.topRoute?.name) ??
      _shellSurfaceNameForPath(state.topRoute?.path) ??
      _shellSurfaceNameForPath(state.fullPath) ??
      _shellSurfaceNameForPath(state.uri.path) ??
      _nonEmpty(state.path) ??
      _nonEmpty(state.fullPath);
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}

String? _shellSurfaceNameForPath(String? path) {
  final candidate = _nonEmpty(path);
  if (candidate == null) return null;

  final pathOnly = Uri.tryParse(candidate)?.path ?? candidate;
  final segments = pathOnly.split('/').where((s) => s.isNotEmpty);
  final firstSegment = segments.isEmpty ? null : segments.first;
  return switch (firstSegment) {
    'home' => 'home',
    'explore' => 'explore',
    'notifications' => 'notifications',
    'inbox' => 'inbox',
    'profile' => 'profile',
    _ => null,
  };
}
