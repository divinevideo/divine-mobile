import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart' as cp;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:openvine/features/challenges/challenge_detail_view.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_video_picker.dart';
import 'package:openvine/features/challenges/challenge_video_tile.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';

import '../../../packages/challenges_repository/test/harness.dart';

Future<void> surface(
  WidgetTester tester,
  Widget child, {
  bool large = false,
}) async {
  tester.view.physicalSize = Size(large ? 320 : 390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Challenge presentation renders and interactions', () {
    test(
      'thumbnail conversion preserves the pinned revision for all v1 video kinds',
      () {
        final h = Harness();
        for (final kind in [21, 22, 34235, 34236]) {
          final video = cp.NostrEvent.fromJson(
            h.creator.sign(
              kind: kind,
              tags: [
                if (kind >= 30000) ['d', 'synthetic:$kind'],
                [
                  'imeta',
                  'url https://media.example.test/video.mp4',
                  'image https://media.example.test/image.jpg',
                  'dim 360x640',
                ],
              ],
            ),
          );
          final model = challengeVideoModel(video)!;
          expect(model.id, video.id);
          expect(model.pubkey, video.pubkey);
          expect(model.thumbnailUrl, 'https://media.example.test/image.jpg');
          expect(model.width, 360);
          expect(model.height, 640);
        }
      },
    );

    testWidgets(
      'picker selects locally and only Continue prepares exact video',
      (
        tester,
      ) async {
        final h = Harness();
        h.video = cp.NostrEvent.fromJson(
          h.creator.sign(
            kind: 34236,
            tags: [
              ['d', 'synthetic:picker'],
            ],
            content: 'Synthetic candidate',
          ),
        );
        final candidates = [
          VideoEvent(
            id: h.video.id,
            pubkey: h.creator.pubkey,
            createdAt: 1893456000,
            timestamp: DateTime.utc(2030),
            content: 'Synthetic candidate',
          ),
        ];
        final continued = <String>[];
        var more = 0;
        var cancelled = false;
        await surface(
          tester,
          ChallengeVideoPicker(
            videos: candidates,
            busy: false,
            hasMore: true,
            onLoadMore: () => more++,
            loadPreview: (_) async => h.video,
            allowed: (_) => true,
            onCancel: () => cancelled = true,
            onContinue: (id) async => continued.add(id),
          ),
        );
        expect(find.text(h.video.id), findsNothing);
        final button = find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(DivineButton),
        );
        expect(tester.widget<DivineButton>(button).onPressed, isNull);
        await tester.tap(find.text('Synthetic candidate'));
        await tester.pumpAndSettle();
        expect(continued, isEmpty);
        expect(h.signatures, 0);
        await tester.ensureVisible(find.text('Show more'));
        await tester.tap(find.text('Show more'));
        expect(more, 1);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(continued, [h.video.id]);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(cancelled, isTrue);
        cancelled = false;
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(cancelled, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'pinned tile removes media on policy revocation and background',
      (
        tester,
      ) async {
        final h = Harness();
        h.video = cp.NostrEvent.fromJson(
          h.creator.sign(
            kind: 34236,
            tags: [
              ['d', 'synthetic:restricted'],
            ],
            content: 'Synthetic restricted caption',
          ),
        );
        var allowed = true;
        var played = 0;
        await surface(
          tester,
          Scaffold(
            body: SizedBox(
              width: 180,
              child: ChallengeVideoTile(
                video: h.video,
                allowed: (_) => allowed,
                onTap: () => played++,
              ),
            ),
          ),
        );
        expect(find.byType(ProfileTabThumbnail), findsOneWidget);
        expect(find.text('Synthetic restricted caption'), findsOneWidget);
        expect(find.text(h.video.id), findsNothing);
        allowed = false;
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ProfileTabThumbnail), findsNothing);
        expect(find.text('Synthetic restricted caption'), findsNothing);
        await tester.tap(find.text('Selected entry unavailable'));
        expect(played, 0);
        allowed = true;
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ProfileTabThumbnail), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.scheduleForcedFrame();
        await tester.pump();
        expect(find.byType(ProfileTabThumbnail), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('picker hides signed captions when preview policy is denied', (
      tester,
    ) async {
      final h = Harness();
      h.video = cp.NostrEvent.fromJson(
        h.creator.sign(
          kind: 34236,
          tags: [
            ['d', 'synthetic:picker-private'],
          ],
          content: 'Synthetic private candidate',
        ),
      );
      var permitted = true;
      await surface(
        tester,
        ChallengeVideoPicker(
          videos: [challengeVideoModel(h.video)!],
          busy: false,
          onCancel: () {},
          onContinue: (_) async {},
          loadPreview: (_) async => h.video,
          allowed: (_) => permitted,
        ),
      );
      expect(find.text('Synthetic private candidate'), findsOneWidget);
      permitted = false;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Synthetic private candidate'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('picker renews preview leases and refreshes on resume', (
      tester,
    ) async {
      final h = Harness();
      h.video = cp.NostrEvent.fromJson(
        h.creator.sign(
          kind: 34236,
          tags: [
            ['d', 'synthetic:picker-lease'],
          ],
          content: 'Synthetic renewable candidate',
        ),
      );
      var expires = tester.binding.clock.now();
      var previewReads = 0;
      final continued = <String>[];
      await surface(
        tester,
        ChallengeVideoPicker(
          videos: [challengeVideoModel(h.video)!],
          busy: false,
          onCancel: () {},
          onContinue: (id) async => continued.add(id),
          loadPreview: (_) async {
            previewReads++;
            expires = tester.binding.clock.now().add(
              const Duration(seconds: 30),
            );
            return h.video;
          },
          allowed: (_) => tester.binding.clock.now().isBefore(expires),
        ),
      );
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileTabThumbnail), findsOneWidget);
      await tester.tap(find.text('Synthetic renewable candidate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, [h.video.id]);
      final beforePause = previewReads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump(const Duration(seconds: 45));
      expect(previewReads, beforePause);
      expect(find.text('Synthetic renewable candidate'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileTabThumbnail), findsOneWidget);
      expect(find.text('Synthetic renewable candidate'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final large in [false, true]) {
      testWidgets(
        'signed winner slots retain order and unavailable labels, large=$large',
        (tester) async {
          final h = Harness();
          final definition =
              cp.parseChallengeEvent(h.definition).value!
                  as cp.ChallengeDefinition;
          final videos = [
            h.video,
            cp.NostrEvent.fromJson(
              h.creator.sign(
                kind: 34236,
                tags: [
                  ['d', 'synthetic:second'],
                ],
                content: 'Synthetic second video',
              ),
            ),
          ];
          final entries = [
            for (var i = 0; i < 2; i++)
              cp.NostrEvent.fromJson(
                h.creator.template(
                  cp.buildEntry(definition, videos[i], 150 + i),
                ),
              ),
          ];
          const labels = [
            'Synthetic first selection',
            'Synthetic second selection',
          ];
          final result = h.organizer.sign(
            kind: 1111,
            createdAt: 201,
            content: entries
                .map((e) => 'nostr:${Nip19.encodeNoteId(e.id)}')
                .join(' '),
            tags: [
              ['t', 'divine-challenge'],
              ['challenge', '1', 'result'],
              ['A', definition.coordinate],
              ['K', '31923'],
              ['P', h.organizer.pubkey],
              ['a', definition.coordinate],
              ['k', '31923'],
              ['p', h.organizer.pubkey],
              ['e', h.definition.id],
              ['challenge_snapshot', jsonEncode(h.definition.toJson())],
              for (var i = 0; i < 2; i++) ...[
                ['winner', entries[i].id, labels[i]],
                ['q', entries[i].id],
              ],
            ],
          );
          h.now = 202;
          h.hidden.add(videos.first.id);
          h.source.records = [
            jsonEncode(h.definition.toJson()),
            for (final e in entries) jsonEncode(e.toJson()),
            jsonEncode(result),
          ];
          final read = await h.reads.refresh(definition.coordinate);
          expect(read.view.currentResult?.winners, hasLength(2));
          final played = <String>[];
          await surface(
            tester,
            ChallengeDetailView(
              state: ChallengeParticipationState(read: read),
              onEnter: () {},
              onRefresh: () async {},
              onPlay: (id) async => played.add(id),
              onWithdraw: (_) async {},
              allowed: h.reads.isVisible,
              deliveryActions: const Text('Synthetic pending delivery'),
            ),
            large: large,
          );
          await tester.scrollUntilVisible(find.text(labels.first), 200);
          await tester.pumpAndSettle();
          expect(find.text('Selected entry unavailable'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text(labels.first)).dy,
            lessThanOrEqualTo(tester.getTopLeft(find.text(labels.last)).dy),
          );
          await tester.tap(find.text(labels.first));
          expect(played, isEmpty);
          await tester.ensureVisible(find.text(labels.last));
          await tester.tap(find.text(labels.last));
          await tester.pumpAndSettle();
          expect(played, [entries.last.id]);
          expect(find.text(entries.first.id), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });
}
