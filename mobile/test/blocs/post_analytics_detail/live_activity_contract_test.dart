// ABOUTME: Checks the app against the Live Activity contract fixture shared
// ABOUTME: with the push service and the widget: timings, links and counts.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/post_analytics_detail/post_analytics_detail_cubit.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockPostLiveActivityRepository extends Mock
    implements PostLiveActivityRepository {}

const _fixturePath = 'test/fixtures/live_activity_contract.json';
const _fixtureSha256 =
    '52c18d40f29b4a24458e1fd33a211b86ec1bab96d74f30d1f3de57e072089f55';

const _owner =
    '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
const _videoId =
    'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2';
const _dTag = 'post-d-tag';
const _coordinate = '34236:$_owner:$_dTag';

/// Single-version `ok` update cases in the fixture, including the one whose
/// views lookup fails.
const _drivenCaseCount = 6;

final _postedAt = DateTime.utc(2026, 11, 19, 12);

void main() {
  final raw = File(_fixturePath).readAsBytesSync();
  final fixture = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;

  group('live activity contract', () {
    test('checksum is pinned', () {
      expect(sha256.convert(raw).toString(), _fixtureSha256);
    });

    test('timings match the contract', () {
      final timings = fixture['timings'] as Map<String, dynamic>;
      expect(
        LiveActivityRegistration.settle.inSeconds,
        timings['settleSeconds'],
      );
      expect(
        LiveActivityRegistration.window.inSeconds,
        timings['windowSeconds'],
      );
    });

    group('links', () {
      final links = (fixture['links'] as List).cast<Map<String, dynamic>>();

      test('the fixture has links to check', () {
        expect(links, isNotEmpty);
      });

      test('links parse to their post', () {
        for (final link in links) {
          final parsed = DeepLinkService.parseDeepLink(link['url'] as String);
          expect(parsed.type, DeepLinkType.postAnalytics, reason: '$link');
          expect(parsed.postEventId, link['postEventId'], reason: '$link');
          expect(
            parsed.postCoordinate,
            link['postCoordinate'],
            reason: '$link',
          );
        }
      });
    });

    group('counts', () {
      final all = (fixture['counts'] as List).cast<Map<String, dynamic>>();
      final cases = all.where(_isSingleVersionUpdate).toList();

      test('every single-version update case is driven', () {
        // Pinned so a fixture that shrinks, or a filter that drifts, is
        // noticed rather than silently running fewer cases.
        expect(cases, hasLength(_drivenCaseCount));
      });

      for (final c in cases) {
        test('single-version count case ${c['name']}', () async {
          final version =
              (c['versions'] as List).single as Map<String, dynamic>;
          final fallback = c['viewsFallback'];
          final api = _MockFunnelcakeApiClient();
          when(() => api.isAvailable).thenReturn(true);
          when(() => api.getSocialCounts(any())).thenAnswer((_) async => null);
          when(
            () => api.getVideosByAuthor(
              pubkey: _owner,
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => VideosByAuthorResponse(
              videos: [
                VideoStats(
                  id: _videoId,
                  pubkey: _owner,
                  createdAt: _postedAt,
                  kind: 34236,
                  dTag: _dTag,
                  title: 'My post',
                  thumbnail: 'thumb',
                  videoUrl: 'videoUrl',
                  reactions: 0,
                  comments: 0,
                  reposts: 0,
                  engagementScore: 0,
                ),
              ],
            ),
          );
          // The bulk entry carries the case's own values, views null where
          // the fixture says null, so the app's fallback merge has to run.
          when(() => api.getBulkVideoStats(any())).thenAnswer(
            (_) async => BulkVideoStatsResponse(
              stats: {
                _videoId: BulkVideoStatsEntry(
                  eventId: _videoId,
                  reactions: version['reactions'] as int,
                  comments: version['comments'] as int,
                  reposts: 0,
                  views: version['views'] as int?,
                ),
              },
            ),
          );
          when(() => api.getVideoViewStats(any())).thenAnswer(
            (_) async => fallback == 'failed'
                ? throw const FunnelcakeException('views lookup failed')
                : VideoViewStats(views: fallback as int?),
          );
          final liveActivity = _MockPostLiveActivityRepository();
          when(
            () => liveActivity.postedAtFor(any()),
          ).thenAnswer((_) async => null);
          when(
            () => liveActivity.isRunningFor(any()),
          ).thenAnswer((_) async => false);
          final now = _postedAt.add(
            Duration(seconds: c['secondsSincePosted'] as int),
          );
          final cubit = PostAnalyticsDetailCubit(
            repository: FunnelcakeCreatorAnalyticsRepository(api),
            ownerPubkey: _owner,
            videoId: _videoId,
            coordinate: _coordinate,
            liveActivity: liveActivity,
            now: () => now,
          );
          addTearDown(cubit.close);

          await cubit.load();

          // The server skips a push when the views lookup fails; the app has
          // no skip, so it shows what it knows: views unknown, the rest as
          // the bulk stats gave them (the case is past the settle point, so
          // a zero stays a zero).
          final expected = fallback == 'failed'
              ? {
                  'views': null,
                  'likes': version['reactions'],
                  'comments': version['comments'],
                }
              : c['expected'] as Map<String, dynamic>;
          expect(cubit.state.counts.views, expected['views']);
          expect(cubit.state.counts.likes, expected['likes']);
          expect(cubit.state.counts.comments, expected['comments']);
        });
      }
    });
  });
}

bool _isSingleVersionUpdate(Map<String, dynamic> c) {
  final versions = c['versions'] as List;
  return c['response'] == 'ok' &&
      versions.length == 1 &&
      versions.single is Map &&
      ((c['expected'] as Map)['action'] == 'update' ||
          c['viewsFallback'] == 'failed');
}
