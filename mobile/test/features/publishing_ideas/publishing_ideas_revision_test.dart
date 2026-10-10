import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_revision.dart';

void main() {
  group('publishingIdeasRevision', () {
    test('recorder audio changes invalidate an ideas-only transcript', () {
      final first = publishingIdeasRevision(
        {},
        [],
        selectedSound: {'id': 'sound', 'url': 'first.wav'},
      );
      final changed = publishingIdeasRevision(
        {},
        [],
        selectedSound: {'id': 'sound', 'url': 'second.wav'},
      );
      expect(changed, isNot(first));
      expect(publishingIdeasRevision({}, []), isNot(first));
    });
    test('reopening with a new container and thumbnail keeps the transcript revision', () {
      final old = publishingIdeasRevision(
        {
          'audio': {
            'id': 'local_import_take',
            'url': '/old/Documents/voice_over_recordings/take.wav',
          },
        },
        [
          {
            'id': 'clip',
            'thumbnailPath': 'old.jpg',
            'trimStartMs': 10,
            'proofManifestJson': 'old proof',
          },
        ],
      );
      final reopened = publishingIdeasRevision(
        {
          'audio': {
            'id': 'local_import_take',
            'url': '/new/Documents/voice_over_recordings/take.wav',
          },
        },
        [
          {
            'proofManifestJson': 'new proof',
            'trimStartMs': 10,
            'id': 'clip',
            'thumbnailPath': 'new.jpg',
          },
        ],
      );
      expect(reopened, old);
      expect(
        publishingIdeasRevision({}, [
          {'id': 'clip', 'trimStartMs': 20},
        ]),
        isNot(old),
      );
    });
  });
}
