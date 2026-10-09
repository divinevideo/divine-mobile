import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipChromaKey, () {
    group('backgroundType', () {
      test('is transparent when nothing fills the keyed area', () {
        const key = ClipChromaKey(key: ChromaKey.greenScreen());
        expect(key.backgroundType, ClipChromaKeyBackgroundType.transparent);
        expect(key.needsComposition, isTrue);
      });

      test('is color when the key carries a fill colour', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );
        expect(key.backgroundType, ClipChromaKeyBackgroundType.color);
        expect(key.needsComposition, isFalse);
      });

      test('is image when the key carries a background image', () {
        final key = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/a/bg.png')),
        );
        expect(key.backgroundType, ClipChromaKeyBackgroundType.image);
        expect(key.needsComposition, isFalse);
      });

      test('is video when a backdrop clip is set, and needs a composition', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a/backdrop.mp4',
        );
        expect(key.backgroundType, ClipChromaKeyBackgroundType.video);
        // The single-track segment path cannot put a video behind the subject,
        // so this background must be pre-rendered.
        expect(key.needsComposition, isTrue);
      });
    });

    group('backdropSources', () {
      test('names a video backdrop as a video source', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a/backdrop.mp4',
        );

        expect(key.backdropSources, const [
          C2paEditSource(path: '/a/backdrop.mp4'),
        ]);
      });

      test('names an image backdrop as an image source', () {
        final key = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/a/bg.png')),
        );

        expect(key.backdropSources, const [
          C2paEditSource(path: '/a/bg.png', kind: C2paSourceKind.image),
        ]);
      });

      test('names no source for a colour fill or no backdrop', () {
        const color = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );
        const transparent = ClipChromaKey(key: ChromaKey.greenScreen());

        expect(color.backdropSources, isEmpty);
        expect(transparent.backdropSources, isEmpty);
      });
    });

    group('withVideoBackground', () {
      test('drops a colour fill so the layer below can show through', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );

        final swapped = key.withVideoBackground('/a/backdrop.mp4');

        expect(swapped.backgroundType, ClipChromaKeyBackgroundType.video);
        // A colour fill left in place would paint over the backdrop and the
        // composition would render a solid rectangle instead of the video.
        expect(swapped.key.backgroundColor, isNull);
        expect(swapped.key.isTransparent, isTrue);
      });

      test('keeps the tuning the user dialled in', () {
        const key = ClipChromaKey(
          key: ChromaKey(
            color: Color(0xFF00FF00),
            similarity: 0.31,
            smoothness: 0.13,
            spill: 0.7,
          ),
        );

        final swapped = key.withVideoBackground('/a/backdrop.mp4');

        expect(swapped.key.color, const Color(0xFF00FF00));
        expect(swapped.key.similarity, 0.31);
        expect(swapped.key.smoothness, 0.13);
        expect(swapped.key.spill, 0.7);
      });
    });

    test('withKey drops a video backdrop', () {
      const key = ClipChromaKey(
        key: ChromaKey.greenScreen(),
        backgroundVideoPath: '/a/backdrop.mp4',
      );

      final swapped = key.withKey(
        const ChromaKey.greenScreen(backgroundColor: Color(0xFF000000)),
      );

      expect(swapped.backgroundType, ClipChromaKeyBackgroundType.color);
      expect(swapped.backgroundVideoPath, isNull);
    });

    group('withKeySettings', () {
      test('changes the tuning and keeps a backdrop clip', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a/backdrop.mp4',
        );

        final tuned = key.withKeySettings(
          color: const Color(0xFF3355AA),
          similarity: 0.22,
          smoothness: 0.05,
          spill: 0.3,
        );

        expect(tuned.key.color, const Color(0xFF3355AA));
        expect(tuned.key.similarity, 0.22);
        expect(tuned.key.smoothness, 0.05);
        expect(tuned.key.spill, 0.3);
        expect(tuned.backgroundVideoPath, '/a/backdrop.mp4');
      });

      test('keeps a colour fill', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );

        expect(
          key.withKeySettings(similarity: 0.2).key.backgroundColor,
          const Color(0xFF102030),
        );
      });
    });

    group('withPreset', () {
      test('adopts the preset screen and keeps an image backdrop', () {
        final key = ClipChromaKey(
          key: const ChromaKey.greenScreen().copyWith(
            similarity: 0.3,
            backgroundImage: EditorLayerImage.file('/a/bg.png'),
          ),
        );

        final blue = key.withPreset(const ChromaKey.blueScreen());

        expect(blue.key.color, const ChromaKey.blueScreen().color);
        expect(blue.key.similarity, const ChromaKey.blueScreen().similarity);
        expect(blue.backgroundImagePath, '/a/bg.png');
      });

      test('keeps a backdrop clip', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a/backdrop.mp4',
        );

        final blue = key.withPreset(const ChromaKey.blueScreen());

        expect(blue.backgroundType, ClipChromaKeyBackgroundType.video);
      });
    });

    group('background setters', () {
      const key = ClipChromaKey(
        key: ChromaKey(color: Color(0xFF00FF00), similarity: 0.27),
        backgroundVideoPath: '/a/backdrop.mp4',
      );

      test('withTransparentBackground leaves the area unfilled', () {
        final swapped = key.withTransparentBackground();

        expect(swapped.backgroundType, ClipChromaKeyBackgroundType.transparent);
        expect(swapped.key.similarity, 0.27);
      });

      test('withColorBackground fills the area with the colour', () {
        final swapped = key.withColorBackground(const Color(0xFF102030));

        expect(swapped.backgroundType, ClipChromaKeyBackgroundType.color);
        expect(swapped.key.backgroundColor, const Color(0xFF102030));
      });

      test('withImageBackground fills the area with the image', () {
        final swapped = key.withImageBackground('/a/bg.png');

        expect(swapped.backgroundType, ClipChromaKeyBackgroundType.image);
        expect(swapped.backgroundImagePath, '/a/bg.png');
        expect(swapped.key.color, const Color(0xFF00FF00));
      });
    });

    group('serialization', () {
      const documentsPath = '/documents';

      test('round-trips the tuning', () {
        // Deliberately not the default key colour: a colour that round-trips
        // only because `fromMap` fell back to the default would prove nothing.
        const key = ClipChromaKey(
          key: ChromaKey(
            color: Color(0xFF12B4A0),
            similarity: 0.27,
            smoothness: 0.11,
            spill: 0.35,
            backgroundColor: Color(0xFF123456),
          ),
        );

        final restored = ClipChromaKey.fromJson(key.toJson(), documentsPath);

        expect(restored, key);
      });

      test('re-anchors file paths under the documents directory', () {
        // iOS rewrites the container path on every app update, so a persisted
        // absolute path goes stale — only the basename survives.
        final key = ClipChromaKey(
          key: ChromaKey(
            backgroundImage: EditorLayerImage.file('/old/container/bg.png'),
          ),
          backgroundVideoPath: '/old/container/backdrop.mp4',
        );

        final json = key.toJson();
        expect(json['backgroundImage'], 'bg.png');
        expect(json['backgroundVideo'], 'backdrop.mp4');

        final restored = ClipChromaKey.fromJson(json, documentsPath);
        expect(restored.backgroundImagePath, '$documentsPath/bg.png');
        expect(restored.backgroundVideoPath, '$documentsPath/backdrop.mp4');
      });

      test('restores a transparent key with no background at all', () {
        const key = ClipChromaKey(key: ChromaKey.blueScreen());

        final restored = ClipChromaKey.fromJson(key.toJson(), documentsPath);

        expect(
          restored.backgroundType,
          ClipChromaKeyBackgroundType.transparent,
        );
        expect(restored.backgroundVideoPath, isNull);
      });
    });

    group('equality', () {
      test('compares the background image by path, not by identity', () {
        // `ChromaKey` compares its `EditorLayerImage` by identity — that class
        // has no value equality. The cubit's state is Equatable over this
        // type, so an identity compare would emit a "changed" state for an
        // unchanged key and rebuild the preview shader on every emit.
        final a = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/bg.png')),
        );
        final b = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/bg.png')),
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('separates keys that differ only in tuning', () {
        const a = ClipChromaKey(key: ChromaKey(similarity: 0.15));
        const b = ClipChromaKey(key: ChromaKey(similarity: 0.4));

        expect(a, isNot(b));
      });

      test('separates keys that differ only in backdrop clip', () {
        const a = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a.mp4',
        );
        const b = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/b.mp4',
        );

        expect(a, isNot(b));
      });
    });
  });
}
