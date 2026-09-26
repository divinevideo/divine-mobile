/// How aggressively a native player buffers media into memory.
///
/// Each native ExoPlayer keeps its read-ahead buffer on the Java heap, so on
/// memory-constrained Android devices several concurrent players can exhaust
/// the heap and crash with an `OutOfMemoryError` from inside ExoPlayer's load
/// control. The profile lets short-form, many-player surfaces cap that buffer
/// while long-form editing surfaces keep the generous platform defaults.
///
/// Only Android acts on this today; other platforms manage their own
/// buffering and ignore it.
enum VideoBufferProfile {
  /// Short-form feed playback: several players coexist, clips are seconds
  /// long, so each player uses a tightly bounded buffer to protect memory.
  feed,

  /// Editing/preview playback: a single player loads longer or scrubbable
  /// content, so it keeps the platform's default (unbounded) buffering.
  full;

  /// Stable wire value sent across the platform channel.
  String get wireValue => name;
}
