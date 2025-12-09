import 'dart:io';

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VineDraft AspectRatio', () {
    test('create() includes aspect ratio', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        videoFile: testFile,
        title: '',
        description: '',
        hashtags: [],
        frameCount: 60,
        selectedApproach: 'test',
        aspectRatio: AspectRatio.vertical,
      );

      expect(draft.aspectRatio, equals(AspectRatio.vertical));
    });

    test('defaults to square if not specified', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        videoFile: testFile,
        title: '',
        description: '',
        hashtags: [],
        frameCount: 60,
        selectedApproach: 'test',
      );

      expect(draft.aspectRatio, equals(AspectRatio.square));
    });

    test('toJson includes aspectRatio', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        videoFile: testFile,
        title: '',
        description: '',
        hashtags: [],
        frameCount: 60,
        selectedApproach: 'test',
        aspectRatio: AspectRatio.vertical,
      );

      final json = draft.toJson();
      expect(json['aspectRatio'], equals('vertical'));
    });

    test('fromJson restores aspectRatio', () {
      final json = {
        'id': 'test-id',
        'videoFilePath': '/path/to/video.mp4',
        'title': '',
        'description': '',
        'hashtags': <String>[],
        'frameCount': 60,
        'selectedApproach': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'publishStatus': 'draft',
        'publishAttempts': 0,
        'aspectRatio': 'vertical',
      };

      final draft = VineDraft.fromJson(json);
      expect(draft.aspectRatio, equals(AspectRatio.vertical));
    });

    test('fromJson defaults to square for legacy drafts', () {
      final json = {
        'id': 'test-id',
        'videoFilePath': '/path/to/video.mp4',
        'title': '',
        'description': '',
        'hashtags': <String>[],
        'frameCount': 60,
        'selectedApproach': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'publishStatus': 'draft',
        'publishAttempts': 0,
        // No aspectRatio field (legacy draft)
      };

      final draft = VineDraft.fromJson(json);
      expect(draft.aspectRatio, equals(AspectRatio.square));
    });
  });
}
