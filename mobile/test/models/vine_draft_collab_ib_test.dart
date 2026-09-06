// ABOUTME: Tests for collaborator and Inspired By fields in VineDraft
// ABOUTME: Validates JSON round-trip, backward compat, and copyWith

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio, InspiredByInfo;
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _testClip() => DivineVideoClip(
  id: 'test_clip',
  video: EditorVideo.file('/path/to/video.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  targetAspectRatio: AspectRatio.square,
  originalAspectRatio: 9 / 16,
);

void main() {
  group('VineDraft collaborator and Inspired By fields', () {
    group('create', () {
      test('defaults to empty collaborators and null IB', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
        );

        expect(draft.collaboratorPubkeys, isEmpty);
        expect(draft.inspiredByVideo, isNull);
        expect(draft.inspiredByNpub, isNull);
      });

      test('accepts collaborator pubkeys', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        );

        expect(draft.collaboratorPubkeys, hasLength(2));
      });

      test('accepts inspiredByVideo', () {
        const ib = InspiredByInfo(
          addressableId:
              '34236:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:my-video',
          relayUrl: 'wss://relay.divine.video',
        );

        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          inspiredByVideo: ib,
        );

        expect(draft.inspiredByVideo, isNotNull);
        expect(draft.inspiredByVideo!.addressableId, equals(ib.addressableId));
      });

      test('accepts inspiredByNpub', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          inspiredByNpub: 'npub1testvalue123',
        );

        expect(draft.inspiredByNpub, equals('npub1testvalue123'));
      });

      test('accepts content warnings', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          contentWarning: ContentLabel.toCsv({
            ContentLabel.nudity,
            ContentLabel.violence,
          }),
        );

        expect(
          draft.contentWarnings,
          equals({ContentLabel.nudity, ContentLabel.violence}),
        );
      });
    });

    group('toJson', () {
      test('includes collaboratorPubkeys when non-empty', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          },
        );

        final json = draft.toJson();
        expect(json.containsKey('collaboratorPubkeys'), isTrue);
        expect(
          json['collaboratorPubkeys'],
          equals([
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ]),
        );
      });

      test('collaboratorPubkeys serializes as List, not Set', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        );

        final json = draft.toJson();
        expect(json['collaboratorPubkeys'], isA<List>());
      });

      test('omits collaboratorPubkeys when empty', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
        );

        final json = draft.toJson();
        expect(json.containsKey('collaboratorPubkeys'), isFalse);
      });

      test('includes inspiredByVideo when set', () {
        const ib = InspiredByInfo(
          addressableId: '34236:pubkey123:dtag456',
          relayUrl: 'wss://relay.divine.video',
        );

        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          inspiredByVideo: ib,
        );

        final json = draft.toJson();
        expect(json.containsKey('inspiredByVideo'), isTrue);
        final ibJson = json['inspiredByVideo'] as Map<String, dynamic>;
        expect(ibJson['addressableId'], equals('34236:pubkey123:dtag456'));
      });

      test('omits inspiredByVideo when null', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
        );

        final json = draft.toJson();
        expect(json.containsKey('inspiredByVideo'), isFalse);
      });

      test('includes inspiredByNpub when set', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          inspiredByNpub: 'npub1abc',
        );

        final json = draft.toJson();
        expect(json['inspiredByNpub'], equals('npub1abc'));
      });

      test('omits inspiredByNpub when null', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
        );

        final json = draft.toJson();
        expect(json.containsKey('inspiredByNpub'), isFalse);
      });

      test('includes contentWarning when set', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          contentWarning: 'nudity,violence',
        );

        final json = draft.toJson();
        expect(json['contentWarning'], equals('nudity,violence'));
      });
    });

    group('fromJson round-trip', () {
      test('preserves collaboratorPubkeys through serialization', () {
        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Collab Video',
          description: 'With friends',
          hashtags: const {'collab'},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        );

        final json = original.toJson();
        final restored = DivineVideoDraft.fromJson(json, '/path/to');

        expect(restored.collaboratorPubkeys, hasLength(2));
        expect(
          restored.collaboratorPubkeys.first,
          equals(
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        );
      });

      test('preserves inspiredByVideo through serialization', () {
        const ib = InspiredByInfo(
          addressableId: '34236:pubkey123:dtag456',
          relayUrl: 'wss://relay.divine.video',
        );

        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'IB Video',
          description: 'Inspired',
          hashtags: const {},
          selectedApproach: 'native',
          inspiredByVideo: ib,
        );

        final json = original.toJson();
        final restored = DivineVideoDraft.fromJson(json, '/path/to');

        expect(restored.inspiredByVideo, isNotNull);
        expect(
          restored.inspiredByVideo!.addressableId,
          equals('34236:pubkey123:dtag456'),
        );
        expect(
          restored.inspiredByVideo!.relayUrl,
          equals('wss://relay.divine.video'),
        );
      });

      test('preserves inspiredByNpub through serialization', () {
        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'IB Video',
          description: 'Inspired by person',
          hashtags: const {},
          selectedApproach: 'native',
          inspiredByNpub: 'npub1testvalue',
        );

        final json = original.toJson();
        final restored = DivineVideoDraft.fromJson(json, '/path/to');

        expect(restored.inspiredByNpub, equals('npub1testvalue'));
      });

      test('preserves captionMentions through serialization', () {
        // The draft is the only thing that survives an app restart, so a pick
        // the author made before backgrounding has to come back with it.
        const mention = CaptionMention(
          display: 'OG-AB',
          pubkey:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          start: 3,
          end: 9,
        );
        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Mention Video',
          description: 'to @OG-AB',
          hashtags: const {},
          selectedApproach: 'native',
          captionMentions: const [mention],
        );

        final restored = DivineVideoDraft.fromJson(
          original.toJson(),
          '/path/to',
        );

        expect(restored.captionMentions, equals(const [mention]));
      });

      test('omits captionMentions from json when there are none', () {
        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'No Mentions',
          description: 'plain',
          hashtags: const {},
          selectedApproach: 'native',
        );

        expect(original.toJson().containsKey('captionMentions'), isFalse);
        expect(
          DivineVideoDraft.fromJson(original.toJson(), '/p').captionMentions,
          isEmpty,
        );
      });

      test('preserves contentWarning through serialization', () {
        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Warning Video',
          description: 'Sensitive content',
          hashtags: const {},
          selectedApproach: 'native',
          contentWarning: 'nudity,violence',
        );

        final json = original.toJson();
        final restored = DivineVideoDraft.fromJson(json, '/path/to');

        expect(restored.contentWarning, equals('nudity,violence'));
        expect(
          restored.contentWarnings,
          equals({ContentLabel.nudity, ContentLabel.violence}),
        );
      });

      test('preserves all collab+IB fields together', () {
        const ib = InspiredByInfo(addressableId: '34236:pubkey:dtag');

        final original = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Full Collab',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          },
          inspiredByVideo: ib,
          inspiredByNpub: 'npub1both',
        );

        final json = original.toJson();
        final restored = DivineVideoDraft.fromJson(json, '/path/to');

        expect(restored.collaboratorPubkeys, hasLength(1));
        expect(restored.inspiredByVideo, isNotNull);
        expect(restored.inspiredByNpub, equals('npub1both'));
      });
    });

    group('backward compatibility', () {
      test('old drafts without collab/IB fields load with defaults', () {
        final json = {
          'id': 'old_draft',
          'videoFilePath': 'video.mp4',
          'title': 'Old Draft',
          'description': 'Before collabs',
          'hashtags': ['old'],
          'selectedApproach': 'native',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'lastModified': '2025-01-01T00:00:00.000Z',
          'publishStatus': 'draft',
          'publishAttempts': 0,
          // No collaboratorPubkeys, inspiredByVideo, or inspiredByNpub
        };

        final draft = DivineVideoDraft.fromJson(json, '/path/to');

        expect(draft.collaboratorPubkeys, isEmpty);
        expect(draft.inspiredByVideo, isNull);
        expect(draft.inspiredByNpub, isNull);
      });
    });

    group('copyWith', () {
      test('preserves collab fields when not updated', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Original',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          },
          inspiredByNpub: 'npub1keep',
        );

        final updated = draft.copyWith(title: 'Updated Title');

        expect(updated.title, equals('Updated Title'));
        expect(updated.collaboratorPubkeys, hasLength(1));
        expect(updated.inspiredByNpub, equals('npub1keep'));
      });

      test('preserves contentWarning when not updated', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Original',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          contentWarning: 'nudity',
        );

        final updated = draft.copyWith(title: 'Updated Title');

        expect(updated.title, equals('Updated Title'));
        expect(updated.contentWarning, equals('nudity'));
        expect(updated.contentWarnings, equals({ContentLabel.nudity}));
      });

      test('can update collaboratorPubkeys', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
          collaboratorPubkeys: {
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          },
        );

        final updated = draft.copyWith(
          collaboratorPubkeys: {
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          },
        );

        expect(updated.collaboratorPubkeys, hasLength(1));
        expect(
          updated.collaboratorPubkeys.first,
          equals(
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        );
      });

      test('can update inspiredByVideo', () {
        final draft = DivineVideoDraft.create(
          clips: [_testClip()],
          title: 'Test',
          description: '',
          hashtags: const {},
          selectedApproach: 'native',
        );

        const ib = InspiredByInfo(addressableId: '34236:pub:dtag');
        final updated = draft.copyWith(inspiredByVideo: ib);

        expect(updated.inspiredByVideo, isNotNull);
        expect(
          updated.inspiredByVideo!.addressableId,
          equals('34236:pub:dtag'),
        );
      });
    });
  });
}
