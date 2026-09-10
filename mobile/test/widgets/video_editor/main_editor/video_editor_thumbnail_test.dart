import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('renders', () {
    testWidgets('VideoEditorThumbnail renders safely with no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorThumbnail(contentSize: Size(120, 120)),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('bounds the thumbnail decode to the content height', (
      tester,
    ) async {
      const contentSize = Size(90, 160);
      final thumbnailPath = '${Directory.systemTemp.path}/editor_thumbnail.png';
      final clip = DivineVideoClip(
        id: 'clip_thumbnail_test',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: thumbnailPath,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _TestClipManagerNotifier([clip]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorThumbnail(contentSize: contentSize),
            ),
          ),
        ),
      );

      // The decode is bounded to the same height (in device pixels) the
      // stop-motion player asks for, so the two share one image-cache entry
      // rather than decoding the raw camera still twice. Asserting on the
      // ResizeImage pins both the bound and the cache key the sharing needs.
      final image = tester.widget<Image>(find.byType(Image)).image;
      expect(
        image,
        isA<ResizeImage>()
            .having(
              (r) => r.height,
              'height',
              (contentSize.height * tester.view.devicePixelRatio).round(),
            )
            .having((r) => r.width, 'width', isNull)
            .having(
              (r) => r.imageProvider,
              'imageProvider',
              isA<FileImage>().having(
                (f) => f.file.path,
                'path',
                thumbnailPath,
              ),
            ),
      );
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier(this._initialClips);

  final List<DivineVideoClip> _initialClips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _initialClips);
}
