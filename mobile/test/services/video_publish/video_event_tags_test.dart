// ABOUTME: Tests for the pure video-event tag builders: reply threading, text
// ABOUTME: tracks, descriptive metadata, and creator credits

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show ClipSourceCredit;
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/video_event_tags.dart';

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _third =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _rootEventId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _commentId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

void main() {
  group('addVideoReplyTags', () {
    test('threads a top-level reply onto the root video', () {
      final tags = <List<String>>[];

      addVideoReplyTags(
        tags,
        const VideoReplyContext(
          rootEventId: _rootEventId,
          rootEventKind: 34236,
          rootAuthorPubkey: _other,
          rootAddressableId: '34236:$_other:vine-1',
        ),
        addReplyToFeed: false,
      );

      expect(
        tags,
        equals([
          ['E', _rootEventId, '', _other],
          ['K', '34236'],
          ['P', _other],
          ['A', '34236:$_other:vine-1', ''],
          ['e', _rootEventId, '', _other],
          ['k', '34236'],
          ['p', _other],
          ['a', '34236:$_other:vine-1', ''],
        ]),
      );
    });

    test('threads a nested reply onto the parent comment', () {
      final tags = <List<String>>[];

      addVideoReplyTags(
        tags,
        const VideoReplyContext(
          rootEventId: _rootEventId,
          rootEventKind: 34236,
          rootAuthorPubkey: _other,
          parentCommentId: _commentId,
          parentAuthorPubkey: _third,
        ),
        addReplyToFeed: true,
      );

      expect(
        tags,
        equals([
          ['E', _rootEventId, '', _other],
          ['K', '34236'],
          ['P', _other],
          ['e', _commentId, '', _third],
          ['k', EventKind.comment.toString()],
          ['p', _third],
          ['divine:reply_visibility', 'feed'],
        ]),
      );
    });
  });

  group('addTextTrackTags', () {
    test('emits one captions tag per ref', () {
      final tags = <List<String>>[];

      addTextTrackTags(
        tags,
        refs: ['https://blossom.example/a.vtt', '39307:$_self:subtitles:v'],
        lang: 'de',
      );

      expect(
        tags,
        equals([
          [
            'text-track',
            'https://blossom.example/a.vtt',
            'wss://relay.divine.video',
            'captions',
            'de',
          ],
          [
            'text-track',
            '39307:$_self:subtitles:v',
            'wss://relay.divine.video',
            'captions',
            'de',
          ],
        ]),
      );
    });
  });

  group('addVideoMetadataTags', () {
    test('emits every descriptive tag in publish order', () {
      final tags = <List<String>>[];
      final upload = PendingUpload.create(
        localVideoPath: '/tmp/video.mp4',
        nostrPubkey: _self,
        title: 'Plants',
        description: 'A plant video',
        hashtags: const ['garden', 'green'],
        videoDuration: const Duration(milliseconds: 6400),
      );

      addVideoMetadataTags(
        tags,
        upload: upload,
        publishedAt: DateTime.fromMillisecondsSinceEpoch(1700000000500),
        language: 'de',
        contentWarning: 'nudity, violence',
        expirationTimestamp: 1800000000,
      );

      expect(
        tags,
        equals([
          ['title', 'Plants'],
          ['summary', 'A plant video'],
          ['t', 'garden'],
          ['t', 'green'],
          ['L', 'ISO-639-1'],
          ['l', 'de', 'ISO-639-1'],
          ['content-warning', 'nudity'],
          ['L', 'content-warning'],
          ['l', 'nudity', 'content-warning'],
          ['l', 'violence', 'content-warning'],
          ['published_at', '1700000000'],
          ['duration', '6'],
          ['alt', 'Plants'],
          ['expiration', '1800000000'],
        ]),
      );
    });

    test('falls back to the description, then a generic alt text', () {
      final withDescription = <List<String>>[];
      addVideoMetadataTags(
        withDescription,
        upload: PendingUpload.create(
          localVideoPath: '/tmp/video.mp4',
          nostrPubkey: _self,
          description: 'Only a description',
        ),
        publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(
        withDescription,
        anyElement(equals(['alt', 'Only a description'])),
      );
      expect(withDescription.any((tag) => tag.first == 'title'), isFalse);

      final bare = <List<String>>[];
      addVideoMetadataTags(
        bare,
        upload: PendingUpload.create(
          localVideoPath: '/tmp/video.mp4',
          nostrPubkey: _self,
        ),
        publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(
        bare,
        equals([
          ['published_at', '0'],
          ['alt', 'Short video'],
        ]),
      );
    });
  });

  group('addVideoCreditTags', () {
    test('credits collaborators, mentions and the inspired-by creator', () {
      final tags = <List<String>>[];

      addVideoCreditTags(
        tags,
        selfPubkeyHex: _self,
        isReply: false,
        collaboratorPubkeys: const [_other],
        mentionedPubkeys: const [_other, _third],
        inspiredByAddressableId: '34236:$_third:vine-9',
        inspiredByRelayUrl: 'wss://relay.example',
      );

      expect(
        tags,
        equals([
          ['p', _other, 'wss://relay.divine.video', 'collaborator'],
          ['p', _third, 'wss://relay.divine.video', 'mention'],
          ['a', '34236:$_third:vine-9', 'wss://relay.example', 'mention'],
        ]),
      );
    });

    test(
      'adds a notifying p tag for an inspired-by creator not yet tagged',
      () {
        final tags = <List<String>>[];

        addVideoCreditTags(
          tags,
          selfPubkeyHex: _self,
          isReply: false,
          inspiredByAddressableId: '34236:$_other:vine-9',
        );

        expect(
          tags,
          equals([
            [
              'a',
              '34236:$_other:vine-9',
              'wss://relay.divine.video',
              'mention',
            ],
            ['p', _other, 'wss://relay.divine.video', 'inspired-by'],
          ]),
        );
      },
    );

    test('never credits the publishing account itself', () {
      final tags = <List<String>>[];

      addVideoCreditTags(
        tags,
        selfPubkeyHex: _self.toUpperCase(),
        isReply: false,
        inspiredByAddressableId: '34236:$_self:vine-9',
        clipSourceCredits: const [
          ClipSourceCredit(
            authorPubkey: _self,
            addressableId: '34236:$_self:c',
          ),
        ],
      );

      expect(tags, isEmpty);
    });

    test('a reply keeps the a tag but emits no new inspired-by p tags', () {
      final tags = <List<String>>[];

      addVideoCreditTags(
        tags,
        selfPubkeyHex: _self,
        isReply: true,
        inspiredByAddressableId: '34236:$_other:vine-9',
        clipSourceCredits: const [
          ClipSourceCredit(
            authorPubkey: _third,
            addressableId: '34236:$_third:c',
          ),
        ],
      );

      expect(tags.where((tag) => tag.first == 'a'), hasLength(2));
      expect(tags.any((tag) => tag.first == 'p'), isFalse);
    });
  });
}
