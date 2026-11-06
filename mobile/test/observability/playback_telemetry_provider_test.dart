import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/playback_telemetry_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _Analytics extends Mock implements AnalyticsService {}

class _Nip98 extends Mock implements Nip98AuthService {}

class _Cohort extends Notifier<bool> {
  @override
  bool build() => true;

  void withdraw() => state = false;
}

final _cohortProvider = NotifierProvider<_Cohort, bool>(_Cohort.new);

class _Environment extends CurrentEnvironmentNotifier {
  @override
  EnvironmentConfig build() => EnvironmentConfig.production;

  void change() =>
      state = const EnvironmentConfig(environment: AppEnvironment.staging);
}

class _TrackingClient extends MockClient {
  _TrackingClient(super.fn);

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _DeliveryFixture {
  _DeliveryFixture(Future<http.Response> Function(http.Request) handler) {
    when(() => analytics.initializedAnalyticsConsent)
        .thenAnswer((_) => consent);
    when(() => analytics.privacyChanges).thenAnswer((_) => changes.stream);
    container = ProviderContainer(
      overrides: [
        isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary).overrideWith(
          (ref) => ref.watch(_cohortProvider),
        ),
        analyticsServiceProvider.overrideWithValue(analytics),
        currentEnvironmentProvider.overrideWith(_Environment.new),
        nip98AuthServiceProvider.overrideWithValue(_Nip98()),
        instrumentedHttpClientFactoryProvider.overrideWithValue(() {
          final client = _TrackingClient(handler);
          clients.add(client);
          return client;
        }),
      ],
    );
    ownership = container.listen(playbackTelemetryProvider, (_, _) {});
  }

  final analytics = _Analytics();
  final changes = StreamController<void>.broadcast(sync: true);
  bool consent = true;
  final clients = <_TrackingClient>[];
  _TrackingClient get client => clients.last;
  late final ProviderContainer container;
  late final ProviderSubscription<void> ownership;

  void event() => FeedFirstFrameMetrics.start(
    videoId: 'synthetic',
    index: 0,
  ).finish(outcome: FeedPlaybackOutcome.cancelled);

  Future<void> dispose() async {
    container.dispose();
    await changes.close();
  }
}

