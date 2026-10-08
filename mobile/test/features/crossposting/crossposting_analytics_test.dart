// ABOUTME: Tests the crossposting CTA analytics helper.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/crossposting/crossposting_analytics.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

class _ThrowingSink implements AnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => throw StateError('nope');

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

void main() {
  group(logCrosspostCtaShown, () {
    test('logs the event with the surface and CTA', () async {
      final sink = _RecordingSink();

      await logCrosspostCtaShown(
        sink,
        surface: CrosspostCtaSurface.settings,
        cta: CrosspostCta.connect,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, equals('crosspost_cta_shown'));
      expect(
        sink.events.single.parameters,
        equals({'surface': 'settings', 'cta': 'connect'}),
      );
    });
  });

  group(CrosspostCtaSurface, () {
    test('names the post-publish surface distinctly', () {
      expect(CrosspostCtaSurface.postPublish.wireName, equals('post_publish'));
      expect(
        CrosspostCtaSurface.values.map((surface) => surface.wireName).toSet(),
        hasLength(CrosspostCtaSurface.values.length),
      );
    });
  });

  group(CrosspostCta, () {
    test('names the post-publish CTAs', () {
      expect(CrosspostCta.crosspostVideo.wireName, equals('crosspost_video'));
      expect(CrosspostCta.reconnect.wireName, equals('reconnect'));
    });
  });

  group(logCrosspostCtaTapped, () {
    test('logs the event with the surface and the CTA', () async {
      final sink = _RecordingSink();

      await logCrosspostCtaTapped(
        sink,
        surface: CrosspostCtaSurface.settings,
        cta: CrosspostCta.automaticMode,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, equals('crosspost_cta_tapped'));
      expect(
        sink.events.single.parameters,
        equals({'surface': 'settings', 'cta': 'automatic_mode'}),
      );
    });

    test('sends the share-sheet surface as share_sheet', () async {
      final sink = _RecordingSink();

      await logCrosspostCtaTapped(
        sink,
        surface: CrosspostCtaSurface.shareSheet,
        cta: CrosspostCta.crosspostRow,
      );

      expect(
        sink.events.single.parameters,
        equals({'surface': 'share_sheet', 'cta': 'crosspost_row'}),
      );
    });

    test('swallows sink failures', () async {
      await expectLater(
        logCrosspostCtaTapped(
          _ThrowingSink(),
          surface: CrosspostCtaSurface.shareSheet,
          cta: CrosspostCta.connect,
        ),
        completes,
      );
    });
  });

  group('connect lifecycle', () {
    test('logs the platform when a connect starts', () async {
      final sink = _RecordingSink();

      await logCrosspostConnectStarted(
        sink,
        platform: CrosspostingPlatform.instagram,
      );

      expect(sink.events.single.name, equals('crosspost_connect_started'));
      expect(
        sink.events.single.parameters,
        equals({'platform': 'instagram'}),
      );
    });

    test('logs the platform and terminal result', () async {
      final sink = _RecordingSink();

      await logCrosspostConnectResult(
        sink,
        platform: CrosspostingPlatform.instagram,
        result: CrosspostConnectResult.connected,
      );

      expect(sink.events.single.name, equals('crosspost_connect_result'));
      expect(
        sink.events.single.parameters,
        equals({'platform': 'instagram', 'result': 'connected'}),
      );
    });
  });
}
