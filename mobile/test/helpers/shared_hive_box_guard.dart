// ABOUTME: Heal-and-blame for the process-global Hive box registry in tests.
// ABOUTME: Guards the #6748 merged-isolate leak class where a suite leaves a
// ABOUTME: box open by name and the next suite inherits its rows.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/constants/hive_box_names.dart';

import 'test_helpers.dart';

/// Every Hive box name the app owns.
///
/// A Hive box is registered process-globally by name, so under
/// `very_good test --optimization` — where the whole unit suite runs in one
/// isolate — a box one suite leaves open is the same box the next suite gets
/// back from `openBox`, rows and backing directory included. That hazard is a
/// property of the name being shared, not of which box it is, so the guard
/// covers the whole set rather than only the box that surfaced it (#6748).
const Set<String> sharedHiveBoxNames = HiveBoxNames.all;

/// How the guard closes and deletes one leaked box. Exists so the guard's own
/// tests can drive the failure path; production callers take the default.
typedef HiveBoxCleanup = Future<void> Function(String boxName);

/// Shared Hive boxes still open at the moment this is called — i.e. a test
/// finished without closing one. Pure: no side effects.
List<String> findSharedHiveBoxViolations() => [
  for (final name in sharedHiveBoxNames)
    if (Hive.isBoxOpen(name)) name,
];

/// After every test (wired as a root `tearDown` in `flutter_test_config.dart`):
/// close and delete every shared Hive box the test left open, so the next suite
/// in the merged isolate starts from an empty one. When [strict] is true, also
/// `fail()` the test that left it.
///
/// During the soak period cleanup always runs but blame is gated by [strict].
/// Hive does not expose opens still pending in its private `_openingBoxes`
/// registry, so unconditional blame could attribute a late open to the test
/// after the actual owner.
Future<void> healAndBlameSharedHiveBoxes({
  required bool strict,
  HiveBoxCleanup cleanup = TestHelpers.cleanupHiveBox,
}) async {
  final violations = findSharedHiveBoxViolations();
  if (violations.isEmpty) return;

  // Heal each box independently. An unguarded `await` here would let the first
  // failing cleanup abandon every box after it — leaking the exact rows this
  // guard exists to purge — and skip the `fail()` below, so the perpetrating
  // test would die with a bare error carrying none of the diagnostic and the
  // next suite would be blamed for the survivor.
  final healFailures = <String>[];
  for (final name in violations) {
    try {
      await cleanup(name);
    } on Object catch (error) {
      healFailures.add('$name ($error)');
    }
  }

  if (!strict) return;

  fail(
    'This test left shared Hive box(es) ${violations.join(', ')} open. Under '
    'very_good --optimization every suite shares one isolate and Hive '
    'registers boxes by name, so the next suite opening the same name gets '
    "this test's box back — rows and backing directory included (#6748). Add "
    'await TestHelpers.cleanupHiveBox(<name>) to the suite tearDown. '
    'See .claude/rules/testing.md (VGV merged isolate).'
    '${healFailures.isEmpty ? '' : ' Cleanup itself then failed for '
              '${healFailures.join('; ')}, so those boxes are still open and the '
              'next suite will inherit them.'}',
  );
}
