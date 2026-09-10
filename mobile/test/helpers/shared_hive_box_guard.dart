// ABOUTME: Heal-and-blame for the process-global Hive box registry in tests.
// ABOUTME: Guards the #6748 merged-isolate leak class where a suite leaves a
// ABOUTME: box open by name and the next suite inherits its rows.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/services/hive_box_opener.dart';

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

const _pendingOpenTimeout = Duration(seconds: 1);

/// One app-owned Hive open that has not settled yet.
final class PendingHiveBoxOpen {
  const PendingHiveBoxOpen({required this.boxName, required this.future});

  final String boxName;
  final Future<Object?> future;
}

final class _PendingHiveOpenTimeout implements Exception {
  const _PendingHiveOpenTimeout();
}

/// Runs Hive opens outside `testWidgets` fake async and records them until they
/// settle, giving root teardown visibility into Hive's otherwise-private
/// opening registry.
final class SharedHiveBoxOpenObserver implements HiveBoxOpenObserver {
  SharedHiveBoxOpenObserver(this._realAsyncZone);

  final Zone _realAsyncZone;
  final Map<Object, PendingHiveBoxOpen> _pending = {};

  List<PendingHiveBoxOpen> get pending => List.unmodifiable(_pending.values);

  @override
  Future<T> observe<T>(String boxName, Future<T> Function() open) {
    final operation = Object();
    final future = _realAsyncZone.run(open);
    _pending[operation] = PendingHiveBoxOpen(boxName: boxName, future: future);
    unawaited(
      future.then<void>(
        (_) {
          _pending.remove(operation);
        },
        onError: (Object _, StackTrace _) {
          _pending.remove(operation);
        },
      ),
    );
    return future;
  }
}

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
/// App-owned opens are observable through [SharedHiveBoxOpenObserver]. Cleanup
/// always runs, while attribution is gated by [strict]. A pending operation
/// that cannot be healed still fails in soak mode so later tests cannot receive
/// a misleading timeout.
Future<void> healAndBlameSharedHiveBoxes({
  required bool strict,
  SharedHiveBoxOpenObserver? openObserver,
  Duration pendingOpenTimeout = _pendingOpenTimeout,
  HiveBoxCleanup cleanup = TestHelpers.cleanupHiveBox,
}) async {
  final pendingAtTeardown = openObserver?.pending ?? const [];
  final timedOut = <String>[];
  for (final pending in pendingAtTeardown) {
    try {
      await pending.future.timeout(
        pendingOpenTimeout,
        onTimeout: () => throw const _PendingHiveOpenTimeout(),
      );
    } on _PendingHiveOpenTimeout {
      timedOut.add(pending.boxName);
    } on Object {
      // The production caller owns the open error. For the harness, settlement
      // is enough: Hive has removed the operation from its opening registry.
    }
  }

  final violations = findSharedHiveBoxViolations();
  if (violations.isEmpty && pendingAtTeardown.isEmpty) return;

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

  if (!strict && timedOut.isEmpty) return;

  final pendingNames = pendingAtTeardown.map((open) => open.boxName).toSet();

  fail(
    'This test started shared Hive box open(s) '
    '${pendingNames.isEmpty ? 'none' : pendingNames.join(', ')} that were still '
    'pending at teardown, or left fully-open box(es) '
    '${violations.isEmpty ? 'none' : violations.join(', ')}. Under '
    'very_good --optimization every suite shares one isolate and Hive '
    'registers both opening and open boxes by name, so the next suite can '
    'inherit rows or wait forever on this test (#9053). Await initialization '
    'and close the box, or replace the production provider in this test. '
    'See .claude/rules/testing.md (VGV merged isolate).'
    '${timedOut.isEmpty ? '' : ' Open(s) ${timedOut.join(', ')} did not settle '
              'within ${pendingOpenTimeout.inMilliseconds}ms; the harness did '
              'not mutate Hive private state, so stop this merged run.'}'
    '${healFailures.isEmpty ? '' : ' Cleanup itself then failed for '
              '${healFailures.join('; ')}, so those boxes are still open and the '
              'next suite will inherit them.'}',
  );
}
