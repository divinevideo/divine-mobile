// ABOUTME: Tests for keeping an unfinished camera session before a room flow
// ABOUTME: takes the camera over

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Scaffold, TextButton;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/collab_room/view/collab_room_navigation.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../helpers/test_provider_overrides.dart';

class _Session extends ClipManagerNotifier {
  _Session(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

class _Editor extends VideoEditorNotifier {
  _Editor(this._outcome);

  final DraftSaveOutcome _outcome;
  final saves = <bool>[];

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<DraftSaveOutcome> saveAsDraft({
    bool enforceCreateNewDraft = false,
  }) async {
    saves.add(enforceCreateNewDraft);
    return _outcome;
  }
}

void main() {
  group('keepUnfinishedCameraSession', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final take = DivineVideoClip(
      id: 'take',
      video: EditorVideo.file(File('/take.mp4')),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    Future<bool?> keep(
      WidgetTester tester, {
      required List<DivineVideoClip> clips,
      required _Editor editor,
    }) async {
      bool? kept;
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            clipManagerProvider.overrideWith(() => _Session(clips)),
            videoEditorProvider.overrideWith(() => editor),
          ],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    kept = await keepUnfinishedCameraSession(context, ref),
                child: const Text('keep'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('keep'));
      await tester.pump();
      return kept;
    }

    testWidgets('saves a session with clips as a new draft', (tester) async {
      final editor = _Editor(DraftSaveOutcome.saved);

      final kept = await keep(tester, clips: [take], editor: editor);

      expect(kept, isTrue);
      expect(editor.saves, [isTrue]);
      expect(
        find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('has nothing to keep without clips', (tester) async {
      final editor = _Editor(DraftSaveOutcome.saved);

      final kept = await keep(tester, clips: const [], editor: editor);

      expect(kept, isTrue);
      expect(editor.saves, isEmpty);
    });

    testWidgets('stops the room flow when the session could not be saved', (
      tester,
    ) async {
      final editor = _Editor(DraftSaveOutcome.failed);

      final kept = await keep(tester, clips: [take], editor: editor);

      expect(kept, isFalse);
      expect(find.text(l10n.videoMetadataFailedToSaveSnackbar), findsOneWidget);
    });
  });
}
