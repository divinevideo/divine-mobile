// ABOUTME: Central entry point for opening app-owned Hive boxes.
// ABOUTME: Lets the merged test harness observe opens before Hive mutates its registry.

import 'package:hive_ce/hive.dart';

/// Intercepts an app-owned Hive box open without changing its result.
abstract interface class HiveBoxOpenObserver {
  Future<T> observe<T>(String boxName, Future<T> Function() open);
}

/// Opens app-owned Hive boxes through the test harness's optional observer.
abstract final class HiveBoxOpener {
  /// Test-only process hook installed by `flutter_test_config.dart`.
  ///
  /// Production leaves this null, so an open pays only one null check before
  /// delegating directly to Hive.
  static HiveBoxOpenObserver? observerForTesting;

  static Future<Box<E>> open<E>(String name, {String? path}) {
    Future<Box<E>> open() => Hive.openBox<E>(name, path: path);
    return observerForTesting?.observe(name, open) ?? open();
  }

  static Future<LazyBox<E>> openLazy<E>(String name, {String? path}) {
    Future<LazyBox<E>> open() => Hive.openLazyBox<E>(name, path: path);
    return observerForTesting?.observe(name, open) ?? open();
  }
}
