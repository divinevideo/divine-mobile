import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/live/widgets/live_room_stage.dart';
import 'package:openvine/screens/live/widgets/live_room_stage_media_tile.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  group('LiveRoomStage', () {
    testWidgets(
      'renders profile identity for stage participants instead of raw pubkeys',
      (tester) async {
        const hostPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final profile = UserProfile(
          pubkey: hostPubkey,
          rawData: const <String, dynamic>{},
          createdAt: DateTime.utc(2026, 4, 9),
          eventId: 'profile-event',
          displayName: 'Alice Stage',
          picture: 'https://example.com/avatar.png',
        );

        await tester.pumpWidget(
          testMaterialApp(
            mockNip05VerificationService: createMockNip05VerificationService(),
            additionalOverrides: [
              userProfileReactiveProvider(hostPubkey).overrideWith(
                (ref) => Stream.value(profile),
              ),
            ],
            home: const Scaffold(
              body: LiveRoomStage(
                speakerPubkeys: <String>[hostPubkey],
                audienceCount: 24,
                statusLabel: 'connected',
                mediaState: LiveMediaState(
                  stageParticipants: <LiveStageParticipant>[
                    LiveStageParticipant(
                      identity: hostPubkey,
                      isLocal: true,
                      isMicrophoneEnabled: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LiveRoomStageMediaTile), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.text('Alice Stage'), findsOneWidget);
        expect(find.text(hostPubkey), findsNothing);
      },
    );

    testWidgets('renders media tiles from the live media snapshot', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          mockNip05VerificationService: createMockNip05VerificationService(),
          home: const Scaffold(
            body: LiveRoomStage(
              speakerPubkeys: <String>['stale-speaker-pubkey'],
              audienceCount: 24,
              statusLabel: 'connected',
              mediaState: LiveMediaState(
                stageParticipants: <LiveStageParticipant>[
                  LiveStageParticipant(
                    identity: 'host-pubkey',
                    isLocal: true,
                    isMicrophoneEnabled: true,
                  ),
                  LiveStageParticipant(
                    identity: 'speaker-pubkey',
                    isLocal: false,
                    isMicrophoneEnabled: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomStageMediaTile), findsNWidgets(2));
      expect(find.text('stale-speaker-pubkey'), findsNothing);
      expect(find.text('24 listeners in the room'), findsOneWidget);
    });

    testWidgets(
      'shows the local host tile as camera and mic off before tracks publish',
      (tester) async {
        const hostPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final profile = UserProfile(
          pubkey: hostPubkey,
          rawData: const <String, dynamic>{},
          createdAt: DateTime.utc(2026, 4, 9),
          eventId: 'profile-event',
          displayName: 'Alice Stage',
        );

        await tester.pumpWidget(
          testMaterialApp(
            mockNip05VerificationService: createMockNip05VerificationService(),
            additionalOverrides: [
              userProfileReactiveProvider(hostPubkey).overrideWith(
                (ref) => Stream.value(profile),
              ),
            ],
            home: const Scaffold(
              body: LiveRoomStage(
                speakerPubkeys: <String>[hostPubkey],
                audienceCount: 0,
                statusLabel: 'connected',
                mediaState: LiveMediaState(
                  canPublish: true,
                  localParticipantIdentity: hostPubkey,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LiveRoomStageMediaTile), findsOneWidget);
        expect(find.text('Alice Stage'), findsOneWidget);
        expect(find.text('Camera and mic are off'), findsOneWidget);
        expect(find.text('Waiting for media'), findsNothing);
      },
    );

    testWidgets(
      'shows the local host tile as starting camera while publish is pending',
      (tester) async {
        const hostPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final profile = UserProfile(
          pubkey: hostPubkey,
          rawData: const <String, dynamic>{},
          createdAt: DateTime.utc(2026, 4, 9),
          eventId: 'profile-event',
          displayName: 'Alice Stage',
        );

        await tester.pumpWidget(
          testMaterialApp(
            mockNip05VerificationService: createMockNip05VerificationService(),
            additionalOverrides: [
              userProfileReactiveProvider(hostPubkey).overrideWith(
                (ref) => Stream.value(profile),
              ),
            ],
            home: const Scaffold(
              body: LiveRoomStage(
                speakerPubkeys: <String>[hostPubkey],
                audienceCount: 0,
                statusLabel: 'connecting',
                mediaState: LiveMediaState(
                  canPublish: true,
                  localParticipantIdentity: hostPubkey,
                  requestedCameraEnabled: true,
                  cameraBusy: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LiveRoomStageMediaTile), findsOneWidget);
        expect(find.text('Alice Stage'), findsOneWidget);
        expect(find.text('Starting camera...'), findsOneWidget);
        expect(find.text('Camera and mic are off'), findsNothing);
      },
    );

    testWidgets('shows the empty state when nobody is on stage', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          mockNip05VerificationService: createMockNip05VerificationService(),
          home: const Scaffold(
            body: LiveRoomStage(
              speakerPubkeys: <String>[],
              audienceCount: 0,
              statusLabel: 'disconnected',
              mediaState: LiveMediaState(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomStageMediaTile), findsNothing);
      expect(
        find.text('Waiting for speakers to join the stage.'),
        findsOneWidget,
      );
    });
  });
}
