import 'package:analytics/analytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  group(FirebaseAnalyticsEventSink, () {
    late FirebaseAnalytics analytics;
    late FirebaseAnalyticsEventSink sink;

    setUp(() {
      analytics = _MockFirebaseAnalytics();
      sink = FirebaseAnalyticsEventSink(analytics: analytics);
    });

    test(
      'forwards user IDs to Firebase Analytics without transforming them',
      () async {
        const pubkeyHex =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        when(() => analytics.setUserId(id: pubkeyHex)).thenAnswer((_) async {});

        await sink.setUserId(pubkeyHex);

        verify(() => analytics.setUserId(id: pubkeyHex)).called(1);
      },
    );

    test('clears the Firebase Analytics user ID', () async {
      when(() => analytics.setUserId()).thenAnswer((_) async {});

      await sink.setUserId(null);

      verify(() => analytics.setUserId()).called(1);
    });

    test('turns Firebase collection off at the SDK level', () async {
      // The consent gate has to sit at the SDK, not at each call site: the
      // trackers hold their own sinks and know nothing about consent.
      when(
        () => analytics.setAnalyticsCollectionEnabled(false),
      ).thenAnswer((_) async {});

      await sink.setCollectionEnabled(enabled: false);

      verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    });

    test('turns Firebase collection back on', () async {
      when(
        () => analytics.setAnalyticsCollectionEnabled(true),
      ).thenAnswer((_) async {});

      await sink.setCollectionEnabled(enabled: true);

      verify(() => analytics.setAnalyticsCollectionEnabled(true)).called(1);
    });

    test('clears the accumulated Firebase analytics identity', () async {
      when(analytics.resetAnalyticsData).thenAnswer((_) async {});

      await sink.resetAnalyticsData();

      verify(analytics.resetAnalyticsData).called(1);
    });

    test('forwards custom events to Firebase Analytics', () async {
      const parameters = <String, Object>{
        'surface_name': 'comments_sheet',
        'total_ms': 3250,
      };
      when(
        () => analytics.logEvent(name: 'surface_load', parameters: parameters),
      ).thenAnswer((_) async {});

      await sink.logEvent(name: 'surface_load', parameters: parameters);

      verify(
        () => analytics.logEvent(name: 'surface_load', parameters: parameters),
      ).called(1);
    });

    test('forwards screen views to Firebase Analytics', () async {
      const parameters = <String, Object>{
        'route_name': 'video',
        'entry_point': 'navigation',
      };
      when(
        () => analytics.logScreenView(
          screenName: 'video_detail',
          screenClass: 'Route',
          parameters: parameters,
        ),
      ).thenAnswer((_) async {});

      await sink.logScreenView(
        screenName: 'video_detail',
        screenClass: 'Route',
        parameters: parameters,
      );

      verify(
        () => analytics.logScreenView(
          screenName: 'video_detail',
          screenClass: 'Route',
          parameters: parameters,
        ),
      ).called(1);
    });
  });
}
