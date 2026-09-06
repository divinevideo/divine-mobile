// ABOUTME: Test configuration file that sets up app-wide plugin mocks.
// ABOUTME: Loads deterministic fonts and opts golden tests into Alchemist setup.

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';

import 'helpers/shared_channel_override.dart';
import 'helpers/shared_hive_box_guard.dart';
import 'test_setup.dart';

const _runGoldenSetup = bool.fromEnvironment('DIVINE_GOLDEN_TESTS');

/// When set (via `--dart-define=DIVINE_STRICT_CHANNELS=true`), the
/// heal-and-blame tearDown also `fail()`s the test that leaked a shared
/// channel. Mobile CI and `mise run test` both set it — the suite was proven
/// clean under it, which was the condition for turning it on (#5738). It stays
/// off for a bare `flutter test` so a single-file run still heals silently.
const _strictChannels = bool.fromEnvironment('DIVINE_STRICT_CHANNELS');

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up test environment with plugin mocks (secure_storage, path_provider, etc.)
  setupTestEnvironment();

  if (!kIsWeb) {
    // ThemeData captures defaultTargetPlatform when it is built, while these
    // app themes are lazy process-cached values. Build both at flutter_test's
    // Android baseline before a test-scoped platform override can permanently
    // determine page transitions for every later test in the merged isolate.
    final _ = VineTheme.theme;
    final _ = VineTheme.lightTheme;

    // google_fonts registers bundled faces asynchronously. Preload every
    // variant used by VineTheme before testMain so the first test selected by
    // a shard ordering seed measures the same glyphs as later tests (#8485).
    VineTheme.bodyLargeFont();
    VineTheme.labelSmallFont();
    VineTheme.headlineMediumFont();
    VineTheme.titleLargeFont();
    VineTheme.codeFont();
    await GoogleFonts.pendingFonts();

    // loadAppFonts permanently registers bundled faces, including Roboto under
    // its bare family name. Do this once before the merged test isolate starts
    // so font metrics cannot depend on which suite runs first (#8649).
    await loadAppFonts();
  }

  // Under `very_good test --optimization` the whole unit suite runs in one
  // isolate and flutter_test auto-restores nothing, so a test that replaces a
  // shared MethodChannel handler without restoring it strands every later
  // suite (#5738). This root tearDown runs after every test in the bundle
  // (inner group/file tearDowns first), heals any shared channel that drifted
  // from its canonical handler, and — under DIVINE_STRICT_CHANNELS — blames
  // the perpetrating test. Compliant tests never trip it.
  tearDown(() => healAndBlameSharedChannels(strict: _strictChannels));

  // Hive registers boxes process-globally by name, so a box one suite leaves
  // open is the same box the next suite gets back from openBox — rows and
  // backing directory included (#6748). This root tearDown closes and deletes
  // any shared box a test left open and blames that test.
  tearDown(healAndBlameSharedHiveBoxes);

  // UserAvatar records broken image URLs in a process-global negative cache.
  // In the merged optimizer isolate that state would otherwise leak a failed
  // URL into a later test that expects the same avatar to load. Reset it after
  // every test so avatar failure caching stays test-local.
  tearDown(AvatarFailureCache.instance.clear);

  // Web / `flutter test --platform chrome`: skip Alchemist. Alchemist and the
  // font loading guarded above can both stall headless Chrome with almost no
  // CPU while `loading ...` is shown.
  if (kIsWeb || !_runGoldenSetup) {
    return testMain();
  }

  // Golden runs opt in to Alchemist with:
  //   flutter test -D DIVINE_GOLDEN_TESTS=true test/goldens/
  // Configure Alchemist for better golden test output
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      // Platform variants to test
      platformGoldensConfig: PlatformGoldensConfig(),
      // CI-specific configuration
      ciGoldensConfig: CiGoldensConfig(),
    ),
    run: testMain,
  );
}
