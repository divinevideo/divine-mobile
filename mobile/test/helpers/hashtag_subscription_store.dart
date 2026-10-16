// ABOUTME: Injectable hashtag persistence fixture shared across test shards.
// ABOUTME: Lives outside test suites so CI pruning cannot remove an import.
import 'dart:async';

import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';

class TestStore implements HashtagSubscriptionStore {
  String? value;
  bool fail = false;
  Completer<void>? readGate;
  Completer<void>? gate;
  @override
  Future<String?> read() async {
    await readGate?.future;
    return value;
  }

  @override
  Future<void> write(String value) async {
    await gate?.future;
    if (fail) throw Exception('failed');
    this.value = value;
  }
}
