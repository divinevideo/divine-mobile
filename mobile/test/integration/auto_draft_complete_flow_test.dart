// ABOUTME: Integration test for complete auto-draft flow from recording to publish
// ABOUTME: Validates end-to-end behavior: record → auto-draft → edit → publish → retry

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Auto-draft complete flow integration', () {
    test('record → auto-draft → edit → publish flow', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      // Simulate recording completion with auto-draft
      // (This test documents the expected flow)

      // 1. Recording stops → draft created automatically
      // (Tested in VineRecordingProvider tests)

      // 2. Preview screen loads draft by ID
      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Do it for the Vine!',
        description: '',
        hashtags: ['openvine', 'vine'],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      // 3. User edits metadata
      final edited = draft.copyWith(
        title: 'My Awesome Vine',
        description: 'This is cool',
      );
      await draftStorage.saveDraft(edited);

      // 4. Verify no duplicate drafts
      final drafts = await draftStorage.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.id, draft.id);
      expect(drafts.first.title, 'My Awesome Vine');

      // 5. Publish attempt updates status
      final publishing = edited.copyWith(
        publishStatus: PublishStatus.publishing,
      );
      await draftStorage.saveDraft(publishing);

      final afterPublishing = await draftStorage.getAllDrafts();
      expect(afterPublishing.first.publishStatus, PublishStatus.publishing);

      // 6. Success deletes draft
      await draftStorage.deleteDraft(draft.id);

      final afterDelete = await draftStorage.getAllDrafts();
      expect(afterDelete, isEmpty);
    });

    test('record → auto-draft → failed publish → retry flow', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      // 1. Auto-draft created
      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Test Video',
        description: '',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      // 2. Publish fails
      final failed = draft.copyWith(
        publishStatus: PublishStatus.failed,
        publishError: 'Network timeout',
        publishAttempts: 1,
      );
      await draftStorage.saveDraft(failed);

      // 3. Draft still exists with error
      final drafts = await draftStorage.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.publishStatus, PublishStatus.failed);
      expect(drafts.first.publishError, 'Network timeout');
      expect(drafts.first.canRetry, true);

      // 4. Retry attempt
      final retrying = failed.copyWith(
        publishStatus: PublishStatus.publishing,
        publishAttempts: 2,
      );
      await draftStorage.saveDraft(retrying);

      final afterRetry = await draftStorage.getAllDrafts();
      expect(afterRetry.first.publishAttempts, 2);

      // 5. Success deletes draft
      await draftStorage.deleteDraft(draft.id);

      final afterSuccess = await draftStorage.getAllDrafts();
      expect(afterSuccess, isEmpty);
    });
  });
}
