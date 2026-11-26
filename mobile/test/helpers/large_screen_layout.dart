// ABOUTME: Test setup for the large-screen layouts: a test window of a given
// ABOUTME: width and an app with the Large Screen Layout flag on or off

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:riverpod/misc.dart' show Override;

/// Lays the test window out [width] × [height] logical pixels wide for the
/// rest of the test.
void setTestWindowSize(
  WidgetTester tester,
  double width, {
  double height = 900,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A localized app showing [home] under an [AdaptiveLayoutScope] with the
/// large-screen layouts [enabled] or not, as the app mounts it.
///
/// [overrides] are added to the flag's own override.
Widget largeScreenLayoutApp({
  required bool enabled,
  required Widget home,
  List<Override> overrides = const [],
  ThemeData? theme,
}) => ProviderScope(
  overrides: [
    isFeatureEnabledProvider(
      FeatureFlag.largeScreenLayout,
    ).overrideWithValue(enabled),
    ...overrides,
  ],
  child: MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    builder: (context, child) => AdaptiveLayoutScope(
      child: DivineSnackbarTheme(child: child!),
    ),
    home: home,
  ),
);
