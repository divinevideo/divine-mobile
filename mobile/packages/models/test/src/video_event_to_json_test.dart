// ABOUTME: Regression tests pinning the VideoEvent.toJson contract.
// ABOUTME: Guarantees the JSON shape stays an explicit allow-list of declared
// ABOUTME: persisted fields — no computed getters, no hashCode, no time-
// ABOUTME: dependent values — so a future getter cannot silently leak into
// ABOUTME: caches or relay payloads. Issue: divinevideo/divine-mobile#3365.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:test/test.dart';

final String _id = 'a' * 64;
final String _pubkey = 'b' * 64;
final String _reposterId = '1' * 64;
final String _reposterPubkey = 'c' * 64;
final String _otherCollab = 'd' * 64;
final String _audioEventId = 'e' * 64;
final String _sha256 = 'f' * 64;
const String _subtitleEventRef =
    '39307:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:subtitles:abc123def';

VideoEvent _fullVideo() => VideoEvent(
  id: _id,
  pubkey: _pubkey,
  createdAt: 1704067200,
  eventCreatedAt: 1704067300,
  content: 'hello vine',
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    1704067200 * 1000,
    isUtc: true,
  ),
  title: 'A short loop',
  videoUrl: 'https://cdn.divine.video/video.mp4',
  thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
  duration: 6,
  dimensions: '720x1280',
  mimeType: 'video/mp4',
  sha256: _sha256,
  fileSize: 4096,
  hashtags: const ['vine', 'test'],
  categories: const ['music'],
  publishedAt: '1704067200',
  rawTags: const {'d': 'abc123def', 'platform': 'vine', 'views': '42'},
  vineId: 'abc123def',
  addressableDTag: 'abc123def',
  group: 'community',
  altText: 'A person waves at the camera',
  blurhash: 'LKO2?U%2Tw=w',
  isRepost: true,
  reposterId: _reposterId,
  reposterPubkey: _reposterPubkey,
  reposterPubkeys: [_reposterPubkey],
  repostedAt: DateTime.fromMillisecondsSinceEpoch(
    1704067260 * 1000,
    isUtc: true,
  ),
  isFlaggedContent: true,
  moderationStatus: 'approved',
  originalLoops: 13565,
  originalLikes: 732,
  originalComments: 24,
  originalReposts: 9,
  expirationTimestamp: 4102444800, // year 2100
  audioEventId: _audioEventId,
  audioEventRelay: 'wss://relay.divine.video',
  nostrLikeCount: 12,
  nostrCommentCount: 3,
  nostrRepostCount: 2,
  authorName: 'Test Author',
  authorAvatar: 'https://cdn.divine.video/avatar.jpg',
  collaboratorPubkeys: [_otherCollab],
  inspiredByVideo: const InspiredByInfo(
    addressableId: '34236:abc123:my-video',
    relayUrl: 'wss://relay.divine.video',
  ),
  inspiredByNpub: 'npub1examplenpubvalue',
  clipSourceCredits: const [
    ClipSourceCredit(
      authorPubkey: 'abc123',
      addressableId: '34236:abc123:clip-source',
      relayUrl: 'wss://relay.divine.video',
    ),
  ],
  nostrEventTags: const [
    ['d', 'abc123def'],
    ['title', 'A short loop'],
  ],
  textTrackRef: 'https://cdn.divine.video/captions.vtt',
  textTrackRefs: const [
    'https://cdn.divine.video/captions.vtt',
    _subtitleEventRef,
  ],
  textTrackContent: 'WEBVTT\n\n00:00.000 --> 00:06.000\nHello',
  contentWarningLabels: const ['nudity'],
  moderationLabels: const ['ml-noisy-label'],
  warnLabels: const ['nudity'],
  proofSummary: ProofVerificationSummary(
    status: 'present',
    level: 'basic_proof',
    checkedAt: DateTime.fromMillisecondsSinceEpoch(
      1779494400 * 1000,
      isUtc: true,
    ),
    version: 1,
    checks: const {'proofmode_present': true},
  ),
  isVerifiedArchive: true,
  archiveAudioReuseEnabled: true,
  eventKind: 34236,
  sourceRelay: 'wss://relay.divine.video',
);

