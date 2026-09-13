// ABOUTME: Classifies owned HTTP traffic into a finite set of UX operations.
// ABOUTME: Unknown paths never become telemetry attributes or trace names.

String httpOperation(Uri url) {
  final path = url.pathSegments;
  if (path.length >= 2 && path[0] == 'api') {
    switch (path[1]) {
      case 'delete':
        return 'creator_delete';
      case 'delete-status':
        return 'creator_delete_status';
      case 'search':
        return 'search';
      case 'event':
        return 'event_lookup';
      case 'publish':
        return 'publish';
      case 'videos':
        return 'feed_video';
      case 'users':
        if (path.length > 3 && path[3] == 'notifications') {
          return 'notifications';
        }
        return 'profile_feed';
      case 'v2':
        if (path.length > 2 && path[2] == 'search') return 'search';
        if (path.length > 4 && path[4] == 'comments') return 'comments';
        if (path.length > 2 && path[2] == 'videos') return 'feed_video';
        return 'other';
      case 'featured-tabs':
      case 'leaderboard':
      case 'categories':
      case 'hashtags':
        return 'discovery';
      case 'username':
        return 'username';
    }
  }
  if (path.isNotEmpty && path.first == 'check-result') {
    return 'moderation_lookup';
  }
  // Classify only known hosts; never return an arbitrary subdomain.
  return switch (url.host) {
    'moderation-api.divine.video' => 'moderation_other',
    'login.divine.video' => 'login_signing',
    'names.divine.video' => 'username',
    'media.divine.video' => 'media',
    _ => 'other',
  };
}
