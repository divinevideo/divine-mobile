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

/// Shared Hive boxes still open at the moment this is called — i.e. a test
/// finished without closing one. Pure: no side effects.
List<String> findSharedHiveBoxViolations() => [
  for (final name in sharedHiveBoxNames)
    if (Hive.isBoxOpen(name)) name,
];

/// After every test (wired as a root `tearDown` in `flutter_test_config.dart`):
/// close and delete every shared Hive box the test left open, so the next suite
/// in the merged isolate starts from an empty one, and `fail()` the test that
/// left it.
///
/// Unlike the shared-MethodChannel harness this blames unconditionally rather
/// than behind a build flag: a shared box open after a test is never
/// intentional, and a single-file run is exactly where the owning suite can
/// still be identified cheaply. Compliant tests never trip it.
Future<void> healAndBlameSharedHiveBoxes() async {
  final violations = findSharedHiveBoxViolations();
  if (violations.isEmpty) return;
  for (final name in violations) {
    await TestHelpers.cleanupHiveBox(name);
  }
  fail(
    'This test left shared Hive box(es) ${violations.join(', ')} open. Under '
    'very_good --optimization every suite shares one isolate and Hive '
    'registers boxes by name, so the next suite opening the same name gets '
    "this test's box back — rows and backing directory included (#6748). Add "
    'await TestHelpers.cleanupHiveBox(<name>) to the suite tearDown. '
    'See .claude/rules/testing.md (VGV merged isolate).',
  );
}
