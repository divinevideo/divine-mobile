import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/published_room_notification.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  group('PublishedRoomNotification.record', () {
    final pubkey = 'a' * 64;
    const roomId = '0123456789abcdef0123456789abcdef';
    final draft = DivineVideoDraft.create(
      id: 'room-publish',
      clips: [
        DivineVideoClip(
          id: 'room-video',
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          video: EditorVideo.file('/test/room-video.mp4'),
        ),
      ],
      title: 'Together',
      description: '',
      hashtags: const {},
      selectedApproach: 'video',
      collabRoomId: roomId,
    ).copyWith(publishStatus: PublishStatus.publishing);
    final body = jsonEncode(
      Event(pubkey, 34236, [
        ['d', 'room-video'],
      ], 'Together').toJson(),
    );

    setUpAll(() => registerFallbackValue(draft));

    test(
      'persists the published event for a later room notification',
      () async {
        final storage = _MockDraftStorageService();
        when(() => storage.saveDraft(any())).thenAnswer((_) async {});
        final notification = PublishedRoomNotification(
          storage: storage,
          currentPubkey: () => pubkey,
          send: null,
        );

        await notification.record(draft, body, pubkey);

        final saved =
            verify(() => storage.saveDraft(captureAny())).captured.single
                as DivineVideoDraft;
        expect(saved.id, draft.id);
        expect(saved.collabRoomId, roomId);
        expect(saved.publishStatus, PublishStatus.published);
        expect(saved.publishedVideoEvent, body);
      },
    );
  });
}
