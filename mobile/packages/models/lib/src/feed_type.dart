// ABOUTME: Defines different types of infinite scroll video feeds in the app
// ABOUTME: Used to distinguish between trending, popular, and other feed types

/// Types of infinite scroll video feeds
enum FeedType {
  trending('trending', 'Trending Now', 'Popular videos right now'),
  popularNow('popular_now', 'Popular Now', 'Videos gaining popularity'),
  recent('recent', 'Recent', 'Latest videos from the network');

  const FeedType(this.id, this.displayName, this.description);

  final String id;
  final String displayName;
  final String description;
}
