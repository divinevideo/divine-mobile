import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';

/// Captures the governed service calls made by consumption UI and blocs.
class RecordingConsumptionAnalytics extends AnalyticsService {
  RecordingConsumptionAnalytics({this.pending, this.failure})
    : super(backgroundActivityManager: BackgroundActivityManager());

  final Future<void>? pending;
  final Object? failure;
  final events = <({String name, Map<String, Object> parameters})>[];
  Iterable<String> get eventNames => events.map((event) => event.name);
  List<Map<String, Object>> get parameters =>
      events.map((event) => event.parameters).toList();

  @override
  Future<String?> recordEngagement({
    required ProductAnalyticsV2EngagementAction action,
    String? contentId,
  }) => _record('engagement_recorded', {
    'action': action.wireName,
    'content_id': ?contentId,
  });

  @override
  Future<String?> recordFeedDepth({
    required String feedSessionId,
    required ProductAnalyticsV2FeedType feedType,
    required int depth,
  }) => _record('feed_depth_recorded', {
    'feed_session_id': feedSessionId,
    'feed_type': feedType.wireName,
    'depth': depth,
  });

  Future<String?> _record(String name, Map<String, Object> parameters) async {
    events.add((name: name, parameters: parameters));
    await pending;
    if (failure case final Object error) throw error;
    return 'recorded';
  }
}
