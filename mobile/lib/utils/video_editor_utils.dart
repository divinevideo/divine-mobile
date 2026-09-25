/// Extension on Duration for video editor time formatting.
extension VideoEditorTimeUtils on Duration {
  /// Formats duration as SS:CS (seconds:centiseconds).
  ///
  /// Example: Duration(seconds: 5, milliseconds: 730) → "05:73"
  String toVideoTime() {
    final seconds = inSeconds.toString().padLeft(2, '0');
    final milliseconds = (inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$seconds:$milliseconds';
  }

  /// Formats duration as seconds with 2 decimal places.
  ///
  /// Example: Duration(seconds: 5, milliseconds: 730) → "5.73"
  String toFormattedSeconds() {
    return (inMilliseconds / 1000).toStringAsFixed(2);
  }

  /// Formats duration as MM:SS.
  ///
  /// Example: Duration(minutes: 1, seconds: 5) → "01:05"
  String toMmSs() {
    final mins = inMinutes.toString().padLeft(2, '0');
    final secs = (inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

/// Extension on [num] for converting seconds to formatted time strings.
extension SecondsFormatting on num {
  /// Converts a value in seconds to a MM:SS string.
  ///
  /// Example: `65.3.toMmSs()` → "01:05"
  String toMmSs() {
    return Duration(milliseconds: (this * 1000).round()).toMmSs();
  }
}
