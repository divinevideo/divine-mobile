// ABOUTME: Tests for RelayStatisticsService which tracks per-relay metrics
// ABOUTME: Tests statistics tracking for subscriptions, events, failures, and timing

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/relay_statistics_service.dart';

void main() {
  late RelayStatisticsService service;

  setUp(() {
    service = RelayStatisticsService();
  });

  tearDown(() {
    service.dispose();
  });

  group('RelayStatisticsService', () {
    const testRelay = 'wss://relay.test.com';

    test('initializes with empty statistics', () {
      expect(service.getStatistics(testRelay), isNull);
      expect(service.getAllStatistics(), isEmpty);
    });

    test('records connection event', () {
      service.recordConnection(testRelay);

      final stats = service.getStatistics(testRelay);
      expect(stats, isNotNull);
      expect(stats!.isConnected, isTrue);
      expect(stats.lastConnected, isNotNull);
      expect(stats.connectionCount, equals(1));
    });

    test('records disconnection event', () {
      service.recordConnection(testRelay);
      service.recordDisconnection(testRelay, reason: 'test');

      final stats = service.getStatistics(testRelay);
      expect(stats, isNotNull);
      expect(stats!.isConnected, isFalse);
      expect(stats.lastDisconnected, isNotNull);
      expect(stats.lastDisconnectReason, equals('test'));
    });

    test('records subscription started', () {
      service.recordSubscriptionStarted(testRelay, 'sub_123');

      final stats = service.getStatistics(testRelay);
      expect(stats, isNotNull);
      expect(stats!.activeSubscriptions, equals(1));
      expect(stats.totalSubscriptions, equals(1));
    });

    test('records subscription closed', () {
      service.recordSubscriptionStarted(testRelay, 'sub_123');
      service.recordSubscriptionClosed(testRelay, 'sub_123');

      final stats = service.getStatistics(testRelay);
      expect(stats!.activeSubscriptions, equals(0));
      expect(stats.totalSubscriptions, equals(1));
    });

    test('records event received', () {
      service.recordEventReceived(testRelay);
      service.recordEventReceived(testRelay);
      service.recordEventReceived(testRelay);

      final stats = service.getStatistics(testRelay);
      expect(stats!.eventsReceived, equals(3));
    });

    test('records event sent', () {
      service.recordEventSent(testRelay);
      service.recordEventSent(testRelay);

      final stats = service.getStatistics(testRelay);
      expect(stats!.eventsSent, equals(2));
    });

    test('records request made', () {
      service.recordRequest(testRelay);
      service.recordRequest(testRelay);
      service.recordRequest(testRelay);
      service.recordRequest(testRelay);

      final stats = service.getStatistics(testRelay);
      expect(stats!.requestsThisSession, equals(4));
    });

    test('records request failure', () {
      service.recordRequestFailure(testRelay, 'Connection timeout');

      final stats = service.getStatistics(testRelay);
      expect(stats!.failedRequests, equals(1));
      expect(stats.lastError, equals('Connection timeout'));
      expect(stats.lastErrorTime, isNotNull);
    });

    test('tracks multiple subscriptions correctly', () {
      service.recordSubscriptionStarted(testRelay, 'sub_1');
      service.recordSubscriptionStarted(testRelay, 'sub_2');
      service.recordSubscriptionStarted(testRelay, 'sub_3');
      service.recordSubscriptionClosed(testRelay, 'sub_1');

      final stats = service.getStatistics(testRelay);
      expect(stats!.activeSubscriptions, equals(2));
      expect(stats.totalSubscriptions, equals(3));
    });

    test('maintains separate statistics per relay', () {
      const relay1 = 'wss://relay1.test.com';
      const relay2 = 'wss://relay2.test.com';

      service.recordConnection(relay1);
      service.recordEventReceived(relay1);
      service.recordEventReceived(relay1);

      service.recordConnection(relay2);
      service.recordEventReceived(relay2);
      service.recordRequestFailure(relay2, 'Error');

      final stats1 = service.getStatistics(relay1);
      final stats2 = service.getStatistics(relay2);

      expect(stats1!.eventsReceived, equals(2));
      expect(stats1.failedRequests, equals(0));

      expect(stats2!.eventsReceived, equals(1));
      expect(stats2.failedRequests, equals(1));
    });

    test('getAllStatistics returns all relay statistics', () {
      const relay1 = 'wss://relay1.test.com';
      const relay2 = 'wss://relay2.test.com';

      service.recordConnection(relay1);
      service.recordConnection(relay2);

      final allStats = service.getAllStatistics();
      expect(allStats.length, equals(2));
      expect(allStats.containsKey(relay1), isTrue);
      expect(allStats.containsKey(relay2), isTrue);
    });

    test('reset clears statistics for specific relay', () {
      service.recordConnection(testRelay);
      service.recordEventReceived(testRelay);
      service.resetStatistics(testRelay);

      final stats = service.getStatistics(testRelay);
      expect(stats, isNull);
    });

    test('resetAll clears all statistics', () {
      const relay1 = 'wss://relay1.test.com';
      const relay2 = 'wss://relay2.test.com';

      service.recordConnection(relay1);
      service.recordConnection(relay2);
      service.resetAllStatistics();

      expect(service.getAllStatistics(), isEmpty);
    });

    test('notifies listeners when statistics change', () {
      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      service.recordConnection(testRelay);
      service.recordEventReceived(testRelay);
      service.recordDisconnection(testRelay);

      expect(notificationCount, equals(3));
    });

    test('calculates session duration when connected', () {
      service.recordConnection(testRelay);

      // Wait a small amount to ensure duration is > 0
      final stats = service.getStatistics(testRelay);
      expect(stats!.sessionDuration, isNotNull);
      expect(stats.sessionDuration!.inMicroseconds, greaterThanOrEqualTo(0));
    });
  });
}
