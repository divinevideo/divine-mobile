import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip ratioClip(double? v, {double? orig = 9 / 16}) =>
      DivineVideoClip(
        id: 'c',
        video: editor.EditorVideo.file(File('/tmp/x.mp4')),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: orig,
        videoAspectRatio: v,
      );

  DivineVideoClip clip(String videoPath) => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File(videoPath)),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
  );

  DivineVideoClip stopMotionClip(List<String> framePaths) => DivineVideoClip(
    id: 'sm1',
    stopMotionFrames: [
      for (final path in framePaths)
        StopMotionClipFrame(
          path: path,
          duration: const Duration(milliseconds: 83),
        ),
    ],
    duration: Duration(milliseconds: 83 * framePaths.length),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  group('DivineVideoClip.hasResolvableVideoFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('divine_video_clip_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('is true when the source video file exists on disk', () async {
      final path = '${tempDir.path}/clip.mp4';
      await File(path).writeAsBytes(const [0]);

      expect(clip(path).hasResolvableVideoFile, isTrue);
    });

    test('is false when the source video file is missing', () {
      expect(
        clip('${tempDir.path}/deleted.mp4').hasResolvableVideoFile,
        isFalse,
      );
    });

    test('is true for a stop-motion clip whose stills all exist', () async {
      final a = '${tempDir.path}/f0.jpg';
      final b = '${tempDir.path}/f1.jpg';
      await File(a).writeAsBytes(const [0]);
      await File(b).writeAsBytes(const [0]);

      expect(stopMotionClip([a, b]).hasResolvableVideoFile, isTrue);
    });

    test('is false for a stop-motion clip with a missing still', () async {
      final a = '${tempDir.path}/f0.jpg';
      await File(a).writeAsBytes(const [0]);

      expect(
        stopMotionClip([a, '${tempDir.path}/gone.jpg']).hasResolvableVideoFile,
        isFalse,
      );
    });

    test(
      'resolves a materialized clip against its mp4, not its cleaned stills',
      () async {
        final path = '${tempDir.path}/rendered.mp4';
        await File(path).writeAsBytes(const [0]);

        // A materialized clip carries a rendered mp4 and may still carry its
        // now-deleted stills. It must resolve against the mp4 that exists, not
        // be dropped as orphaned for the missing stills.
        final materialized = stopMotionClip([
          '${tempDir.path}/gone.jpg',
        ]).copyWith(video: editor.EditorVideo.file(File(path)));

        expect(materialized.hasResolvableVideoFile, isTrue);
      },
    );
  });

  group('DivineVideoClip.isStopMotion (video-first)', () {
    test('is true for a frames-only clip', () {
      expect(stopMotionClip(['/a.jpg']).isStopMotion, isTrue);
    });

    test('is false once a video is present, even if stills remain', () {
      final materialized = stopMotionClip([
        '/a.jpg',
      ]).copyWith(video: editor.EditorVideo.file(File('/rendered.mp4')));

      expect(materialized.isStopMotion, isFalse);
    });

    test('is false for a normal video clip', () {
      expect(clip('/v.mp4').isStopMotion, isFalse);
    });
  });

  group('DivineVideoClip.copyWith clearStopMotionFrames', () {
    test('drops the stills so the result is a plain video clip', () {
      final materialized = stopMotionClip(['/a.jpg', '/b.jpg']).copyWith(
        video: editor.EditorVideo.file(File('/rendered.mp4')),
        clearStopMotionFrames: true,
      );

      expect(materialized.stopMotionFrames, isNull);
      expect(materialized.isStopMotion, isFalse);
    });

    test('keeps the stills when the flag is not set', () {
      final copy = stopMotionClip([
        '/a.jpg',
      ]).copyWith(video: editor.EditorVideo.file(File('/rendered.mp4')));

      expect(copy.stopMotionFrames, hasLength(1));
    });
  });

  group('DivineVideoClip.sourceStartOffset', () {
    test('defaults to zero and survives copyWith', () {
      final original = clip('/videos/clip.mp4');
      expect(original.sourceStartOffset, equals(Duration.zero));

      final shifted = original.copyWith(
        sourceStartOffset: const Duration(seconds: 3),
      );
      expect(shifted.sourceStartOffset, equals(const Duration(seconds: 3)));

      // Unrelated copyWith calls (e.g. the render swapping the video file)
      // must not reset the offset — losing it re-anchors the timeline
      // thumbnail raster and visibly shifts the strip.
      final trimmed = shifted.copyWith(trimStart: const Duration(seconds: 1));
      expect(trimmed.sourceStartOffset, equals(const Duration(seconds: 3)));
    });

    test('round-trips through JSON and defaults to zero when absent', () {
      final shifted = clip(
        '/videos/clip.mp4',
      ).copyWith(sourceStartOffset: const Duration(milliseconds: 3210));

      final restored = DivineVideoClip.fromJson(shifted.toJson(), '/videos');
      expect(
        restored.sourceStartOffset,
        equals(const Duration(milliseconds: 3210)),
      );

      // Old drafts/history entries have no key — must default to zero.
      final legacy = DivineVideoClip.fromJson(
        clip('/videos/clip.mp4').toJson(),
        '/videos',
      );
      expect(legacy.sourceStartOffset, equals(Duration.zero));
    });
  });

  group('DivineVideoClip.minTrimStart', () {
    test('defaults to zero and survives copyWith', () {
      final original = clip('/videos/clip.mp4');
      expect(original.minTrimStart, equals(Duration.zero));

      final floored = original.copyWith(
        minTrimStart: const Duration(seconds: 2),
      );
      expect(floored.minTrimStart, equals(const Duration(seconds: 2)));

      // An unrelated copyWith (e.g. a later trim) must keep the floor.
      final trimmed = floored.copyWith(trimStart: const Duration(seconds: 3));
      expect(trimmed.minTrimStart, equals(const Duration(seconds: 2)));
    });

    test('round-trips through JSON and defaults to zero when absent', () {
      final floored = clip(
        '/videos/clip.mp4',
      ).copyWith(minTrimStart: const Duration(milliseconds: 2500));

      final restored = DivineVideoClip.fromJson(floored.toJson(), '/videos');
      expect(restored.minTrimStart, equals(const Duration(milliseconds: 2500)));

      // Old drafts/history entries have no key — must default to zero.
      final legacy = DivineVideoClip.fromJson(
        clip('/videos/clip.mp4').toJson(),
        '/videos',
      );
      expect(legacy.minTrimStart, equals(Duration.zero));
    });
  });

  group('DivineVideoClip.videoAspectRatio', () {
    test("is the recording's ratio until a bake reshapes the file", () {
      final recorded = clip('/videos/clip.mp4').copyWith(
        originalAspectRatio: 9 / 16,
      );

      expect(recorded.videoAspectRatio, 9 / 16);
      expect(recorded.toJson().containsKey('videoAspectRatio'), isFalse);
    });

    test('round-trips through JSON without touching originalAspectRatio', () {
      // A square crop of a 9:16 recording: the file is 1:1, the canvas the
      // session's layers were authored on stays 9:16.
      final transformed = clip(
        '/videos/clip.mp4',
      ).copyWith(originalAspectRatio: 9 / 16, videoAspectRatio: 1);

      final restored = DivineVideoClip.fromJson(
        transformed.toJson(),
        '/videos',
      );

      expect(restored.videoAspectRatio, 1);
      expect(restored.originalAspectRatio, 9 / 16);
    });

    test('survives an unrelated copyWith', () {
      final transformed = clip('/videos/clip.mp4').copyWith(
        originalAspectRatio: 9 / 16,
        videoAspectRatio: 1,
      );

      // A split or a reverse re-renders the same frames, so both halves keep
      // the shape the transform gave them.
      expect(transformed.copyWith(volume: 0.5).videoAspectRatio, 1);
    });
  });

  group('DivineVideoClip.chromaKey', () {
    const key = ClipChromaKey(key: editor.ChromaKey.greenScreen());

    test('round-trips with its source path through JSON', () {
      final keyed = clip('/videos/clip.mp4').copyWith(
        chromaKey: key,
        chromaKeySourcePath: '/videos/original.mp4',
      );

      final restored = DivineVideoClip.fromJson(keyed.toJson(), '/videos');

      expect(restored.chromaKey, key);
      expect(restored.chromaKeySourcePath, '/videos/original.mp4');
    });

    test('is absent from JSON and null on legacy drafts', () {
      final json = clip('/videos/clip.mp4').toJson();
      expect(json.containsKey('chromaKey'), isFalse);
      expect(json.containsKey('chromaKeySourcePath'), isFalse);

      final restored = DivineVideoClip.fromJson(json, '/videos');
      expect(restored.chromaKey, isNull);
      expect(restored.chromaKeySourcePath, isNull);
    });

    test('survives an unrelated copyWith but can be cleared', () {
      final keyed = clip('/videos/clip.mp4').copyWith(
        chromaKey: key,
        chromaKeySourcePath: '/videos/original.mp4',
      );

      expect(keyed.copyWith(volume: 0.5).chromaKey, isNotNull);

      // Re-rendering the clip (transform, reverse) makes the recorded source
      // stop describing the video, so both are dropped together.
      final cleared = keyed.copyWith(clearChromaKey: true);
      expect(cleared.chromaKey, isNull);
      expect(cleared.chromaKeySourcePath, isNull);
    });

    test('does not follow the clip into a new logical clip', () {
      final keyed = clip('/videos/clip.mp4').copyWith(
        chromaKey: key,
        chromaKeySourcePath: '/videos/original.mp4',
      );

      // A split or duplicate makes a different clip; re-keying it from the
      // original's source would restore footage this clip never had.
      final split = keyed.copyWith(id: 'c2');
      expect(split.chromaKey, isNull);
      expect(split.chromaKeySourcePath, isNull);
    });

    test('drops an unparseable key instead of failing the whole clip', () {
      final json = clip('/videos/clip.mp4').toJson()
        ..['chromaKey'] = 'not-a-map';

      final restored = DivineVideoClip.fromJson(json, '/videos');

      expect(restored.chromaKey, isNull);
      expect(restored.id, 'c1');
    });
  });

  group('DivineVideoClip source provenance', () {
    test('round-trips through JSON when populated', () {
      final source = clip('/videos/clip.mp4').copyWith(
        sourceCredits: const [
          model.ClipSourceCredit(
            authorPubkey: 'source-author-pubkey',
            eventId: 'source-event-id',
            addressableId: '34236:source-author-pubkey:source-d-tag',
            relayUrl: 'wss://relay.divine.video',
          ),
        ],
      );

      final json = source.toJson();
      expect(json['sourceAuthorPubkey'], 'source-author-pubkey');
      expect(json['sourceEventId'], 'source-event-id');
      expect(
        json['sourceAddressableId'],
        '34236:source-author-pubkey:source-d-tag',
      );
      expect(json['sourceRelayHint'], 'wss://relay.divine.video');

      final restored = DivineVideoClip.fromJson(json, '/videos');
      expect(restored.sourceCredits, hasLength(1));
      expect(restored.sourceAuthorPubkey, source.sourceAuthorPubkey);
      expect(restored.sourceEventId, source.sourceEventId);
      expect(restored.sourceAddressableId, source.sourceAddressableId);
      expect(restored.sourceRelayHint, source.sourceRelayHint);
    });

    test(
      'stores multiple source credits with scalar first-credit fallback',
      () {
        final source = clip('/videos/clip.mp4').copyWith(
          sourceCredits: const [
            model.ClipSourceCredit(
              authorPubkey: 'source-author-a',
              eventId: 'source-event-a',
              addressableId: '34236:source-author-a:source-a',
              relayUrl: 'wss://relay-a.divine.video',
            ),
            model.ClipSourceCredit(
              authorPubkey: 'source-author-b',
              eventId: 'source-event-b',
              relayUrl: 'wss://relay-b.divine.video',
            ),
          ],
        );

        final restored = DivineVideoClip.fromJson(source.toJson(), '/videos');

        expect(restored.sourceCredits, hasLength(2));
        expect(restored.sourceAuthorPubkey, 'source-author-a');
        expect(restored.sourceEventId, 'source-event-a');
        expect(restored.sourceAddressableId, '34236:source-author-a:source-a');
        expect(restored.sourceRelayHint, 'wss://relay-a.divine.video');
        expect(restored.sourceCredits[1].authorPubkey, 'source-author-b');
        expect(restored.sourceCredits[1].eventId, 'source-event-b');
        expect(
          restored.sourceCredits[1].relayUrl,
          'wss://relay-b.divine.video',
        );
      },
    );

    test(
      'drops malformed source credit entries instead of failing restore',
      () {
        final json = clip('/videos/clip.mp4').toJson()
          ..['sourceCredits'] = [
            {
              'eventId': 'missing-author',
              'addressableId': '34236:source-author-a:source-a',
            },
            {
              'authorPubkey': 'source-author-b',
              'eventId': 'source-event-b',
              'addressableId': '34236:source-author-b:source-b',
              'relayUrl': 'wss://relay-b.divine.video',
            },
          ];

        final restored = DivineVideoClip.fromJson(json, '/videos');

        expect(restored.sourceCredits, hasLength(1));
        expect(restored.sourceCredits.single.authorPubkey, 'source-author-b');
      },
    );

    test('defaults to null for legacy JSON and omits empty keys', () {
      final json = clip('/videos/clip.mp4').toJson();
      expect(json.containsKey('sourceAuthorPubkey'), isFalse);
      expect(json.containsKey('sourceEventId'), isFalse);
      expect(json.containsKey('sourceAddressableId'), isFalse);
      expect(json.containsKey('sourceRelayHint'), isFalse);

      final restored = DivineVideoClip.fromJson(json, '/videos');
      expect(restored.sourceAuthorPubkey, isNull);
      expect(restored.sourceEventId, isNull);
      expect(restored.sourceAddressableId, isNull);
      expect(restored.sourceRelayHint, isNull);
      expect(restored.sourceCredits, isEmpty);
    });

    test('survives copyWith and can be cleared explicitly', () {
      final source = clip('/videos/clip.mp4').copyWith(
        sourceCredits: const [
          model.ClipSourceCredit(
            authorPubkey: 'source-author-pubkey',
            eventId: 'source-event-id',
            addressableId: '34236:source-author-pubkey:source-d-tag',
            relayUrl: 'wss://relay.divine.video',
          ),
        ],
      );

      final copied = source.copyWith(duration: const Duration(seconds: 6));
      expect(copied.sourceCredits, source.sourceCredits);
      expect(copied.sourceAuthorPubkey, source.sourceAuthorPubkey);
      expect(copied.sourceEventId, source.sourceEventId);
      expect(copied.sourceAddressableId, source.sourceAddressableId);
      expect(copied.sourceRelayHint, source.sourceRelayHint);

      final cleared = copied.copyWith(clearSourceCredits: true);
      expect(cleared.sourceAuthorPubkey, isNull);
      expect(cleared.sourceEventId, isNull);
      expect(cleared.sourceAddressableId, isNull);
      expect(cleared.sourceRelayHint, isNull);
      expect(cleared.sourceCredits, isEmpty);
    });

    test('carries every credit onto a split or duplicated clip', () {
      final merged = clip('/videos/clip.mp4').copyWith(
        sourceCredits: const [
          model.ClipSourceCredit(
            authorPubkey: 'source-author-a',
            addressableId: '34236:source-author-a:source-a',
            relayUrl: 'wss://relay-a.divine.video',
          ),
          model.ClipSourceCredit(
            authorPubkey: 'source-author-b',
            addressableId: '34236:source-author-b:source-b',
          ),
        ],
      );

      // A new id makes this a new logical clip, which resets chroma/transition
      // state. Provenance is a fact about the footage, so it must survive.
      final half = merged.copyWith(
        id: 'c2',
        trimEnd: const Duration(seconds: 1),
      );
      expect(half.sourceCredits, equals(merged.sourceCredits));
    });
  });

  group('DivineVideoClip.budgetDuration', () {
    test('equals duration for a normal clip', () {
      expect(
        clip('/videos/clip.mp4').budgetDuration,
        equals(const Duration(seconds: 5)),
      );
    });

    test('subtracts minTrimStart so a split end half is not double-counted', () {
      // A 5s clip split at 2s: start half [0,2s], end half [2s,5s] on the same
      // file with minTrimStart 2s. Summing budgetDuration must recover the
      // original 5s, not 2s + 5s = 7s.
      final startHalf = clip(
        '/videos/clip.mp4',
      ).copyWith(duration: const Duration(seconds: 2));
      final endHalf = clip('/videos/clip.mp4').copyWith(
        trimStart: const Duration(seconds: 2),
        minTrimStart: const Duration(seconds: 2),
      );
      expect(startHalf.budgetDuration, equals(const Duration(seconds: 2)));
      expect(endHalf.budgetDuration, equals(const Duration(seconds: 3)));
      expect(
        startHalf.budgetDuration + endHalf.budgetDuration,
        equals(const Duration(seconds: 5)),
      );
    });
  });

  group('DivineVideoClip.ownedFilePaths', () {
    test('yields every file reference a clip can carry', () {
      // Pins the full set, because this getter is what four cleanup paths diff
      // against to decide a file is unreachable. A reference dropped from here
      // stops being protected: the file is queued for deletion while a clip is
      // still playing it.
      final populated = clip('/videos/clip.mp4').copyWith(
        forwardVideoPath: '/videos/forward.mp4',
        reversedVideoPath: '/videos/reversed.mp4',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/stills/frame-0.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        thumbnailPath: '/thumbs/clip.jpg',
        ghostFramePath: '/ghosts/clip.png',
        chromaKeySourcePath: '/videos/pre-key.mp4',
        chromaKey: ClipChromaKey(
          key: editor.ChromaKey(
            backgroundImage: editor.EditorLayerImage.file(
              '/backdrops/beach.jpg',
            ),
          ),
        ),
      );

      expect(populated.ownedFilePaths.nonNulls, <String>[
        '/videos/clip.mp4',
        '/videos/forward.mp4',
        '/videos/reversed.mp4',
        '/stills/frame-0.jpg',
        '/thumbs/clip.jpg',
        '/ghosts/clip.png',
        '/videos/pre-key.mp4',
        '/backdrops/beach.jpg',
      ]);
    });

    test('yields the stills of a frames-only stop-motion clip', () {
      expect(
        stopMotionClip([
          '/stills/a.jpg',
          '/stills/b.jpg',
        ]).ownedFilePaths.nonNulls,
        <String>['/stills/a.jpg', '/stills/b.jpg'],
      );
    });
  });

  test('degenerate measured ratios fall back', () {
    expect(ratioClip(0).videoAspectRatio, 9 / 16);
    expect(ratioClip(double.nan).videoAspectRatio, 9 / 16);
    expect(ratioClip(double.infinity).videoAspectRatio, 9 / 16);
    expect(ratioClip(-1.5).videoAspectRatio, 9 / 16);
    expect(ratioClip(1.0).videoAspectRatio, 1.0);
  });

  test('a degenerate persisted original ratio falls back too', () {
    expect(ratioClip(null, orig: 0).originalAspectRatio, 9 / 16);
    expect(ratioClip(null, orig: double.nan).originalAspectRatio, 9 / 16);
    expect(ratioClip(null, orig: 3 / 4).originalAspectRatio, 3 / 4);
  });
}
