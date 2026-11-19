// ABOUTME: Persists and retries Together room notifications after a video goes live.

import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_publish/publish_result.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Finishes a Together post without repeating the public video publish.
class PublishedRoomNotification {
  const PublishedRoomNotification({
    required DraftStorageService storage,
    required String? Function() currentPubkey,
    required Future<void> Function(String roomId, String videoAddress)? send,
  }) : _storage = storage,
       _currentPubkey = currentPubkey,
       _send = send;

  final DraftStorageService _storage;
  final String? Function() _currentPubkey;
  final Future<void> Function(String roomId, String videoAddress)? _send;

  /// Retains the successful video while its room notification is outstanding.
  Future<void> record(
    DivineVideoDraft draft,
    String? signedEventBody,
    String pubkey,
  ) async {
    if (draft.collabRoomId == null ||
        signedEventBody == null ||
        _currentPubkey() != pubkey) {
      return;
    }
    try {
      await _storage.saveDraft(
        draft.copyWith(
          publishStatus: PublishStatus.published,
          publishedVideoEvent: signedEventBody,
        ),
      );
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Could not record the published Together video',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Returns the original public result and tries any pending room update.
  Future<PublishSuccess> recover(DivineVideoDraft draft) async {
    final body = draft.publishedVideoEvent;
    final event = body == null
        ? null
        : Event.fromJson(jsonDecode(body) as Map<String, dynamic>);
    final notified =
        draft.collabRoomId == null ||
        (event != null &&
            await notify(
              draft,
              pubkey: event.pubkey,
              kind: event.kind,
              stableId: event.dTagValue,
            ));
    return PublishSuccess(
      eventId: event?.id,
      signedEventBody: body,
      collabRoomNotificationPending: !notified,
    );
  }

  /// Hands a room update to the DM queue and reports whether it was accepted.
  Future<bool> notify(
    DivineVideoDraft draft, {
    required String pubkey,
    required int kind,
    required String? stableId,
  }) async {
    final roomId = draft.collabRoomId;
    final send = _send;
    if (roomId == null) return true;
    if (send == null || stableId == null || stableId.isEmpty) return false;
    if (_currentPubkey() != pubkey) return false;
    try {
      await send(roomId, '$kind:$pubkey:$stableId');
      return true;
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Could not tell the Together room its video was published',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
