// ABOUTME: Tests for importing videos into the local clip library.
// ABOUTME: Covers validation, file copying, clip creation, and save failures.

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _FakeDivineVideoClip extends Fake implements DivineVideoClip {}

const _defaultVineId = 'vine-123';

models.VideoEvent _video({
  String id = 'classic-vine-event-id',
  String pubkey = 'classic-vine-author-pubkey',
  String? videoUrl = 'https://cdn.example.com/classic.mp4',
  int? duration = 6,
  String? dimensions = '480x480',
  Map<String, String> rawTags = const {'platform': 'vine'},
  String? vineId = _defaultVineId,
  String? title,
  String content = 'classic vine',
  String? textTrackContent,
  String? sourceRelay = 'wss://relay.divine.video',
}) {
  return models.VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1451606400,
    content: content,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1451606400 * 1000,
      isUtc: true,
    ),
    title: title,
    videoUrl: videoUrl,
    duration: duration,
    dimensions: dimensions,
    rawTags: rawTags,
    vineId: vineId,
    addressableDTag: vineId,
    textTrackContent: textTrackContent,
    sourceRelay: sourceRelay,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDivineVideoClip());
  });

  late Directory tempDir;
  late Directory docsDir;
  late File sourceVideo;
  late _MockClipLibraryService clipLibraryService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'classic_vine_import_test_',
    );
    docsDir = Directory('${tempDir.path}/documents')..createSync();
    sourceVideo = File('${tempDir.path}/source.mp4')
      ..writeAsBytesSync(List<int>.filled(16, 7));
    clipLibraryService = _MockClipLibraryService();
    when(() => clipLibraryService.saveClip(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  VideoClipImportService buildService({
    Future<File?> Function({required String url, required String cacheKey})?
    downloadVideo,
    Future<VideoClipThumbnail?> Function({
      required String videoPath,
      required Duration targetTimestamp,
    })?
    extractThumbnail,
    Future<String?> Function({
      required String videoPath,
      required Duration videoDuration,
    })?
    extractLastFrame,
    Future<VideoMetadata> Function(EditorVideo video)? readVideoMetadata,
    DocumentsPathProvider? getDocumentsPath,
    DateTime? now,
  }) {
    return VideoClipImportService(
      clipLibraryService: clipLibraryService,
      getDocumentsPath: getDocumentsPath ?? () async => docsDir.path,
      downloadVideo:
          downloadVideo ??
          ({required url, required cacheKey}) async => sourceVideo,
      extractThumbnail:
          extractThumbnail ??
          ({required videoPath, required targetTimestamp}) async {
            final thumbnail = File('${docsDir.path}/thumb.jpg')
              ..writeAsBytesSync(const [1, 2, 3]);
            return VideoClipThumbnail(
              path: thumbnail.path,
              timestamp: targetTimestamp,
            );
          },
      extractLastFrame:
          extractLastFrame ??
          ({required videoPath, required videoDuration}) async {
            final ghost = File('${docsDir.path}/ghost.jpg')
              ..writeAsBytesSync(const [4, 5, 6]);
            return ghost.path;
          },
      // Default to a stub so the production ctor never evaluates its
      // `?? ProVideoEditor.instance.getMetadata` fallback, which would construct
      // the real MethodChannelProVideoEditor and leak EventChannel subscriptions
      // into the merged VGV optimizer isolate (#5159). Tests that exercise the
      // metadata path inject their own reader.
      readVideoMetadata:
          readVideoMetadata ??
          (video) async => VideoMetadata(
            duration: Duration.zero,
            extension: 'mp4',
            fileSize: 0,
            resolution: Size.zero,
            rotation: 0,
            bitrate: 0,
          ),
      now: () => now ?? DateTime.utc(2026, 4, 27, 12),
    );
  }

  group('importToLibrary', () {
    test('imports a classic Vine as a saved square library clip', () async {
      final service = buildService();

      final result = await service.importToLibrary(_video());

      expect(result, isA<VideoClipImportSuccess>());
      final success = result as VideoClipImportSuccess;
      expect(success.clip.id, startsWith('classic_vine_vine-123_'));
      expect(success.clip.duration, const Duration(seconds: 6));
      expect(success.clip.targetAspectRatio, models.AspectRatio.square);
      expect(success.clip.originalAspectRatio, 1);
      expect(success.clip.thumbnailPath, endsWith('thumb.jpg'));
      expect(success.clip.ghostFramePath, endsWith('ghost.jpg'));
      expect(success.clip.requireVideo.file!.path, startsWith(docsDir.path));
      expect(success.clip.libraryTitle, 'classic vine');
      expect(success.clip.sourceAuthorPubkey, 'classic-vine-author-pubkey');
      expect(success.clip.sourceEventId, 'classic-vine-event-id');
      expect(
        success.clip.sourceAddressableId,
        '34236:classic-vine-author-pubkey:vine-123',
      );
      expect(success.clip.sourceRelayHint, 'wss://relay.divine.video');
      expect(
        File(success.clip.requireVideo.file!.path).readAsBytesSync(),
        sourceVideo.readAsBytesSync(),
      );

      final captured =
          verify(
                () => clipLibraryService.saveClip(captureAny()),
              ).captured.single
              as DivineVideoClip;
      expect(captured.id, success.clip.id);
      expect(captured.sourceAuthorPubkey, success.clip.sourceAuthorPubkey);
      expect(captured.sourceEventId, success.clip.sourceEventId);
      expect(captured.sourceAddressableId, success.clip.sourceAddressableId);
      expect(captured.sourceRelayHint, success.clip.sourceRelayHint);
    });

    test('uses an explicit user title when importing to the library', () async {
      final service = buildService();

      final result = await service.importToLibrary(
        _video(title: 'Published title'),
        libraryTitle: 'My local cut',
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.libraryTitle, 'My local cut');
    });

    test('derives the default library title from post title first', () async {
      final service = buildService();

      final result = await service.importToLibrary(
        _video(title: 'Published title', content: 'Published description'),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.libraryTitle, 'Published title');
    });

    test(
      'derives the default library title from description when title is empty',
      () async {
        final service = buildService();

        final result = await service.importToLibrary(
          _video(title: '  ', content: 'A useful description'),
        );

        final success = result as VideoClipImportSuccess;
        expect(success.clip.libraryTitle, 'A useful description');
      },
    );

    test('derives the default library title from embedded subtitles', () async {
      final service = buildService();

      final result = await service.importToLibrary(
        _video(
          title: '',
          content: '',
          textTrackContent: '''
  WEBVTT

  00:00.000 --> 00:02.000
  First useful caption
  ''',
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.libraryTitle, 'First useful caption');
    });
  });

  group('defaultLibraryTitleFor', () {
    test('uses a timestamp fallback when metadata has no title text', () {
      final title = VideoClipImportService.defaultLibraryTitleFor(
        _video(title: '', content: '', textTrackContent: ''),
        fallbackTime: DateTime(2026, 6, 13, 15, 45),
      );

      expect(title, 'Clip Jun 13, 3:45 PM');
    });

    test('normalizes whitespace and truncates long library titles', () {
      final title = VideoClipImportService.defaultLibraryTitleFor(
        _video(
          title:
              '  This title has     extra spaces and it keeps going past the eighty character limit for local clip names  ',
          content: 'fallback description',
        ),
      );

      expect(title, hasLength(80));
      expect(
        title,
        'This title has extra spaces and it keeps going past the eighty character limi...',
      );
    });

    // Regression for #7295: truncating by UTF-16 code unit split the emoji at
    // the 77-unit boundary and left a lone high surrogate, which then threw
    // "string is not well-formed UTF-16" out of the paragraph builder when the
    // clip title was rendered. Truncation now counts grapheme clusters, so the
    // emoji is either kept whole or dropped whole.
    test('truncates long library titles without splitting an emoji', () {
      final title = VideoClipImportService.defaultLibraryTitleFor(
        _video(
          title: '${'a' * 76}\u{1F600} trailing text past the eighty limit',
          content: 'fallback description',
        ),
      );

      // The old code-unit cut produced 'a' * 76 + a lone high surrogate, which
      // this expectation rejects.
      expect(title, equals('${'a' * 76}\u{1F600}...'));
    });

    // Regression for #7295: `textTrackContent` is the only title source here
    // that no model display boundary covers — `SubtitleService.parseVtt` hands
    // a relay-served cue through verbatim — so a cue under the length cap
    // carried its lone surrogate straight into `libraryTitle`, which renders as
    // a plain `Text`.
    test('sanitizes a lone surrogate carried in a subtitle cue', () {
      final loneSurrogate = String.fromCharCode(0xD83D);

      final title = VideoClipImportService.defaultLibraryTitleFor(
        _video(
          title: '',
          content: '',
          textTrackContent:
              '''
  WEBVTT

  00:00.000 --> 00:02.000
  cue text $loneSurrogate here
  ''',
        ),
      );

      expect(title, equals('cue text \uFFFD here'));
    });
  });

  group('dimension and aspect ratio resolution', () {
    test(
      'imports an own (non-classic) video as a saved library clip',
      () async {
        final service = buildService();

        final result = await service.importToLibrary(
          _video(
            id: 'own-video-event-id',
            pubkey: 'own-video-author-pubkey',
            rawTags: const {'platform': 'divine'},
            vineId: null,
          ),
        );

        expect(result, isA<VideoClipImportSuccess>());
        final success = result as VideoClipImportSuccess;
        expect(success.clip.id, startsWith('own_video_own-video-event-id_'));
        expect(success.clip.sourceAuthorPubkey, 'own-video-author-pubkey');
        expect(success.clip.sourceEventId, 'own-video-event-id');
        expect(success.clip.sourceAddressableId, isNull);
        expect(success.clip.sourceRelayHint, 'wss://relay.divine.video');
        verify(() => clipLibraryService.saveClip(any())).called(1);
      },
    );

    test(
      'falls back to ProVideoEditor metadata when event dimensions are missing '
      'and resolves a vertical target ratio',
      () async {
        final service = buildService(
          readVideoMetadata: (video) async => VideoMetadata(
            duration: const Duration(seconds: 6),
            extension: 'mp4',
            fileSize: 1024,
            resolution: const Size(1080, 1920),
            rotation: 0,
            bitrate: 1000,
          ),
        );

        final result = await service.importToLibrary(
          _video(
            id: 'own-no-dims',
            rawTags: const {'platform': 'divine'},
            vineId: null,
            dimensions: null,
          ),
        );

        final success = result as VideoClipImportSuccess;
        expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
        expect(success.clip.originalAspectRatio, closeTo(1080 / 1920, 0.001));
      },
    );

    test('falls back to ProVideoEditor metadata for square own videos without '
        'dimensions', () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(720, 720),
          rotation: 0,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-square',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.targetAspectRatio, models.AspectRatio.square);
      expect(success.clip.originalAspectRatio, 1);
    });

    test('maps landscape own video to square target ratio', () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(1920, 1080),
          rotation: 0,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-landscape',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      // Landscape videos (ratio > 1.0) satisfy _squareishMinAspectRatio and
      // intentionally map to square to match the clip library's crop policy.
      expect(success.clip.targetAspectRatio, models.AspectRatio.square);
      expect(success.clip.originalAspectRatio, closeTo(1920 / 1080, 0.001));
    });

    test(
      'uses display dimensions when metadata reports a rotated portrait video',
      () async {
        final service = buildService(
          readVideoMetadata: (video) async => VideoMetadata(
            duration: const Duration(seconds: 6),
            extension: 'mp4',
            fileSize: 1024,
            resolution: const Size(1080, 1920),
            rotation: 90,
            bitrate: 1000,
          ),
        );

        final result = await service.importToLibrary(
          _video(
            id: 'own-rotated',
            rawTags: const {'platform': 'divine'},
            vineId: null,
            dimensions: null,
          ),
        );

        final success = result as VideoClipImportSuccess;
        expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
        expect(success.clip.originalAspectRatio, closeTo(1080 / 1920, 0.001));
      },
    );

    test('keeps a rotated landscape display as square', () async {
      final service = buildService(
        readVideoMetadata: (video) async => VideoMetadata(
          duration: const Duration(seconds: 6),
          extension: 'mp4',
          fileSize: 1024,
          resolution: const Size(1920, 1080),
          rotation: 90,
          bitrate: 1000,
        ),
      );

      final result = await service.importToLibrary(
        _video(
          id: 'own-rotated-landscape',
          rawTags: const {'platform': 'divine'},
          vineId: null,
          dimensions: null,
        ),
      );

      final success = result as VideoClipImportSuccess;
      expect(success.clip.targetAspectRatio, models.AspectRatio.square);
      expect(success.clip.originalAspectRatio, closeTo(1920 / 1080, 0.001));
    });

    test('prefers imeta dimensions over the probed resolution', () async {
      var metadataRead = false;
      final service = buildService(
        readVideoMetadata: (video) async {
          metadataRead = true;
          // A resolution that disagrees with the imeta `dim` tag, so the
          // assertions below can tell which source won.
          return VideoMetadata(
            duration: const Duration(seconds: 5),
            extension: 'mp4',
            fileSize: 1024,
            resolution: const Size(720, 720),
            rotation: 0,
            bitrate: 1000,
          );
        },
      );

      final event = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://cdn.example.com/own-imeta-dim.mp4'],
          ['platform', 'divine'],
          [
            'imeta',
            'url https://cdn.example.com/own-imeta-dim.mp4',
            'dim 1080x1920',
          ],
        ],
        'Divine portrait post',
        createdAt: 1786231401,
      );

      final result = await service.importToLibrary(
        models.VideoEvent.fromNostrEvent(event),
      );

      final success = result as VideoClipImportSuccess;
      // The file is still probed — the duration needs it — but the ratio comes
      // from the event.
      expect(metadataRead, isTrue);
      expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
      expect(success.clip.originalAspectRatio, closeTo(1080 / 1920, 0.001));
    });

    test(
      'falls back to vertical target ratio when metadata probe throws',
      () async {
        final service = buildService(
          readVideoMetadata: (video) async => throw StateError('probe failed'),
        );

        final result = await service.importToLibrary(
          _video(
            id: 'own-probe-fail',
            rawTags: const {'platform': 'divine'},
            vineId: null,
            dimensions: null,
          ),
        );

        final success = result as VideoClipImportSuccess;
        expect(success.clip.targetAspectRatio, models.AspectRatio.vertical);
        expect(success.clip.originalAspectRatio, 1);
      },
    );
  });

  group('import failure reasons', () {
    test('returns missingVideoUrl when no playable URL is available', () async {
      final service = buildService();

      final result = await service.importToLibrary(_video(videoUrl: null));

      expect(
        result,
        isA<VideoClipImportFailure>().having(
          (result) => result.reason,
          'reason',
          VideoClipImportFailureReason.missingVideoUrl,
        ),
      );
      verifyNever(() => clipLibraryService.saveClip(any()));
    });

    test(
      'returns downloadFailed when the cache cannot provide a file',
      () async {
        final service = buildService(
          downloadVideo: ({required url, required cacheKey}) async => null,
        );

        final result = await service.importToLibrary(_video());

        expect(
          result,
          isA<VideoClipImportFailure>().having(
            (result) => result.reason,
            'reason',
            VideoClipImportFailureReason.downloadFailed,
          ),
        );
        verifyNever(() => clipLibraryService.saveClip(any()));
      },
    );

    test('returns copyFailed when the video cannot be copied', () async {
      final importedAt = DateTime.utc(2026, 4, 27, 12);
      // Deliberately couple this collision to the generated clip ID: if the ID
      // scheme changes, this regression test must choose a new failing target.
      final target = Directory(
        '${docsDir.path}/classic_vine_vine-123_'
        '${importedAt.microsecondsSinceEpoch}.mp4',
      )..createSync();
      final service = buildService(now: importedAt);

      final result = await service.importToLibrary(_video());

      expect(
        result,
        isA<VideoClipImportFailure>().having(
          (result) => result.reason,
          'reason',
          VideoClipImportFailureReason.copyFailed,
        ),
      );
      verifyNever(() => clipLibraryService.saveClip(any()));
      expect(target.existsSync(), isTrue);
      expect(docsDir.listSync().whereType<File>(), isEmpty);
    });

    test(
      'returns copyFailed when the documents directory cannot be created',
      () async {
        final service = buildService(
          getDocumentsPath: () async => '${sourceVideo.path}/documents',
        );

        final result = await service.importToLibrary(_video());

        expect(
          result,
          isA<VideoClipImportFailure>().having(
            (result) => result.reason,
            'reason',
            VideoClipImportFailureReason.copyFailed,
          ),
        );
        verifyNever(() => clipLibraryService.saveClip(any()));
        expect(docsDir.listSync().whereType<File>(), isEmpty);
      },
    );

    test('returns saveFailed when the clip cannot be saved', () async {
      when(
        () => clipLibraryService.saveClip(any()),
      ).thenThrow(Exception('save failed'));
      final service = buildService();

      final result = await service.importToLibrary(_video());

      expect(
        result,
        isA<VideoClipImportFailure>().having(
          (result) => result.reason,
          'reason',
          VideoClipImportFailureReason.saveFailed,
        ),
      );
      verify(() => clipLibraryService.saveClip(any())).called(1);
    });

    test(
      'returns unsupportedPlatform without downloading the video',
      () async {
        var downloadAttempts = 0;
        final service = buildService(
          getDocumentsPath: () async => '',
          downloadVideo: ({required url, required cacheKey}) async {
            downloadAttempts++;
            return sourceVideo;
          },
        );

        final result = await service.importToLibrary(_video());

        expect(
          result,
          isA<VideoClipImportFailure>().having(
            (result) => result.reason,
            'reason',
            VideoClipImportFailureReason.unsupportedPlatform,
          ),
        );
        expect(downloadAttempts, isZero);
        verifyNever(() => clipLibraryService.saveClip(any()));
      },
    );
  });

  group('clip duration', () {
    VideoMetadata metadataWith(Duration duration) => VideoMetadata(
      duration: duration,
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(480, 480),
      rotation: 0,
      bitrate: 1000,
    );

    test(
      'measures the file instead of trusting the archive duration tag',
      () async {
        // Every Vine archive event advertises `duration 6`; the real assets
        // measure 5.201s-6.548s. Trusting the tag makes the export cut a
        // full-length Vine short and lets custom audio outlive the video on
        // Android (#7920).
        final service = buildService(
          readVideoMetadata: (video) async =>
              metadataWith(const Duration(milliseconds: 6548)),
        );

        final result = await service.importToLibrary(_video());

        final success = result as VideoClipImportSuccess;
        expect(success.clip.duration, const Duration(milliseconds: 6548));
      },
    );

    test('extracts the ghost frame at the measured duration', () async {
      Duration? ghostFrameDuration;
      final service = buildService(
        readVideoMetadata: (video) async =>
            metadataWith(const Duration(milliseconds: 5201)),
        extractLastFrame: ({required videoPath, required videoDuration}) async {
          ghostFrameDuration = videoDuration;
          return null;
        },
      );

      await service.importToLibrary(_video());

      expect(ghostFrameDuration, const Duration(milliseconds: 5201));
    });

    test('falls back to the event tag when the probe reports zero', () async {
      final service = buildService(
        readVideoMetadata: (video) async => metadataWith(Duration.zero),
      );

      final result = await service.importToLibrary(_video(duration: 7));

      final success = result as VideoClipImportSuccess;
      expect(success.clip.duration, const Duration(seconds: 7));
    });

    test('falls back to the event tag when the probe throws', () async {
      final service = buildService(
        readVideoMetadata: (video) async => throw StateError('probe failed'),
      );

      final result = await service.importToLibrary(_video(duration: 7));

      final success = result as VideoClipImportSuccess;
      expect(success.clip.duration, const Duration(seconds: 7));
    });

    test('falls back to six seconds when neither source is usable', () async {
      final service = buildService(
        readVideoMetadata: (video) async => metadataWith(Duration.zero),
      );

      final result = await service.importToLibrary(_video(duration: null));

      final success = result as VideoClipImportSuccess;
      expect(success.clip.duration, const Duration(seconds: 6));
    });
  });
}
