import 'dart:async';

import 'package:challenge_protocol/challenge_protocol.dart' hide ChallengeView;
import 'package:challenges_repository/challenges_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_participation_cubit.dart';
import 'package:openvine/features/challenges/challenge_playback.dart';
import 'package:openvine/features/challenges/challenge_view.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/harness.dart';
import '../../helpers/divine_video_player_channel.dart';

void main() {
  group('review policy lease', () {
    for (final failure in ['denied', 'refresh error', 'owner changed']) {
      testWidgets(
        'renews exact review across expiry/resume and blocks $failure',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1000, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final h = Harness();
          h.video = NostrEvent.fromJson(
            h.creator.sign(
              kind: 34236,
              tags: [
                ['d', 'synthetic:video'],
                [
                  'imeta',
                  'url https://media.example.test/synthetic.mp4',
                  'm video/mp4',
                ],
              ],
            ),
          );
          h.videoId = h.video.id;
          var until = tester.binding.clock.now();
          var reject = false;
          Completer<void>? renewal;
          final refreshed = <String>[];
          final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
          h.reads = ChallengesRepository(
            source: h.source.read,
            store: h.retained,
            clock: () => h.now,
            isVisible: (event) =>
                event.id != h.video.id ||
                until.isAfter(tester.binding.clock.now()),
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
              refreshed.add(video.id);
              // Same fail-closed renewal boundary as ChallengeVideoPolicy:
              // remove the lease before asynchronous fresh evidence arrives.
              until = tester.binding.clock.now();
              await renewal?.future;
              if (reject) {
                if (failure == 'refresh error') {
                  throw StateError('Synthetic policy read failed');
                }
                if (failure == 'owner changed') h.owner = null;
                return;
              }
              until = tester.binding.clock.now().add(
                const Duration(seconds: 30),
              );
            },
            sign: (fields) async {
              h.signatures++;
              return h.signFields(fields);
            },
          );
          final cubit = ChallengeParticipationCubit(
            coordinate: coordinate,
            submissions: h.repository,
            refresh: () => h.reads.refresh(coordinate),
            loadCandidates: () async => [],
            exactVideo: (_) async => h.video,
            clientTags: () async => [],
            prepareRecording: (_) async => 'recording',
            handoffs: () async => [],
            reviewPublished: (_) => h.prepare(),
          );
          addTearDown(cubit.close);
          final messenger = tester.binding.defaultBinaryMessenger;
          const global = MethodChannel('divine_video_player');
          messenger.setMockMethodCallHandler(global, (call) async {
            if (call.method == 'create') {
              final id =
                  (call.arguments as Map<Object?, Object?>)['id']! as int;
              MockStreamHandlerEventSink? sink;
              installMockDivineVideoPlayer(
                playerId: id,
                streamHandler: MockStreamHandler.inline(
                  onListen: (_, events) {
                    sink = events;
                  },
                ),
                onMethodCall: (call) async {
                  if (call.method == 'play') {
                    sink!.success({
                      'status': 'playing',
                      'isFirstFrameRendered': true,
                    });
                  }
                  return null;
                },
              );
              return {'textureId': id + 1};
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(global, null);
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          });
          await cubit.load();
          await cubit.selectVideo(h.video.id);
          final review = cubit.state.review!;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider.value(
                value: cubit,
                child: ChallengeView(onRecord: (_, _) async {}),
              ),
            ),
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          });
          await tester.pumpAndSettle();
          DivineButton agree() => tester.widget<DivineButton>(
            find.ancestor(
              of: find.text('Enter this video'),
              matching: find.byType(DivineButton),
            ),
          );
          expect(agree().onPressed, isNotNull);
          renewal = Completer<void>();
          await tester.pump(const Duration(seconds: 20));
          await tester.pump();
          expect(agree().onPressed, isNull);
          await tester.pump(const Duration(seconds: 15));
          renewal.complete();
          renewal = null;
          await tester.pumpAndSettle();
          expect(agree().onPressed, isNotNull);
          expect(cubit.state.review, same(review));
          expect(refreshed.toSet(), {h.video.id});
          expect(refreshed.length, greaterThan(1));
          expect(h.signatures, 0);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pumpAndSettle();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          expect(agree().onPressed, isNull);
          expect(find.byType(ChallengePlayback), findsNothing);
          final beforeResume = refreshed.length;
          await tester.pump(const Duration(seconds: 35));
          expect(refreshed.length, beforeResume);
          renewal = Completer<void>();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          await tester.pump();
          expect(agree().onPressed, isNull);
          renewal.complete();
          renewal = null;
          await tester.pumpAndSettle();
          expect(agree().onPressed, isNotNull);
          expect(cubit.state.review, same(review));

          reject = true;
          await tester.pump(const Duration(seconds: 20));
          await tester.pumpAndSettle();
          expect(agree().onPressed, isNull);
          expect(find.byType(ChallengePlayback), findsNothing);
          expect(h.signatures, 0);
          if (failure != 'owner changed') {
            reject = false;
            await tester.ensureVisible(find.text('Retry'));
            await tester.tap(find.text('Retry'));
            await tester.pumpAndSettle();
            expect(agree().onPressed, isNotNull);
            expect(cubit.state.review, same(review));
          }
          expect(h.signatures, 0);
          expect(refreshed.toSet(), {h.video.id});
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  });
}
