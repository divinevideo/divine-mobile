// ABOUTME: Tests for DivineVideoDraft.stickerCredits: the tags a draft's
// ABOUTME: social stickers add come from the layers it is rendered with.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';

const _pubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

const _hashtag = SocialStickerData(
  kind: SocialStickerKind.hashtag,
  hashtag: 'summer',
);

const _mention = SocialStickerData(
  kind: SocialStickerKind.mention,
  pubkey: _pubkey,
  name: 'alice',
);

Map<String, dynamic> _layer(String id, SocialStickerData sticker) => {
  'id': id,
  'type': 'widget',
  'exportConfigs': {'id': id, 'meta': sticker.toMeta()},
};

DivineVideoDraft _draft({
  required Map<String, dynamic> editorStateHistory,
  required Map<String, dynamic> editorEditingParameters,
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: const [],
  title: '',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  editorStateHistory: editorStateHistory,
  editorEditingParameters: editorEditingParameters,
);

void main() {
  group(DivineVideoDraft, () {
    group('stickerCredits', () {
      test('reads the stickers placed after the last Done', () {
        // Done saved the hashtag; the user then swapped it for a mention and
        // backed out, which saves the history alone.
        final draft = _draft(
          editorEditingParameters: {
            'layers': [_layer('hashtag', _hashtag)],
          },
          editorStateHistory: {
            'version': '6.5.0',
            'position': 1,
            'references': {
              'hashtag': _layer('hashtag', _hashtag),
              'mention': _layer('mention', _mention),
            },
            'history': [
              {
                'layers': [
                  {'id': 'hashtag'},
                ],
              },
              {
                'layers': [
                  {'id': 'mention'},
                ],
              },
            ],
          },
        );

        final credits = draft.stickerCredits;

        expect(credits.mentionPubkeys, equals({_pubkey}));
        expect(credits.hashtags, isEmpty);
      });

      test('reads none once every edit is undone', () {
        final draft = _draft(
          editorEditingParameters: {
            'layers': [_layer('hashtag', _hashtag)],
          },
          editorStateHistory: {'version': '6.5.0', 'position': -1},
        );

        expect(draft.stickerCredits, equals(const SocialStickerCredits()));
      });

      test('fails rather than credit nothing for a history it cannot read', () {
        final draft = _draft(
          editorEditingParameters: const {},
          editorStateHistory: {
            'version': '6.5.0',
            'position': 0,
            'history': 'not a history',
          },
        );

        expect(() => draft.stickerCredits, throwsA(anything));
      });
    });
  });
}
