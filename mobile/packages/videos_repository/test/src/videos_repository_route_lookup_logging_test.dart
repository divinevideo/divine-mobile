// ABOUTME: Pins the per-step diagnostics emitted by the route-id video lookup.
// ABOUTME: A silent null here is undiagnosable in production (see #7892).

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {
  // A live client reports false; an unstubbed mock getter would return null.
  @override
  bool isDisposed = false;
}

const _pubkey =
    'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';

Event _videoEvent({required String id, required String dTag}) =>
    Event.fromJson({
      'id': id,
      'pubkey': _pubkey,
      'created_at': 1765250795,
      'kind': 34236,
      'content': '',
      'sig': 'a' * 128,
      'tags': [
        ['d', dTag],
        ['imeta', 'url https://cdn.divine.video/$dTag.mp4', 'm video/mp4'],
        ['title', 'route lookup fixture'],
      ],
    });

/// Messages captured for this test's unique route id.
List<String> _logsMentioning(String routeId) => LogCaptureService()
    .getRecentLogs()
    .where((e) => e.message.contains(routeId))
    .map((e) => e.message)
    .toList();

/// WARNING-level messages captured for this test's unique route id.
List<String> _warningsMentioning(String routeId) => LogCaptureService()
    .getRecentLogs()
    .where((e) => e.level == LogLevel.warning && e.message.contains(routeId))
    .map((e) => e.message)
    .toList();

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group('route-id lookup diagnostics', () {
    late _MockNostrClient nostr;
    late _MockFunnelcakeApiClient funnelcake;

    setUp(() {
      nostr = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      when(() => nostr.queryEvents(any())).thenAnswer((_) async => []);
      when(() => funnelcake.isAvailable).thenReturn(false);
    });

    VideosRepository build() =>
        VideosRepository(nostrClient: nostr, funnelcakeApiClient: funnelcake);

    test(
      'names every missed source when the route id resolves nowhere',
      () async {
        const dTag =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const routeId = '34236:$_pubkey:$dTag';

        final result = await build().fetchVideoWithStatsForRouteId(routeId);

        expect(result, isNull);
        final logs = _logsMentioning(routeId);
        expect(logs, isNotEmpty, reason: 'lookup failure must be logged');
        final combined = logs.join('\n');
        for (final step in [
          'localCache',
          'relayAddressable',
          'relayStableId',
        ]) {
          expect(
            combined,
            contains(step),
            reason: 'failure log must name the $step step',
          );
        }
      },
    );

    test('names the source that resolved the route id', () async {
      const dTag =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const eventId =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const routeId = '34236:$_pubkey:$dTag';

      when(() => funnelcake.isAvailable).thenReturn(true);
      when(
        () => funnelcake.getVideoEvent(any()),
      ).thenAnswer((_) async => _videoEvent(id: eventId, dTag: dTag));
      when(
        () => funnelcake.getBulkVideoStats(any()),
      ).thenThrow(const FunnelcakeException('no stats'));

      final result = await build().fetchVideoWithStatsForRouteId(routeId);

      expect(result, isNotNull);
      final combined = _logsMentioning(routeId).join('\n');
      expect(
        combined,
        contains('funnelcake'),
        reason: 'success log must name the resolving step',
      );
    });

    test('logs the full route id without truncating it', () async {
      const dTag =
          '4444444444444444444444444444444444444444444444444444444444444444';
      const routeId = '34236:$_pubkey:$dTag';

      await build().fetchVideoWithStatsForRouteId(routeId);

      // Nostr ids are never truncated in logs (repo-wide rule).
      expect(_logsMentioning(routeId).join('\n'), contains(dTag));
    });

    test('logs a route id it cannot parse', () async {
      // parse() only rejects blank input; every other string is treated as a
      // bare d-tag, so blank is the one shape that reaches this branch.
      final result = await build().fetchVideoWithStatsForRouteId('   ');

      expect(result, isNull);
      final parseFailures = LogCaptureService()
          .getRecentLogs()
          .where((e) => e.message.contains('could not parse route id'))
          .toList();
      expect(
        parseFailures,
        isNotEmpty,
        reason: 'an unparseable route id must not fail silently',
      );
    });

    test('does not warn when a fallback route id rescues the lookup', () async {
      const missingId =
          '5555555555555555555555555555555555555555555555555555555555555555';
      const dTag =
          '6666666666666666666666666666666666666666666666666666666666666666';
      const fallbackRouteId = '34236:$_pubkey:$dTag';

      // Only the fallback's d-tag resolves; the primary misses every source.
      when(() => nostr.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments.first as List<Filter>;
        final matches = filters.any((f) => f.d?.contains(dTag) ?? false);
        return matches ? [_videoEvent(id: missingId, dTag: dTag)] : <Event>[];
      });

      final result = await build().fetchVideoWithStatsForRouteId(
        missingId,
        fallbackRouteIds: const [fallbackRouteId],
      );

      expect(result, isNotNull, reason: 'the fallback must rescue the lookup');
      expect(
        _warningsMentioning(missingId),
        isEmpty,
        reason: 'a net-successful lookup must not log a warning',
      );
      expect(
        _logsMentioning(missingId).join('\n'),
        contains('exhausted every source'),
        reason: 'the primary miss stays diagnosable below warning level',
      );
    });

    test('warns once when every candidate fails', () async {
      const missingId =
          '7777777777777777777777777777777777777777777777777777777777777777';
      const dTag =
          '8888888888888888888888888888888888888888888888888888888888888888';
      const fallbackRouteId = '34236:$_pubkey:$dTag';

      final result = await build().fetchVideoWithStatsForRouteId(
        missingId,
        fallbackRouteIds: const [fallbackRouteId],
      );

      expect(result, isNull);
      // Deduped across both candidates: reporting per candidate would leave
      // two distinct warnings for one failed lookup.
      final warnings = {
        ..._warningsMentioning(missingId),
        ..._warningsMentioning(dTag),
      };
      expect(
        warnings,
        hasLength(1),
        reason: 'exhaustion is reported once, after every candidate failed',
      );
      expect(
        warnings.single,
        contains(fallbackRouteId),
        reason: 'the warning must name every candidate it tried',
      );
    });
  });
}
