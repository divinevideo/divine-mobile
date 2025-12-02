// ABOUTME: Reusable test helpers for widget tests with common provider overrides
// ABOUTME: Reduces boilerplate in widget tests by providing configured ProviderScope

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';

/// Create a mock SharedPreferences with all feature flags set to null
/// Pass in your test-generated MockSharedPreferences instance
dynamic createMockSharedPreferences(dynamic mockPrefs) {
  for (final flag in FeatureFlag.values) {
    when(mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
    when(
      mockPrefs.setBool('ff_${flag.name}', any),
    ).thenAnswer((_) async => true);
    when(mockPrefs.remove('ff_${flag.name}')).thenAnswer((_) async => true);
    when(mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
  }
  return mockPrefs;
}

/// Wrapper for widget tests with common provider overrides
Widget createTestApp({required Widget child, required dynamic mockPrefs}) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}