const _expectedKeys = <String>{
  'id',
  'pubkey',
  'createdAt',
  'eventCreatedAt',
  'content',
  'title',
  'videoUrl',
  'thumbnailUrl',
  'duration',
  'dimensions',
  'mimeType',
  'sha256',
  'fileSize',
  'hashtags',
  'categories',
  'timestamp',
  'publishedAt',
  'rawTags',
  'vineId',
  'addressableDTag',
  'group',
  'altText',
  'blurhash',
  'isRepost',
  'reposterId',
  'reposterPubkey',
  'reposterPubkeys',
  'repostedAt',
  'isFlaggedContent',
  'moderationStatus',
  'originalLoops',
  'originalLikes',
  'originalComments',
  'originalReposts',
  'expirationTimestamp',
  'audioEventId',
  'audioEventRelay',
  'nostrLikeCount',
  'nostrCommentCount',
  'nostrRepostCount',
  'authorName',
  'authorAvatar',
  'collaboratorPubkeys',
  'inspiredByVideo',
  'inspiredByNpub',
  'clipSourceCredits',
  'textTrackRef',
  'textTrackRefs',
  'textTrackContent',
  'contentWarningLabels',
  'moderationLabels',
  'proofSummary',
  'isVerifiedArchive',
  'archiveAudioReuseEnabled',
  'eventKind',
  'sourceRelay',
};

const _excludedDerivedGetters = <String>{
  'hashCode',
  'nostrCreatedAt',
  'isExpired',
  'shareKind',
  'isAddressableShareKind',
  'stableId',
  'hasAddressableDTag',
  'addressableId',
  'effectiveThumbnailUrl',
  'displayPubkey',
  'displayContent',
  'displayTitle',
  'allHashtags',
  'hasContentWarning',
  'shouldShowWarning',
  'hasSubtitles',
  'hasCollaborators',
  'hasInspiredBy',
  'inspiredByCreatorPubkey',
  'totalLikes',
  'totalLoops',
  'hasLoopMetadata',
  'hasAudioReference',
  'proofModeVerificationLevel',
  'proofModeManifest',
  'proofModeDeviceAttestation',
  'proofModePgpFingerprint',
  'proofModeC2paManifestId',
  'hasProofModeManifest',
  'hasProofModeDeviceAttestation',
  'hasProofModePgpFingerprint',
  'hasProofModeC2paManifestId',
  'hasCreatorIdentityBinding',
  'identityVerifier',
  'hasPortableIdentity',
  'hasProofMode',
  'isVerifiedMobile',
  'isVerifiedWeb',
  'hasBasicProof',
  'isOriginalVine',
  'hasUnknownOriginalDate',
  'isOriginalContent',
  'width',
  'height',
  'isPortrait',
  'fileSizeMB',
  'formattedDuration',
  'hasVideo',
  'isGif',
  'isMp4',
  'isWebM',
};

const _excludedInternalFields = <String>{'nostrEventTags', 'warnLabels'};

