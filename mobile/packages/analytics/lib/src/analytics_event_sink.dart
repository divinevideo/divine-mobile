// ABOUTME: Testable abstraction over analytics event delivery.

abstract interface class AnalyticsEventSink {
  Future<void> setUserId(String? userId);

  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  });

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  });
}

class NoOpAnalyticsEventSink implements AnalyticsEventSink {
  const NoOpAnalyticsEventSink();

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}