void main() {
  tearDown(() => FeedPlaybackTelemetry.configure(enabled: false));

  group('playbackTelemetryProvider', () {
    testWidgets('resume after an idle pause creates a fresh owned client', (
      tester,
    ) async {
      var requests = 0;
      final fixture = _DeliveryFixture((_) async {
        requests++;
        return http.Response('{"accepted":true}', 202);
      });
      addTearDown(fixture.dispose);
      fixture.event();
      fixture.ownership.pause();
      await tester.pump();
      await tester.pump();
      expect(requests, 1);
      expect(fixture.client.closed, isTrue);
      fixture.ownership.resume();
      await tester.pump();
      expect(fixture.clients, hasLength(2));
      expect(fixture.client.closed, isFalse);
      expect(FeedPlaybackTelemetry.startLoad(), isNotNull);
      fixture.event();
      fixture.ownership.pause();
      await tester.pump();
      await tester.pump();
      expect(requests, 2);
      expect(fixture.clients.every((client) => client.closed), isTrue);
      fixture.ownership.close();
      fixture.container.dispose();
    });

    testWidgets('resume during delivery preserves queued rows and one client', (
      tester,
    ) async {
      final first = Completer<http.Response>();
      final requests = <http.Request>[];
      final fixture = _DeliveryFixture((request) async {
        requests.add(request);
        if (requests.length == 1) return first.future;
        return http.Response('{"accepted":true}', 202);
      });
      addTearDown(fixture.dispose);
      fixture.event();
      fixture.ownership.pause();
      await tester.pump();
      expect(requests, hasLength(1));
      fixture.ownership.resume();
      await tester.pump();
      fixture.event();
      fixture.ownership.pause();
      first.complete(http.Response('{"accepted":true}', 202));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(requests, hasLength(2));
      expect(fixture.clients, hasLength(1));
      expect(fixture.client.closed, isTrue);
      fixture.ownership.close();
      fixture.container.dispose();
    });

    testWidgets('drains a queued row behind an in-flight row before closing', (
      tester,
    ) async {
      final first = Completer<http.Response>();
      final requests = <http.Request>[];
      final fixture = _DeliveryFixture((request) async {
        requests.add(request);
        if (requests.length == 1) return first.future;
        return http.Response('{"accepted":true}', 202);
      });
      addTearDown(fixture.dispose);
      fixture.event();
      await tester.pump(const Duration(seconds: 5));
      expect(requests, hasLength(1));
      fixture.event();
      fixture.ownership.close();
      await tester.pump();
      expect(fixture.client.closed, isFalse);
      first.complete(http.Response('{"accepted":true}', 202));
      await tester.pump();
      expect(fixture.client.closed, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(requests, hasLength(2));
      final firstEvent =
          (jsonDecode(requests[0].body) as Map)['events'] as List;
      final secondEvent =
          (jsonDecode(requests[1].body) as Map)['events'] as List;
      expect(firstEvent, hasLength(1));
      expect(secondEvent, hasLength(1));
      expect(
        secondEvent.single['attempt_id'],
        isNot(firstEvent.single['attempt_id']),
      );
      expect(fixture.client.closed, isTrue);
      expect(fixture.changes.hasListener, isFalse);
    });

    for (final boundary in ['consent', 'account', 'cohort', 'environment']) {
      testWidgets(
        '$boundary withdrawal while paused drops queued and retry rows',
        (
          tester,
        ) async {
          final first = Completer<http.Response>();
          var requests = 0;
          final fixture = _DeliveryFixture((request) async {
            requests++;
            return first.future;
          });
          addTearDown(fixture.dispose);
          fixture.event();
          await tester.pump(const Duration(seconds: 5));
          expect(requests, 1);
          fixture.event();
          final load = FeedPlaybackTelemetry.startLoad()!;
          fixture.ownership.pause();
          expect(load.isCurrent, isFalse);
          switch (boundary) {
            case 'consent':
              fixture.consent = false;
              fixture.changes.add(null);
            case 'account':
              fixture.changes.add(null);
            case 'cohort':
              fixture.container.read(_cohortProvider.notifier).withdraw();
            case 'environment':
              (fixture.container.read(
                currentEnvironmentProvider.notifier,
              ) as _Environment).change();
          }
          await tester.pump();
          first.complete(http.Response('', 503));
          await tester.pump();
          await tester.pump(const Duration(seconds: 20));
          expect(requests, 1);
          expect(FeedPlaybackTelemetry.startLoad(), isNull);
          expect(fixture.client.closed, isTrue);
          expect(fixture.changes.hasListener, isFalse);
          fixture.ownership.close();
          await tester.pump();
          fixture.container.dispose();
        },
      );
    }

    testWidgets('throwing HTTP adapter drains within the retry bound', (
      tester,
    ) async {
      var requests = 0;
      final fixture = _DeliveryFixture((_) async {
        requests++;
        throw StateError('synthetic adapter failure');
      });
      addTearDown(fixture.dispose);
      fixture.event();
      fixture.ownership.close();
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      expect(requests, 3);
      expect(fixture.client.closed, isTrue);
      expect(fixture.changes.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    });

    for (final pause in [true, false]) {
      testWidgets(
        'delivers terminal event after ${pause ? 'pause' : 'unmount'}',
        (
          tester,
        ) async {
          final changes = StreamController<void>.broadcast(sync: true);
          addTearDown(changes.close);
          final analytics = _Analytics();
          when(() => analytics.initializedAnalyticsConsent).thenReturn(true);
          when(() => analytics.privacyChanges)
              .thenAnswer((_) => changes.stream);
          final requests = <http.Request>[];
          final container = ProviderContainer(
            overrides: [
              isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)
                  .overrideWithValue(true),
              analyticsServiceProvider.overrideWithValue(analytics),
              nip98AuthServiceProvider.overrideWithValue(_Nip98()),
              instrumentedHttpClientFactoryProvider.overrideWithValue(
                () => MockClient((request) async {
                  requests.add(request);
                  return http.Response('{"accepted":true}', 202);
                }),
              ),
            ],
          );
          addTearDown(container.dispose);
          final ownership = container.listen(
            playbackTelemetryProvider,
            (_, _) {},
          );
          FeedFirstFrameMetrics.start(
            videoId: 'synthetic',
            index: 0,
          ).finish(outcome: FeedPlaybackOutcome.cancelled);
          if (pause) {
            ownership.pause();
          } else {
            ownership.close();
          }
          await tester.pump();
          await tester.pump(const Duration(seconds: 5));
          expect(requests, hasLength(1));
          expect(requests.single.body, contains('cancelled'));
          expect(FeedPlaybackTelemetry.startLoad(), isNull);
          if (pause) ownership.close();
          await tester.pump();
          container.dispose();
        },
      );
    }

    test(
      'off-cohort feeds do not construct analytics or HTTP dependencies',
      () {
        final container = ProviderContainer(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)
                .overrideWithValue(false),
            analyticsServiceProvider.overrideWith(
              (_) => throw StateError('analytics constructed'),
            ),
            nip98AuthServiceProvider.overrideWith(
              (_) => throw StateError('signing constructed'),
            ),
            instrumentedHttpClientFactoryProvider.overrideWith(
              (_) => throw StateError('HTTP constructed'),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          () => container.read(playbackTelemetryProvider),
          returnsNormally,
        );
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
      },
    );

    test(
      'mounted ownership enforces consent, suspension and last-feed disposal',
      () async {
        final changes = StreamController<void>.broadcast(sync: true);
        addTearDown(changes.close);
        var consent = true;
        final analytics = _Analytics();
        when(() => analytics.initializedAnalyticsConsent)
            .thenAnswer((_) => consent);
        when(() => analytics.privacyChanges).thenAnswer((_) => changes.stream);
        final container = ProviderContainer(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)
                .overrideWithValue(true),
            analyticsServiceProvider.overrideWithValue(analytics),
            nip98AuthServiceProvider.overrideWithValue(_Nip98()),
            instrumentedHttpClientFactoryProvider.overrideWithValue(
              () => MockClient((_) => throw StateError('unexpected request')),
            ),
          ],
        );
        addTearDown(container.dispose);
        final ownership = container.listen(
          playbackTelemetryProvider,
          (_, _) {},
        );
        final beforeWithdrawal = FeedPlaybackTelemetry.startLoad()!;
        consent = false;
        changes.add(null);
        expect(beforeWithdrawal.isCurrent, isFalse);
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
        consent = true;
        changes.add(null);
        final beforeSuspension = FeedPlaybackTelemetry.startLoad()!;
        ownership.pause();
        expect(beforeSuspension.isCurrent, isFalse);
        changes.add(null);
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
        ownership.resume();
        await container.pump();
        final beforeDisposal = FeedPlaybackTelemetry.startLoad()!;
        ownership.close();
        await container.pump();
        expect(beforeDisposal.isCurrent, isFalse);
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
      },
    );
  });
}
