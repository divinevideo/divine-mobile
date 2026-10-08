part of 'post_publish_crosspost_cubit.dart';

/// What the post-publish confirmation says about crossposting.
enum PostPublishCrosspostPrompt {
  /// Crossposting settings are still loading; show nothing yet.
  loading,

  /// Nothing worth saying: unavailable, switched off, or failed to load.
  none,

  /// A platform is connected in manual mode: offer to crosspost this video.
  crosspost,

  /// Nothing is connected yet: offer to set crossposting up.
  setUp,

  /// A connected platform posts automatically and none is manual or lapsed:
  /// say so, offer nothing.
  automatic,

  /// A platform still switched on lapsed its authorization: offer to
  /// reconnect it.
  reconnect,
}

class PostPublishCrosspostState extends Equatable {
  const PostPublishCrosspostState({
    this.prompt = PostPublishCrosspostPrompt.loading,
    this.platforms = const [],
    this.connections = const [],
  });

  final PostPublishCrosspostPrompt prompt;

  /// The platforms [prompt] names, in the service's order.
  final List<CrosspostingPlatform> platforms;

  /// The connected manual-mode accounts a
  /// [PostPublishCrosspostPrompt.crosspost] prompt offers; empty otherwise.
  final List<CrosspostingConnection> connections;

  @override
  List<Object?> get props => [prompt, platforms, connections];
}