/// Adding a new persisted field to [VideoEvent] requires THREE coordinated
/// edits — default-deny is intentional, but the cost is on the contributor:
///   1. Add the `final` field + constructor parameter on [VideoEvent].
///   2. Add the field to [VideoEvent.toJson]'s map literal.
///   3. Add the field name to [_expectedKeys] below + populate it in
///      [_fullVideo].
///
/// Miss only #2 → the "contains exactly the persisted field set" test fails
/// loudly. Miss only #3 → the new field silently leaks through this guard.
void main() {
  group('VideoEvent.toJson', () {
    test('contains exactly the persisted field set', () {
      expect(_fullVideo().toJson().keys.toSet(), equals(_expectedKeys));
    });

    test('omits hashCode and time-dependent isExpired', () {
      final json = _fullVideo().toJson();
      expect(
        json.containsKey('hashCode'),
        isFalse,
        reason: 'hashCode is VM-specific and must never be serialized',
      );
      expect(
        json.containsKey('isExpired'),
        isFalse,
        reason: 'isExpired depends on DateTime.now() and is unstable',
      );
    });

    test('omits all derived getters', () {
      final json = _fullVideo().toJson();
      for (final getter in _excludedDerivedGetters) {
        expect(
          json.containsKey(getter),
          isFalse,
          reason: '$getter is a derived getter and must not be persisted',
        );
      }
    });

    test('omits internal fields kept only for republishing or UI state', () {
      final json = _fullVideo().toJson();
      for (final field in _excludedInternalFields) {
        expect(
          json.containsKey(field),
          isFalse,
          reason: '$field is internal model state, not part of the JSON shape',
        );
      }
    });

    test('produces identical output across calls', () {
      final video = _fullVideo();
      expect(video.toJson(), equals(video.toJson()));
    });

    test('serializes inspiredByVideo as a nested map, not a raw object', () {
      final json = _fullVideo().toJson();
      expect(json['inspiredByVideo'], isA<Map<String, dynamic>>());
      final nested = json['inspiredByVideo']! as Map<String, dynamic>;
      expect(nested['addressableId'], equals('34236:abc123:my-video'));
      expect(nested['relayUrl'], equals('wss://relay.divine.video'));
    });

    test('serializes timestamp and repostedAt as ISO 8601 strings', () {
      final json = _fullVideo().toJson();
      expect(json['timestamp'], isA<String>());
      expect(json['timestamp'], equals('2024-01-01T00:00:00.000Z'));
      expect(json['repostedAt'], isA<String>());
      expect(json['repostedAt'], equals('2024-01-01T00:01:00.000Z'));
    });

    test('survives jsonEncode round-trip', () {
      expect(() => jsonEncode(_fullVideo().toJson()), returnsNormally);
    });

    test(
      'serializes a null inspiredByVideo as a null value (key always present)',
      () {
        final minimal = VideoEvent(
          id: _id,
          pubkey: _pubkey,
          createdAt: 1704067200,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            1704067200 * 1000,
            isUtc: true,
          ),
        );
        expect(_fullVideo().toJson().containsKey('inspiredByVideo'), isTrue);
        expect(minimal.toJson().containsKey('inspiredByVideo'), isTrue);
        expect(minimal.toJson()['inspiredByVideo'], isNull);
      },
    );
  });

  group('VideoEvent.fromJson', () {
    test('round-trips every persisted field through toJson', () {
      final original = _fullVideo();
      final restored = VideoEvent.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, equals(original.id));
      expect(restored.pubkey, equals(original.pubkey));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.content, equals(original.content));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.title, equals(original.title));
      expect(restored.videoUrl, equals(original.videoUrl));
      expect(restored.thumbnailUrl, equals(original.thumbnailUrl));
      expect(restored.duration, equals(original.duration));
      expect(restored.dimensions, equals(original.dimensions));
      expect(restored.mimeType, equals(original.mimeType));
      expect(restored.sha256, equals(original.sha256));
      expect(restored.fileSize, equals(original.fileSize));
      expect(restored.hashtags, equals(original.hashtags));
      expect(restored.categories, equals(original.categories));
      expect(restored.publishedAt, equals(original.publishedAt));
      expect(restored.rawTags, equals(original.rawTags));
      expect(restored.vineId, equals(original.vineId));
      expect(restored.addressableDTag, equals(original.addressableDTag));
      expect(restored.group, equals(original.group));
      expect(restored.altText, equals(original.altText));
      expect(restored.blurhash, equals(original.blurhash));
      expect(restored.isRepost, equals(original.isRepost));
      expect(restored.reposterId, equals(original.reposterId));
      expect(restored.reposterPubkey, equals(original.reposterPubkey));
      expect(restored.reposterPubkeys, equals(original.reposterPubkeys));
      expect(restored.repostedAt, equals(original.repostedAt));
      expect(restored.isFlaggedContent, equals(original.isFlaggedContent));
      expect(restored.moderationStatus, equals(original.moderationStatus));
      expect(restored.originalLoops, equals(original.originalLoops));
      expect(restored.originalLikes, equals(original.originalLikes));
      expect(restored.originalComments, equals(original.originalComments));
      expect(restored.originalReposts, equals(original.originalReposts));
      expect(
        restored.expirationTimestamp,
        equals(original.expirationTimestamp),
      );
      expect(restored.audioEventId, equals(original.audioEventId));
      expect(restored.audioEventRelay, equals(original.audioEventRelay));
      expect(restored.nostrLikeCount, equals(original.nostrLikeCount));
      expect(restored.nostrCommentCount, equals(original.nostrCommentCount));
      expect(restored.nostrRepostCount, equals(original.nostrRepostCount));
      expect(restored.authorName, equals(original.authorName));
      expect(restored.authorAvatar, equals(original.authorAvatar));
      expect(
        restored.collaboratorPubkeys,
        equals(original.collaboratorPubkeys),
      );
      expect(restored.inspiredByVideo, equals(original.inspiredByVideo));
      expect(restored.inspiredByNpub, equals(original.inspiredByNpub));
      expect(restored.clipSourceCredits, equals(original.clipSourceCredits));
      expect(
        restored.clipSourceCredits.single.addressableId,
        equals(original.clipSourceCredits.single.addressableId),
      );
      expect(
        restored.clipSourceCredits.single.relayUrl,
        equals(original.clipSourceCredits.single.relayUrl),
      );
      expect(restored.textTrackRef, equals(original.textTrackRef));
      expect(restored.textTrackContent, equals(original.textTrackContent));
      expect(
        restored.contentWarningLabels,
        equals(original.contentWarningLabels),
      );
      expect(restored.proofSummary, equals(original.proofSummary));
      expect(restored.isVerifiedArchive, isTrue);
      expect(restored.archiveAudioReuseEnabled, isTrue);
    });

    test('hydrates addressableDTag from rawTags for older cache entries', () {
      final json = _fullVideo().toJson()..remove('addressableDTag');

      final restored = VideoEvent.fromJson(json);

      expect(restored.addressableDTag, equals('abc123def'));
      expect(restored.addressableId, equals('34236:$_pubkey:abc123def'));
    });

    test('round-trips a minimal video with only required fields', () {
      final minimal = VideoEvent(
        id: _id,
        pubkey: _pubkey,
        createdAt: 1704067200,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          1704067200 * 1000,
          isUtc: true,
        ),
      );
      final restored = VideoEvent.fromJson(
        jsonDecode(jsonEncode(minimal.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, equals(minimal.id));
      expect(restored.timestamp, equals(minimal.timestamp));
      expect(restored.videoUrl, isNull);
      expect(restored.inspiredByVideo, isNull);
      expect(restored.proofSummary, isNull);
      expect(restored.hashtags, isEmpty);
      expect(restored.isRepost, isFalse);
    });

    test('defaults internal-only fields omitted from toJson to empty', () {
      final restored = VideoEvent.fromJson(
        jsonDecode(jsonEncode(_fullVideo().toJson())) as Map<String, dynamic>,
      );

      // nostrEventTags and warnLabels are not persisted and default to empty;
      // moderationLabels IS persisted (a hard content-filter signal).
      expect(restored.nostrEventTags, isEmpty);
      expect(restored.warnLabels, isEmpty);
    });
  });
}
