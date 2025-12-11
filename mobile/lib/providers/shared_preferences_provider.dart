// ABOUTME: Canonical SharedPreferences provider for the entire application
// ABOUTME: All code should use this provider rather than calling SharedPreferences.getInstance() directly

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical SharedPreferences provider for the application.
///
/// This provider MUST be overridden in ProviderScope during app initialization
/// with a pre-initialized SharedPreferences instance from main.dart.
///
/// Usage:
/// ```dart
/// // In providers/services that need SharedPreferences:
/// final prefs = ref.watch(sharedPreferencesProvider);
///
/// // In main.dart:
/// final sharedPreferences = await SharedPreferences.getInstance();
/// runApp(
///   ProviderScope(
///     overrides: [
///       sharedPreferencesProvider.overrideWithValue(sharedPreferences),
///     ],
///     child: const MyApp(),
///   ),
/// );
/// ```
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope with a '
    'pre-initialized SharedPreferences instance. See main.dart for the '
    'correct initialization pattern.',
  );
});
