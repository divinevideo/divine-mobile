// ABOUTME: Regression tests for app-layer profile feed enrichment merge.
// ABOUTME: Ensures Nostr-only metadata is not dropped when REST copies win.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_enrichment_merge.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video({
  required String id,
  String pubkey = 'pubkey',
  String? vineId,
  String? addressableDTag,
  String? textTrackRef,
  String? textTrackLang,
  List<String> textTrackRefs = const [],
  String? textTrackContent,
  int? eventCreatedAt,
  List<List<String>> nostrEventTags = const [],
  List<String> hashtags = const [],
  String? title,
  int? nostrLikeCount,
  int? nostrCommentCount,
  int? nostrRepostCount,
  List<String> categories = const [],
  List<String> moderationLabels = const [],
  ProofVerificationSummary? proofSummary,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    vineId: vineId,
    addressableDTag: addressableDTag,
    textTrackRef: textTrackRef,
    textTrackLang: textTrackLang,
    textTrackRefs: textTrackRefs,
    textTrackContent: textTrackContent,
    eventCreatedAt: eventCreatedAt,
    nostrEventTags: nostrEventTags,
    hashtags: hashtags,
    title: title,
    nostrLikeCount: nostrLikeCount,
    nostrCommentCount: nostrCommentCount,
    nostrRepostCount: nostrRepostCount,
    categories: categories,
    moderationLabels: moderationLabels,
    proofSummary: proofSummary,
  );
}

void main() {
  group('mergeProfileFeedEnrichment', () {
    test('fills addressable d tag from enriched Nostr copy', () {
      final current = _video(id: 'rest', vineId: 'video-d-tag');
      final enriched = _video(
        id: 'nostr',
        vineId: 'video-d-tag',
        addressableDTag: 'video-d-tag',
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(current)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged.single.addressableDTag, equals('video-d-tag'));
      expect(merged.single.addressableId, equals('34236:pubkey:video-d-tag'));
    });

    test('fills plural text-track refs from enriched Nostr copy', () {
      final current = _video(id: 'rest', vineId: 'video-subtitles');
      final enriched = _video(
        id: 'nostr',
        vineId: 'video-subtitles',
        textTrackRef: 'https://media.divine.video/subtitle-vtt',
        textTrackLang: 'ja',
        textTrackRefs: const [
          'https://media.divine.video/subtitle-vtt',
          '39307:pubkey:subtitles:video-subtitles',
        ],
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(current)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged, hasLength(1));
      expect(
        merged.single.textTrackRef,
        equals('https://media.divine.video/subtitle-vtt'),
      );
      expect(merged.single.textTrackLang, 'ja');
      expect(merged.single.textTrackRefs, [
        'https://media.divine.video/subtitle-vtt',
        '39307:pubkey:subtitles:video-subtitles',
      ]);
    });

    test('does not inherit stale embedded text when current has refs', () {
      final current = _video(
        id: 'nostr',
        vineId: 'video-subtitles',
        textTrackRef: 'https://media.divine.video/edited.vtt',
      );
      final enriched = _video(
        id: 'rest',
        vineId: 'video-subtitles',
        textTrackContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nstale\n',
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(current)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged.single.textTrackRef, current.textTrackRef);
      expect(merged.single.textTrackContent, isNull);
    });

    test('does not reintroduce source videos missing from current state', () {
      final staleSource = _video(id: 'old-rest', vineId: 'old-vine');
      final current = _video(id: 'new-rest', vineId: 'new-vine');
      final enriched = _video(
        id: 'old-nostr',
        vineId: 'old-vine',
        textTrackRef: 'https://media.divine.video/stale.vtt',
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(staleSource)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged, [current]);
    });

    test('uses raw tags from a strictly newer enriched event', () {
      final current = _video(
        id: 'rest',
        vineId: 'video-d-tag',
        eventCreatedAt: 100,
        nostrEventTags: const [
          ['d', 'video-d-tag'],
          ['t', 'stale'],
        ],
        hashtags: const ['stale'],
        title: 'Stale title',
        nostrLikeCount: 11,
        nostrCommentCount: 7,
        nostrRepostCount: 3,
        categories: const ['comedy'],
        moderationLabels: const ['label'],
        proofSummary: const ProofVerificationSummary(
          status: 'present',
          level: 'basic_proof',
          version: 1,
          checks: {'proofmode_present': true},
        ),
      );
      final enriched = _video(
        id: 'nostr',
        vineId: 'video-d-tag',
        eventCreatedAt: 101,
        nostrEventTags: const [
          ['d', 'video-d-tag'],
          ['t', 'current'],
        ],
        hashtags: const ['current'],
        title: 'Current title',
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(current)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged.single.nostrEventTags, enriched.nostrEventTags);
      expect(merged.single.hashtags, enriched.hashtags);
      expect(merged.single.title, enriched.title);
      expect(merged.single.id, enriched.id);
      expect(merged.single.nostrLikeCount, 11);
      expect(merged.single.nostrCommentCount, 7);
      expect(merged.single.nostrRepostCount, 3);
      expect(merged.single.categories, ['comedy']);
      expect(merged.single.moderationLabels, ['label']);
      expect(merged.single.proofSummary, current.proofSummary);
    });

    test('keeps raw tags from a newer current event', () {
      final current = _video(
        id: 'nostr-current',
        vineId: 'video-d-tag',
        eventCreatedAt: 102,
        nostrEventTags: const [
          ['d', 'video-d-tag'],
          ['t', 'current'],
        ],
      );
      final enriched = _video(
        id: 'stale-enrichment',
        vineId: 'video-d-tag',
        eventCreatedAt: 101,
        nostrEventTags: const [
          ['d', 'video-d-tag'],
          ['t', 'stale'],
        ],
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(current)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged.single.nostrEventTags, current.nostrEventTags);
      expect(merged.single.id, current.id);
    });
  });
}
