/// The step of the post flow a Live Activity is showing.
enum LiveActivityPhase {
  /// The post is being published.
  posting,

  /// The post is published and live.
  live,

  /// The published post could not be found.
  notFound,

  /// The closing summary is showing.
  summary,
}
