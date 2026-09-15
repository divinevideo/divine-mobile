// ABOUTME: Tests source context captured when a sound is saved from a video.
// ABOUTME: Verifies passive transcript parsing without network transcription.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/saved_sound_context_builder.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

const _fullEventId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _fullPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

VideoEvent _video({
  String? textTrackContent,
  String content = 'The original post description',
}) => VideoEvent(
  id: _fullEventId,
  pubkey: _fullPubkey,
  createdAt: 1700000000,
  content: content,
  timestamp: DateTime.utc(2026, 7, 31),
  title: 'Original post title',
  thumbnailUrl: 'https://example.com/thumbnail.jpg',
  textTrackContent: textTrackContent,
);

void main() {
  group(SavedSoundContextBuilder, () {
    test('captures recognizable source post details with full IDs', () {
      final context = const SavedSoundContextBuilder().fromVideo(
        _video(),
        creatorName: 'Rabble',
      );

      expect(context.videoEventId, _fullEventId);
      expect(context.creatorPubkey, _fullPubkey);
      expect(context.creatorName, 'Rabble');
      expect(context.title, 'Original post title');
      expect(context.description, 'The original post description');
      expect(context.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(context.transcript, isNull);
    });

    test('keeps the wire-format attribution line out of the description', () {
      final npub = normalizeToNpub(_fullPubkey)!;
      final context = const SavedSoundContextBuilder().fromVideo(
        _video(
          content:
              'The original post description\n\n'
              '${inspiredByAttributionLine(npub)}',
        ),
      );

      expect(context.description, 'The original post description');
    });

    test('turns embedded VTT cues into readable transcript text', () {
      final context = const SavedSoundContextBuilder().fromVideo(
        _video(
          textTrackContent: '''
WEBVTT

00:00:00.000 --> 00:00:01.000
hello there

00:00:01.000 --> 00:00:02.000
general kenobi
''',
        ),
      );

      expect(context.transcript, 'hello there general kenobi');
    });

    test('emits adjacent duplicate cue text only once', () {
      final context = const SavedSoundContextBuilder().fromVideo(
        _video(
          textTrackContent: '''
WEBVTT

00:00:00.000 --> 00:00:01.000
music

00:00:01.000 --> 00:00:02.000
music

00:00:02.000 --> 00:00:03.000
continues
''',
        ),
      );

      expect(context.transcript, 'music continues');
    });

    test('treats absent, empty, and malformed captions as no transcript', () {
      const builder = SavedSoundContextBuilder();

      expect(builder.fromVideo(_video()).transcript, isNull);
      expect(
        builder.fromVideo(_video(textTrackContent: '  ')).transcript,
        isNull,
      );
      expect(
        builder
            .fromVideo(_video(textTrackContent: 'not actually WebVTT'))
            .transcript,
        isNull,
      );
    });
  });
}
