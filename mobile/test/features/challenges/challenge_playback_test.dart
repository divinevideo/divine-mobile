import 'dart:async';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_playback.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../packages/challenges_repository/test/synthetic.dart';

void main() {
  group(ChallengePlayback, () {
    for (final failCreation in [false, true]) {
      testWidgets(
        'closing during native creation cleans up (failure: $failCreation)',
        (
          tester,
        ) async {
          // Keep the asynchronous channel replies and cancellation in the same
          // real-async zone; widget fake time cannot drain native stream cleanup.
          await tester.runAsync(() async {
            final creation = Completer<Map<Object?, Object?>>();
            final disposal = Completer<void>();
            final calls = <String>[];
            final availability = <bool>[];
            final initialLiveCount =
                DivineVideoPlayerController.liveControllerCount;
            final messenger = tester.binding.defaultBinaryMessenger;
            const channel = MethodChannel('divine_video_player');
            MethodChannel? events;
            messenger.setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              if (call.method == 'create') {
                final id = (call.arguments as Map<Object?, Object?>)['id'];
                events = MethodChannel('divine_video_player/player_$id/events');
                messenger.setMockMethodCallHandler(events!, (event) async {
                  calls.add('event.${event.method}');
                  return null;
                });
                return creation.future;
              }
              if (call.method == 'dispose') disposal.complete();
              return null;
            });
            addTearDown(() {
              messenger.setMockMethodCallHandler(channel, null);
              if (events != null) {
                messenger.setMockMethodCallHandler(events!, null);
              }
            });
            final signer = SyntheticSigner();
            final video = NostrEvent.fromJson(
              signer.sign(
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
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ChallengePlayback(
                  video: video,
                  allowed: (_) => true,
                  onAvailabilityChanged: availability.add,
                ),
              ),
            );
            expect(calls, ['create']);
            await tester.pumpWidget(const SizedBox());
            if (failCreation) {
              creation.completeError(
                PlatformException(code: 'synthetic_creation_failure'),
              );
            } else {
              creation.complete({'textureId': 7});
              await disposal.future.timeout(const Duration(seconds: 2));
            }
            await tester.pumpAndSettle();
            expect(
              calls,
              failCreation
                  ? ['create']
                  : ['create', 'event.listen', 'event.cancel', 'dispose'],
            );
            expect(availability, isEmpty);
            expect(
              DivineVideoPlayerController.liveControllerCount,
              initialLiveCount,
            );
            expect(tester.takeException(), isNull);
          });
        },
      );
    }
  });
}
