import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_stack.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoMetadataCaptureStack, () {
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

    Widget buildWidget({
      TextScaler textScaler = TextScaler.noScaling,
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _MockClipManagerNotifier([testClip]),
          ),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(VideoEditorProviderState()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: textScaler,
                viewInsets: viewInsets,
              ),
              child: child!,
            );
          },
          home: const VideoMetadataCaptureStack(),
        ),
      );
    }

    testWidgets('renders $VideoMetadataCaptureStack', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureStack), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataCaptureAppBar', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureAppBar), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataCaptureClipPreview', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureClipPreview), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataFormFields', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataFormFields), findsOneWidget);
    });

    testWidgets('renders $VideoMetadataCaptureBottomBar', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataCaptureBottomBar), findsOneWidget);
    });

    testWidgets('uses correct background color', (tester) async {
      await tester.pumpWidget(buildWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(VineTheme.surfaceContainerHigh));
    });

    testWidgets('body scroll dismisses the keyboard', (tester) async {
      await tester.pumpWidget(buildWidget());

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    testWidgets('a drag notification from the description dismisses keyboard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildWidget(
          textScaler: const TextScaler.linear(1.35),
          viewInsets: const EdgeInsets.only(bottom: 336),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final description = find.byWidgetPredicate(
        (widget) =>
            widget is DivineTextField && widget.labelText == 'Description',
      );
      await tester.enterText(
        description,
        List.generate(40, (index) => 'description line $index').join('\n'),
      );
      await tester.pump(const Duration(seconds: 1));

      final descriptionField = tester.widget<DivineTextField>(description);
      expect(descriptionField.focusNode?.hasFocus, isTrue);

      final editable = find.descendant(
        of: description,
        matching: find.byType(EditableText),
      );
      final outerScrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final initialOffset = outerScrollable.position.pixels;

      final editableContext = tester.element(editable);
      final descriptionScrollable = tester.state<ScrollableState>(
        find.descendant(of: description, matching: find.byType(Scrollable)),
      );
      ScrollUpdateNotification(
        metrics: descriptionScrollable.position,
        context: editableContext,
        scrollDelta: 10,
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(0, -10),
        ),
      ).dispatch(editableContext);
      await tester.pump();

      // The description consumes this drag to scroll its own text. Dismissing
      // the keyboard is intentional: it restores the viewport so the next
      // page drag can reach Tags and the remaining metadata controls.
      expect(outerScrollable.position.pixels, initialOffset);
      expect(descriptionField.focusNode?.hasFocus, isFalse);
    });
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
