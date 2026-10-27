// Synthetic native UI acceptance. Uses real challenge repositories and signed
// synthetic events; no real account, relay transport, API or camera publication.
import 'dart:convert';
import 'dart:io';

import 'package:challenge_protocol/challenge_protocol.dart' show NostrEvent;
import 'package:challenges_repository/challenges_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:path_provider/path_provider.dart';

import '../../packages/challenges_repository/test/harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('challenge_native', () {
    testWidgets('synthetic native challenge participation', (tester) async {
      final initialLifecycle = binding.lifecycleState;
      debugPrint('Synthetic challenge initial lifecycle: $initialLifecycle');
      // This fixture drives Dart lifecycle transitions explicitly; it does not
      // assert OS background/foreground delivery.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final h = Harness();
      final media = (await rootBundle.load('assets/videos/default_intro.mp4'))
          .buffer
          .asUint8List();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        var start = 0;
        var end = media.length - 1;
        if (range != null) {
          final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
          if (match != null) {
            start = int.parse(match.group(1)!);
            if (match.group(2)!.isNotEmpty) end = int.parse(match.group(2)!);
            if (end >= media.length) end = media.length - 1;
            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-$end/${media.length}',
            );
          }
        }
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.contentLength = end - start + 1;
        request.response.add(media.sublist(start, end + 1));
        await request.response.close();
      });
      h.video = NostrEvent.fromJson(
        h.creator.sign(
          kind: 34236,
          content: 'A little Divine test video',
          tags: [
            ['d', 'synthetic:video'],
            [
              'imeta',
              'url http://127.0.0.1:${server.port}/synthetic.mp4',
              'm video/mp4',
            ],
          ],
        ),
      );
      h.videoId = h.video.id;
      h.source.beforeRead = () async {
        h.source.observation = RawChallengeRead(
          records: h.source.records,
          source: ReadSource.relay,
          completeness: ReadCompleteness.partial,
          revisionsComplete: true,
        );
      };
      final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
      var policyUntil = DateTime.now();
      var policyRefreshes = 0;
      final refreshedVideoIds = <String>[];
      h.reads = ChallengesRepository(
        source: h.source.read,
        store: h.retained,
        clock: () => h.now,
        isVisible: (event) =>
            !h.hidden.contains(event.id) &&
            (event.id != h.video.id || policyUntil.isAfter(DateTime.now())),
      );
      h.repository = ChallengeSubmissionRepository(
        reads: h.reads,
        store: h.store,
        transport: h.transport.publish,
        currentOwner: () => h.owner,
        canPublish: (_) => h.publicationAllowed,
        currentVideoId: (_) => h.videoId,
        writableRelays: () => [h.relay],
        refreshVideo: (video) async {
          // Native timer callbacks run outside tester.pump's guarded zone.
          // Record here; assert every exact ID in the main test body below.
          refreshedVideoIds.add(video.id);
          policyUntil = DateTime.now();
          // Synthetic evidence only: the production relay/moderation/media
          // lookup is not exercised by this local native acceptance fixture.
          policyRefreshes++;
          policyUntil = DateTime.now().add(const Duration(seconds: 30));
        },
        sign: (fields) async {
          h.signatures++;
          return h.signFields(fields);
        },
      );
      final output = await Directory(
        '${(await getApplicationDocumentsDirectory()).path}/challenge-artifacts',
      ).create(recursive: true);
      var recorded = false;
      final cubit = ChallengeParticipationCubit(
        coordinate: coordinate,
        submissions: h.repository,
        refresh: () => h.reads.refresh(coordinate),
        loadCandidates: () async => [
          VideoEvent.fromNostrEvent(Event.fromJson(h.video.toJson())),
        ],
        exactVideo: (id) async => id == h.video.id ? h.video : null,
        clientTags: () async => [],
        prepareRecording: (_) async => 'synthetic-recording',
        handoffs: () async => recorded ? ['synthetic-recording'] : [],
        reviewPublished: (_) => h.prepare(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      Future<void> pump(bool light) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: light ? VineTheme.lightTheme : VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: ChallengeView(
                ownerName: 'Synthetic creator',
                onRecord: (_, id) async {
                  expect(id, 'synthetic-recording');
                  recorded = true;
                  await cubit.load();
                },
              ),
            ),
          ),
        );
        await GoogleFonts.pendingFonts();
        await tester.pumpAndSettle();
      }

      Future<void> tap(String text) async {
        final finder = find.text(text).first;
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        if (text == 'Agree and submit') {
          for (var frame = 0; frame < 100; frame++) {
            final button = tester.widget<DivineButton>(
              find.ancestor(of: finder, matching: find.byType(DivineButton)),
            );
            if (button.onPressed != null) break;
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> screenshot(String name) async {
        final bytes = await binding.takeScreenshot(name);
        await File('${output.path}/$name.png').writeAsBytes(bytes);
      }

      await pump(false);
      await screenshot('native-challenge-dark');
      await pump(true);
      await screenshot('native-challenge-light');
      await tap('Record a video');
      expect(recorded, isTrue);
      await tap('Review your published video');
      expect(cubit.state.review!.video.id, h.video.id);
      await pump(false);
      await screenshot('native-challenge-review-dark');
      await pump(true);
      await screenshot('native-challenge-review');
      final pinnedReview = cubit.state.review;
      final refreshesBeforeReading = policyRefreshes;
      final observedIdsBeforeReading = refreshedVideoIds.length;
      debugPrint(
        'Synthetic review before wait: lifecycle=${binding.lifecycleState}, busy=${cubit.state.busy}',
      );
      final reviewWaitStarted = DateTime.now();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(cubit.state.review, same(pinnedReview));
      final reviewReadingElapsedMs = DateTime.now()
          .difference(reviewWaitStarted)
          .inMilliseconds;
      final afterReadingRefreshes = policyRefreshes;
      debugPrint(
        'Synthetic review after wait: lifecycle=${binding.lifecycleState}, busy=${cubit.state.busy}, refreshes=$policyRefreshes, elapsedMs=$reviewReadingElapsedMs',
      );
      expect(reviewReadingElapsedMs, greaterThanOrEqualTo(30000));
      expect(policyRefreshes, greaterThan(refreshesBeforeReading));
      expect(refreshedVideoIds.length, greaterThan(observedIdsBeforeReading));
      expect(refreshedVideoIds, isNotEmpty);
      expect(refreshedVideoIds, everyElement(h.video.id));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      for (var frame = 0; frame < 100; frame++) {
        final button = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text('Agree and submit'),
            matching: find.byType(DivineButton),
          ),
        );
        if (button.onPressed != null) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester
            .widget<DivineButton>(
              find.ancestor(
                of: find.text('Agree and submit'),
                matching: find.byType(DivineButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(cubit.state.review, same(pinnedReview));
      expect(h.signatures, 0);
      await screenshot('native-challenge-review-renewed');
      await tap('Cancel');
      await tap('Choose one of your videos');
      await tap(h.video.id);
      expect(h.signatures, 0);
      await tap('Agree and submit');
      expect(h.signatures, 1);
      final original = cubit.state.actions.single.signedBody;
      h.transport.outcomes[h.relay] = RelayOutcome.accepted;
      await tap('Retry delivery');
      expect(cubit.state.actions.single.signedBody, original);
      expect(h.signatures, 1);
      await screenshot('native-challenge-submitted');
      await tap('Withdraw entry');
      await tap('Confirm withdrawal');
      expect(h.signatures, 2);
      expect(refreshedVideoIds, everyElement(h.video.id));
      await cubit.load();
      await tester.pumpAndSettle();
      expect(cubit.state.actions, hasLength(2));
      await screenshot('native-challenge-withdrawal');
      await File('${output.path}/result.json').writeAsString(
        jsonEncode({
          'passed': true,
          'customSchemeDelivered': false,
          'exactSignedRetry': true,
          'reviewLeaseRenewal': true,
          'observedInitialLifecycle': initialLifecycle?.name,
          'reviewReadingElapsedMs': reviewReadingElapsedMs,
          'policyRefreshesBeforeReading': refreshesBeforeReading,
          'policyRefreshesAfterReading': afterReadingRefreshes,
          'syntheticLifecycleResume': true,
          'realPolicyNetworkLookup': false,
          'existingVideo': true,
          'withdrawal': true,
          'recordingHandoffUi': true,
          'realCameraRecording': false,
          'realRelayPublication': false,
          'hostedUniversalLink': false,
        }),
      );
      await tester.pumpWidget(const SizedBox());
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
