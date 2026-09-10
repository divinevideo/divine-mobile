// ABOUTME: State provider for version tap counter
// ABOUTME: Tracks taps to unlock developer mode (7 taps)

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_mode_tap_provider.g.dart';

@riverpod
class DeveloperModeTapCounter extends _$DeveloperModeTapCounter {
  Timer? _resetTimer;

  @override
  int build() {
    // Clean up timer when provider is disposed
    ref.onDispose(() {
      _resetTimer?.cancel();
    });
    return 0;
  }

  /// Increments the counter and returns the updated tap count.
  int tap() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      state = 0;
    });
    state++;
    return state;
  }

  void reset() {
    _resetTimer?.cancel();
    state = 0;
  }
}
