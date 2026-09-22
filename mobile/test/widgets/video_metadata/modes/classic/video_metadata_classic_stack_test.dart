import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_editor/video_render_failure_reason.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_preview_thumbnail.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_stack.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_render_failure_banner.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoMetadataClassicStack, () {
    late DivineVideoClip testClip;

    setUp(() {
      testClip = DivineVideoClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        thumbnailPath: 'test_thumbnail.jpg',
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );
    });

    Widget buildWidget({VideoEditorProviderState? state}) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _MockClipManagerNotifier([testClip]),
          ),
          // The post-time tile reads the feature flag, which otherwise pulls
          // in shared preferences (#3538).
          isFeatureEnabledProvider(
            FeatureFlag.scheduledPosts,
          ).overrideWithValue(true),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(
              state ?? VideoEditorProviderState(),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoMetadataClassicStack(),
        ),
      );
    }

    testWidgetsWithSurfaceSize('renders $VideoMetadataClassicStack', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataClassicStack), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('renders $VideoMetadataClassicAppBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataClassicAppBar), findsOneWidget);
    });

    testWidgetsWithSurfaceSize(
      'renders $VideoMetadataClassicPreviewThumbnail',
      (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byType(VideoMetadataClassicPreviewThumbnail),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithSurfaceSize('renders $VideoMetadataFormFields', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataFormFields), findsOneWidget);
    });

    testWidgetsWithSurfaceSize(
      'explains a render that failed out of storage below the preview '
      '(#7125)',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: VideoEditorProviderState(
              renderFailed: true,
              renderFailureReason: VideoRenderFailureReason.insufficientStorage,
            ),
          ),
        );

        expect(find.byType(VideoMetadataRenderFailureBanner), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).publishErrorLowStorage,
          ),
          findsOneWidget,
          reason:
              'the stack must mount the banner, or an out-of-storage user '
              'only reads "Generation failed"',
        );
      },
    );

    testWidgetsWithSurfaceSize('renders $VideoMetadataClassicBottomBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataClassicBottomBar), findsOneWidget);
    });

    testWidgetsWithSurfaceSize('uses correct background color', (tester) async {
      await tester.pumpWidget(buildWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(VineTheme.surfaceContainerHigh));
    });

    testWidgetsWithSurfaceSize('body scroll dismisses the keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    testWidgetsWithSurfaceSize(
      '$VideoMetadataFormFields keeps the full post controls available',
      (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final formFields = tester.widget<VideoMetadataFormFields>(
          find.byType(VideoMetadataFormFields),
        );
        expect(formFields.enableTags, isTrue);
        expect(formFields.enableExpiration, isTrue);
        expect(formFields.enableContentWarning, isTrue);
        expect(formFields.enableCollaborators, isTrue);
        expect(formFields.enableInspiredBy, isTrue);
        expect(formFields.enableVideoReply, isTrue);
      },
    );
  });
}

void testWidgetsWithSurfaceSize(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await callback(tester);
  });
}

class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
