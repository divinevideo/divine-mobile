// ABOUTME: Tests for the video routes' recorder builder and engagement paths.
// ABOUTME: Pins recorder query parsing and the flat engagement registration.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

import '../../helpers/l10n.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

/// Minimal state for the engagement builder: it reads only the `eventId`
/// path parameter and the query.
class _EngagementState extends Fake implements GoRouterState {
  _EngagementState(this._eventId, [String query = ''])
    : uri = Uri.parse(
        '/video/${Uri.encodeComponent(_eventId)}/likers'
        '${query.isEmpty ? '' : '?$query'}',
      );

  final String _eventId;

  @override
  final Uri uri;

  @override
  Map<String, String> get pathParameters => {'eventId': _eventId};
}

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState(this.uri);

  @override
  final Uri uri;

  @override
  ValueKey<String> get pageKey => const ValueKey('video-recorder');

  @override
  String? get name => VideoRecorderScreen.routeName;

  @override
  String? get path => VideoRecorderScreen.path;

  @override
  GoRoute? get topRoute => null;

  @override
  String? get fullPath => null;

  @override
  Map<String, String> get pathParameters => const {};
}

/// Runs the recorder route's page builder for [location] and returns the
/// widget it mounts, without building it.
VideoRecorderRoute _recorderRouteFor(String location) {
  final route = videoRoutes().whereType<GoRoute>().firstWhere(
    (route) => route.path == VideoRecorderScreen.path,
  );
  final page = route.pageBuilder!(
    _FakeBuildContext(),
    _FakeGoRouterState(Uri.parse(location)),
  );
  return (page as CustomTransitionPage<void>).child as VideoRecorderRoute;
}

void main() {
  group('videoRoutes recorder route', () {
    test('a bare location opens directly, without auto-record', () {
      final recorder = _recorderRouteFor(VideoRecorderScreen.path);

      expect(recorder.entryPoint, CreationEntryPoint.direct);
      expect(recorder.autoRecord, isFalse);
    });

    test('reads the entry point from the query', () {
      final recorder = _recorderRouteFor(
        VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.bottomNav),
      );

      expect(recorder.entryPoint, CreationEntryPoint.bottomNav);
      expect(recorder.autoRecord, isFalse);
    });

    test('reads the auto-record flag from the query', () {
      final recorder = _recorderRouteFor(
        VideoRecorderScreen.pathForEntryPoint(
          CreationEntryPoint.bottomNav,
          autoRecord: true,
        ),
      );

      expect(recorder.entryPoint, CreationEntryPoint.bottomNav);
      expect(recorder.autoRecord, isTrue);
    });
  });

  group('videoRoutes engagement routes', () {
    // videoRoutes() is spread straight into GoRouter.routes, so entering
    // either of these cold leaves a one-entry stack — the reason
    // VideoEngagementListView's back arrow needs safePop (#9359). The
    // behavioural test for that builds its own router, so this is the only
    // check bound to the real table.
    for (final path in const [
      '/video/:eventId/likers',
      '/video/:eventId/reposters',
    ]) {
      test('$path is registered flat and top-level', () {
        final matches = videoRoutes().whereType<GoRoute>().where(
          (route) => route.path == path,
        );

        expect(
          matches,
          hasLength(1),
          reason:
              'Expected exactly one top-level GoRoute at $path. Nesting it '
              'under another route makes canPop() true on cold entry, which '
              'retires the safePop fallback in VideoEngagementListView; '
              'renaming it strands the location hardcoded by '
              'video_engagement_list_screen_test.dart. Either way, revisit '
              'that test before updating this one.',
        );
      });
    }
  });

  group('buildVideoEngagementList', () {
    const hexId =
        'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
    const authorHex =
        '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
    const dTag = 'ip1dd9tAlmw';
    const coordinate = '34236:$authorHex:$dTag';
    const nevent =
        'nevent1qqsvyx8dnn5emv7zzm98cu8h52y68kjklc9ehg2f9vchnkmnernr5ngvsmkn3';
    const naddr =
        'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
        'eqyt7crqpa2zfh72sxpqqqzzmcqtynsu';

    VideoEngagementListScreen build(String id, [String query = '']) =>
        buildVideoEngagementList(
          _FakeBuildContext(),
          _EngagementState(id, query),
          VideoEngagementType.likers,
        ) as VideoEngagementListScreen;

    test('passes a hex event id straight through', () {
      final screen = build(hexId);

      expect(screen.eventId, equals(hexId));
      expect(screen.addressableId, isNull);
      expect(screen.type, equals(VideoEngagementType.likers));
    });

    test('decodes an nevent1 link to its hex event id', () {
      // Undecoded, this reached the API as bech32, which 404s — so the list
      // rendered empty for a video that has likers.
      expect(build(nevent).eventId, equals(hexId));
    });

    test('resolves an naddr1 link to its d tag and coordinate', () {
      final screen = build(naddr);

      expect(screen.eventId, equals(dTag));
      expect(screen.addressableId, equals(coordinate));
    });

    test('resolves a raw coordinate the same way', () {
      final screen = build(coordinate);

      expect(screen.eventId, equals(dTag));
      expect(screen.addressableId, equals(coordinate));
    });

    test('keeps an explicit ?a= over the decoded coordinate', () {
      final screen = build(naddr, 'a=34236:$authorHex:other');

      expect(screen.addressableId, equals('34236:$authorHex:other'));
    });

    test('forwards ?a= for a plain hex link', () {
      expect(build(hexId, 'a=$coordinate').addressableId, equals(coordinate));
    });

    test('builds the reposters list for that type', () {
      final screen = buildVideoEngagementList(
        _FakeBuildContext(),
        _EngagementState(hexId),
        VideoEngagementType.reposters,
      ) as VideoEngagementListScreen;

      expect(screen.type, equals(VideoEngagementType.reposters));
    });
  });

  group('buildVideoEngagementList rejects an id it cannot decode', () {
    // RouteErrorScreen reads ctx.l10n, so these need a real localized
    // context rather than the Fake the cases above can use.
    Future<Widget> buildFor(WidgetTester tester, String id) async {
      late BuildContext captured;
      await tester.pumpWidget(
        buildLocalizedWidget(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return buildVideoEngagementList(
        captured,
        _EngagementState(id),
        VideoEngagementType.likers,
      );
    }

    testWidgets('a whitespace-only segment', (tester) async {
      // `raw.isEmpty` let this through and the API was asked for
      // /api/videos/%20%20%20/likers, which answers nothing.
      expect(await buildFor(tester, '   '), isA<RouteErrorScreen>());
    });

    testWidgets('an nevent1 that does not decode', (tester) async {
      // A truncated or mistyped shared link. Forwarded raw, it 404s at the
      // API and misses at the relay, and the list renders empty.
      expect(
        await buildFor(tester, 'nevent1qvqsqxvr2tz'),
        isA<RouteErrorScreen>(),
      );
    });

    testWidgets('an naddr1 for a kind that is not a video', (tester) async {
      expect(
        await buildFor(
          tester,
          'naddr1qq9kjup3v3jrjazpd3khwq3qsxktkuz8tw9hzhpc6pevaymknj3827parpu'
          'eqyt7crqpa2zfh72sxpqqqp65wdhulxv',
        ),
        isA<RouteErrorScreen>(),
      );
    });
  });
}
