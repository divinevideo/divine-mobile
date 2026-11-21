import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:infinite_video_feed/infinite_video_feed.dart';

/// Shares bounded selection requests across native feeds for this lifetime.
final bunnyPlaybackSelectorProvider = Provider<BunnyPlaybackSelector>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return BunnyPlaybackSelector(client: client);
});
