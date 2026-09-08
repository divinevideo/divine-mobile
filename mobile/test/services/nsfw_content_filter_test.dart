import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

class _FakeLabelEvent extends Fake implements Event {
  _FakeLabelEvent({required this.pubkey, required this.tags});

  @override
  String get id =>
      '8888888888888888888888888888888888888888888888888888888888888888';

  @override
  int get createdAt => 0;

  @override
  final String pubkey;

  @override
  final List<List<String>> tags;
}

const _testPubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

VideoEvent _createVideo({
  List<String> contentWarningLabels = const [],
  List<String> moderationLabels = const [],
  List<String> hashtags = const [],
  String? sha256,
  String? vineId,
  String pubkey = _testPubkey,
}) {
  return VideoEvent(
    id: 'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2',
    pubkey: pubkey,
    createdAt: DateTime(2025).millisecondsSinceEpoch,
    content: '',
    timestamp: DateTime(2025),
    contentWarningLabels: contentWarningLabels,
    moderationLabels: moderationLabels,
    hashtags: hashtags,
    sha256: sha256,
    vineId: vineId,
    addressableDTag: vineId,
  );
}

void main() {
  group('createNsfwFilter', () {
    late AgeVerificationService ageService;
    late ContentFilterService contentFilterService;
    late _MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late ModerationLabelService moderationLabelService;

    Future<void> seedModerationLabels(List<List<String>> tags) async {
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (
          events: <Event>[
            _FakeLabelEvent(
              pubkey: moderationLabelService.divineModerationPubkeyHex,
              tags: tags,
            ),
          ],
          timedOut: false,
          noRelays: false,
        ),
      );

      await moderationLabelService.subscribeToLabeler(
        moderationLabelService.divineModerationPubkeyHex,
      );
    }

    setUpAll(() {
      registerFallbackValue(<Filter>[_FakeFilter()]);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ageService = AgeVerificationService(
        preferences: prefs,
        currentPubkeyHex: () => _testPubkey,
      );
      contentFilterService = ContentFilterService(
        ageVerificationService: ageService,
      );
      await contentFilterService.initialize();
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      // The moderation labeler opens a live tail after its backfill (#8255).
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => StreamController<Event>.broadcast().stream);
      moderationLabelService = ModerationLabelService(
        nostrClient: mockNostrClient,
        authService: mockAuthService,
        sharedPreferences: prefs,
      );
    });

    group('with default preferences', () {
      test('keeps owner profanity behind a warning during cache restore', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
          viewerPubkey: () => _testPubkey.toUpperCase(),
        );
        final resolver = createNsfwWarnLabels(
          contentFilterService,
          moderationLabelService: moderationLabelService,
          viewerPubkey: () => _testPubkey.toUpperCase(),
        );
        final cached = VideoEvent.fromJson(
          _createVideo(contentWarningLabels: ['profanity']).toJson(),
        );

        expect(filter(cached), isFalse);
        expect(resolver(cached), ['profanity']);
      });

      test('still hides owner adult and always-filtered self-labels', () {
        for (final label in ['nudity', 'violence']) {
          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
            viewerPubkey: () => _testPubkey,
          );

          expect(
            filter(_createVideo(contentWarningLabels: [label])),
            isTrue,
            reason: '$label must not use the narrow creator carve-out',
          );
        }
      });

      test('returns false for video without content labels or hashtags', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo();

        expect(filter(video), isFalse);
      });

      test('returns true for video with nudity label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['nudity']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with sexual label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['sexual']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with porn label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['porn']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with violence label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['violence']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with drugs label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['drugs']);

        expect(filter(video), isTrue);
      });

      test('still hides a video whose moderationLabels survived a cache '
          'round-trip', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // The home-feed cache stores videos via toJson and rehydrates them
        // via fromJson on cold start. The ML "hide" signal must survive that
        // trip, otherwise a moderated video slips past the filter while the
        // cached window is served.
        final original = _createVideo(moderationLabels: ['nudity']);
        final cached = VideoEvent.fromJson(original.toJson());

        expect(filter(original), isTrue);
        expect(cached.moderationLabels, equals(['nudity']));
        expect(filter(cached), isTrue);
      });
    });

    group('NSFW hashtag detection', () {
      test('returns true for video with #nsfw hashtag', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['nsfw']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with #adult hashtag', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['adult']);

        expect(filter(video), isTrue);
      });

      test('returns true for case-insensitive #NSFW hashtag', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['NSFW']);

        expect(filter(video), isTrue);
      });

      test('returns false for unrelated hashtags', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['funny', 'cats', 'viral']);

        expect(filter(video), isFalse);
      });
    });

    group('unrecognized content-warning labels', () {
      test('adds nudity fallback for unrecognized labels', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // 'some-unknown-label' is not in ContentLabel enum
        final video = _createVideo(
          contentWarningLabels: ['some-unknown-label'],
        );

        // Unrecognized labels trigger conservative nudity fallback → hide
        expect(filter(video), isTrue);
      });

      test('does not add nudity fallback when recognized label present', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // 'flashing-lights' is recognized and defaults to warn, which does
        // not hide.
        final video = _createVideo(contentWarningLabels: ['flashing-lights']);

        expect(filter(video), isFalse);
      });
    });

    group('with changed preferences', () {
      test(
        'returns false for nudity when age-verified user sets to show',
        () async {
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await contentFilterService.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );

          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(contentWarningLabels: ['nudity']);

          expect(filter(video), isFalse);
        },
      );

      test('returns true for flashing lights when user sets to hide', () async {
        await contentFilterService.setPreference(
          ContentLabel.flashingLights,
          ContentFilterPreference.hide,
        );

        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['flashing-lights']);

        expect(filter(video), isTrue);
      });
    });

    group('mixed labels', () {
      test('returns true when any label maps to hide', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // alcohol=hide while unverified, nudity=hide -> hide wins
        final video = _createVideo(contentWarningLabels: ['alcohol', 'nudity']);

        expect(filter(video), isTrue);
      });

      test('returns false when all labels map to warn', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // flashing-lights=warn, misleading=warn -> most restrictive is warn.
        final video = _createVideo(
          contentWarningLabels: ['flashing-lights', 'misleading'],
        );

        expect(filter(video), isFalse);
      });

      test(
        'does not double-add nudity when hashtag and label both present',
        () {
          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(
            contentWarningLabels: ['nudity'],
            hashtags: ['nsfw'],
          );

          // Should still filter because nudity is age-gated to hide.
          expect(filter(video), isTrue);
        },
      );

      test(
        'returns true for replaceable video with trusted addressable label',
        () async {
          await seedModerationLabels([
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
            ['a', '34236:$_testPubkey:replaceable-video-d-tag'],
          ]);

          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(vineId: 'replaceable-video-d-tag');

          expect(filter(video), isTrue);
        },
      );
    });

    group('ML moderation labels (video.moderationLabels)', () {
      test('keeps videos with only unknown ML moderation labels', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(
          moderationLabels: const ['some-new-server-label'],
        );

        expect(filter(video), isFalse);
      });

      test('still hides videos with known hide labels', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(moderationLabels: const ['nudity']);

        expect(filter(video), isTrue);
      });

      test(
        'respects sexual show preference for sexual-content alias',
        () async {
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await contentFilterService.setPreference(
            ContentLabel.sexual,
            ContentFilterPreference.show,
          );

          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(
            moderationLabels: const ['sexual-content'],
          );

          expect(filter(video), isFalse);
        },
      );

      test('does not hide videos with no moderation labels', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo();

        expect(filter(video), isFalse);
      });

      test('hides when moderationLabels contains a known hide label '
          'alongside an unknown label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(
          moderationLabels: const ['nudity', 'unknown-x'],
        );

        expect(filter(video), isTrue);
      });

      test('ignores unknown labels when the user preferenced recognized '
          'labels as show', () async {
        // Simulate an age-verified user who has explicitly opted in to
        // seeing alcohol content. Unknown ML labels should not override that
        // recognized preference.
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await contentFilterService.setPreference(
          ContentLabel.alcohol,
          ContentFilterPreference.show,
        );

        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(
          moderationLabels: const ['alcohol', 'unknown-x'],
        );

        expect(filter(video), isFalse);
      });

      test(
        'does not hide on self-labels branch when moderationLabels is empty',
        () {
          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          // Self-labels branch: unknown self-label triggers nudity fallback
          // inside _getContentLabels, which maps to hide. This test locks in
          // that pre-existing behavior to guarantee the B2 change didn't touch
          // the self-labels branch.
          final video = _createVideo(
            contentWarningLabels: const ['some-unknown-self-label'],
          );

          expect(filter(video), isTrue);
        },
      );
    });

    group('createNsfwWarnLabels', () {
      test('returns trusted hash-based warn labels', () async {
        await seedModerationLabels([
          ['L', 'content-warning'],
          ['l', 'flashing-lights', 'content-warning'],
          ['x', 'trusted-warning-hash'],
        ]);

        final resolver = createNsfwWarnLabels(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final labels = resolver(_createVideo(sha256: 'trusted-warning-hash'));

        expect(labels, equals(['flashing-lights']));
      });
    });
  });
}
