// ABOUTME: Tests for the page naming clips saved to the gallery without their
// ABOUTME: proof: why each one has none, and saving again once it can be added.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clip_gallery_save/clip_gallery_save_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/clip_gallery_save/clip_gallery_save_warning_page.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockClipProvenanceVerifier extends Mock
    implements ClipProvenanceVerifier {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/clips/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(ClipGallerySaveWarningView, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockGallerySaveService gallery;
    late _MockClipProvenanceVerifier verifier;

    setUp(() {
      gallery = _MockGallerySaveService();
      verifier = _MockClipProvenanceVerifier();
      when(
        () => gallery.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySaveSuccess());
    });

    Future<ClipGallerySaveCubit> pumpView(
      WidgetTester tester,
      Map<String, ClipGallerySaveWarning> warnings,
    ) async {
      final cubit = ClipGallerySaveCubit(
        gallerySaveService: gallery,
        verifier: verifier,
        signOwnClips: (_) async => {},
        results: [
          for (final MapEntry(key: id, value: warning) in warnings.entries)
            ClipGallerySaveResult(_clip(id), saved: true, warning: warning),
        ],
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider.value(
            value: cubit,
            child: const ClipGallerySaveWarningView(),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('says why each clip has no proof', (tester) async {
      await pumpView(tester, {
        'stills': ClipGallerySaveWarning.stopMotion,
        'imported': ClipGallerySaveWarning.noProof,
        'altered': ClipGallerySaveWarning.notVerified,
        'debug': ClipGallerySaveWarning.signingUnsupported,
      });

      expect(find.text(l10n.libraryGallerySaveWarningIntro), findsOneWidget);
      expect(
        find.text(l10n.libraryGallerySaveWarningStopMotion),
        findsOneWidget,
      );
      expect(find.text(l10n.libraryGallerySaveWarningNoProof), findsOneWidget);
      expect(
        find.text(l10n.libraryGalleryImportItemNotVerified),
        findsOneWidget,
      );
      expect(
        find.text(l10n.libraryGallerySaveWarningSigningUnsupported),
        findsOneWidget,
      );
      // None of these can get their proof by being saved again.
      expect(find.text(l10n.commonRetry), findsNothing);
    });

    testWidgets('saves a copy with proof once it can be added', (
      tester,
    ) async {
      when(() => verifier.verify('/clips/offline.mp4')).thenAnswer(
        (_) async => const ClipProvenanceResult(ClipProvenanceStatus.verified),
      );
      await pumpView(tester, {
        'offline': ClipGallerySaveWarning.signingUnavailable,
      });
      expect(
        find.text(l10n.libraryGallerySaveWarningSigningUnavailable),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      verify(() => gallery.saveVideoToGallery(any())).called(1);
      expect(
        find.text(l10n.libraryGallerySaveWarningSavedWithProof),
        findsOneWidget,
      );
      expect(find.text(l10n.commonRetry), findsNothing);
    });
  });
}
