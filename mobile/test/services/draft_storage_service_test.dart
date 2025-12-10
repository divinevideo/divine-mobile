// ABOUTME: TDD tests for DraftStorageService - persistent storage for vine drafts
// ABOUTME: Tests save, load, delete, and clear operations using shared_preferences

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DraftStorageService', () {
    late DraftStorageService service;

    setUp(() async {
      // Start with clean slate for each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = DraftStorageService(prefs);
    });

    group('saveDraft', () {
      test('should save a draft to storage', () async {
        final draft = VineDraft.create(
          videoFile: File('/path/to/video.mp4'),
          title: 'Test Vine',
          description: 'A test description',
          hashtags: ['test', 'vine'],
          frameCount: 30,
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.id, draft.id);
        expect(drafts.first.title, 'Test Vine');
        expect(drafts.first.description, 'A test description');
        expect(drafts.first.hashtags, ['test', 'vine']);
        expect(drafts.first.frameCount, 30);
        expect(drafts.first.selectedApproach, 'hybrid');
      });

      test('should save multiple drafts', () async {
        final now = DateTime.now();
        final draft1 = VineDraft(
          id: 'draft_1',
          videoFile: File('/path/to/video1.mp4'),
          title: 'First Vine',
          description: 'First',
          hashtags: ['first'],
          frameCount: 30,
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        final draft2 = VineDraft(
          id: 'draft_2',
          videoFile: File('/path/to/video2.mp4'),
          title: 'Second Vine',
          description: 'Second',
          hashtags: ['second'],
          frameCount: 45,
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 2);
        expect(drafts[0].title, 'First Vine');
        expect(drafts[1].title, 'Second Vine');
      });

      test('should update existing draft if ID matches', () async {
        final draft = VineDraft.create(
          videoFile: File('/path/to/video.mp4'),
          title: 'Original Title',
          description: 'Original',
          hashtags: ['original'],
          frameCount: 30,
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final updated = draft.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
        );

        await service.saveDraft(updated);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.title, 'Updated Title');
        expect(drafts.first.description, 'Updated description');
      });
    });

    group('getAllDrafts', () {
      test('should return empty list when no drafts exist', () async {
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should return all saved drafts', () async {
        final now = DateTime.now();
        final draft1 = VineDraft(
          id: 'draft_1',
          videoFile: File('/path/to/video1.mp4'),
          title: 'First',
          description: '',
          hashtags: [],
          frameCount: 30,
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        final draft2 = VineDraft(
          id: 'draft_2',
          videoFile: File('/path/to/video2.mp4'),
          title: 'Second',
          description: '',
          hashtags: [],
          frameCount: 45,
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 2);
      });

      test('should handle corrupted storage gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vine_drafts', 'invalid json');

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });
    });

    group('deleteDraft', () {
      test('should delete draft by ID', () async {
        final now = DateTime.now();
        final draft1 = VineDraft(
          id: 'draft_1',
          videoFile: File('/path/to/video1.mp4'),
          title: 'First',
          description: '',
          hashtags: [],
          frameCount: 30,
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        final draft2 = VineDraft(
          id: 'draft_2',
          videoFile: File('/path/to/video2.mp4'),
          title: 'Second',
          description: '',
          hashtags: [],
          frameCount: 45,
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        await service.deleteDraft(draft1.id);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.id, draft2.id);
        expect(drafts.first.title, 'Second');
      });

      test('should do nothing if draft ID does not exist', () async {
        final draft = VineDraft.create(
          videoFile: File('/path/to/video.mp4'),
          title: 'Test',
          description: '',
          hashtags: [],
          frameCount: 30,
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);
        await service.deleteDraft('nonexistent-id');

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
      });
    });

    group('clearAllDrafts', () {
      test('should remove all drafts from storage', () async {
        final now = DateTime.now();
        final draft1 = VineDraft(
          id: 'draft_1',
          videoFile: File('/path/to/video1.mp4'),
          title: 'First',
          description: '',
          hashtags: [],
          frameCount: 30,
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        final draft2 = VineDraft(
          id: 'draft_2',
          videoFile: File('/path/to/video2.mp4'),
          title: 'Second',
          description: '',
          hashtags: [],
          frameCount: 45,
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishError: null,
          publishAttempts: 0,
          aspectRatio: AspectRatio.square,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        await service.clearAllDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should handle clearing when no drafts exist', () async {
        await service.clearAllDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });
    });
  });
}
