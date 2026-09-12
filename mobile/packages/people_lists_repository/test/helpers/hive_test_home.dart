// ABOUTME: Owns Hive's process-global home path for package tests.
// ABOUTME: Guarantees each override is cleared after its test completes.

import 'package:hive_ce/hive_ce.dart';
import 'package:test/test.dart';

void setHiveTestHome(String path) {
  Hive.init(path);
  addTearDown(() => Hive.init(null));
}
