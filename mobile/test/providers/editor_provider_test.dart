// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/editor_state.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/providers/editor_provider.dart';

void main() {
  group('EditorProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide initial state', () {
      final state = container.read(editorProvider);

      expect(state.textOverlays, isEmpty);
      expect(state.selectedTextId, isNull);
      expect(state.selectedSoundId, isNull);
      expect(state.isProcessing, isFalse);
      expect(state.exportStage, isNull);
      expect(state.exportProgress, 0.0);
      expect(state.errorMessage, isNull);
    });

    group('addTextOverlay', () {
      test('should add text overlay to state', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        notifier.addTextOverlay(overlay);

        final state = container.read(editorProvider);
        expect(state.textOverlays, hasLength(1));
        expect(state.textOverlays.first.id, 'text1');
        expect(state.textOverlays.first.text, 'Hello');
      });

      test('should add multiple text overlays', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay1 = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );
        final overlay2 = TextOverlay(
          id: 'text2',
          text: 'World',
          normalizedPosition: const Offset(0.3, 0.3),
        );

        notifier.addTextOverlay(overlay1);
        notifier.addTextOverlay(overlay2);

        final state = container.read(editorProvider);
        expect(state.textOverlays, hasLength(2));
        expect(state.textOverlays[0].id, 'text1');
        expect(state.textOverlays[1].id, 'text2');
      });
    });

    group('updateTextOverlay', () {
      test('should update existing text overlay', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        notifier.addTextOverlay(overlay);

        final updatedOverlay = overlay.copyWith(
          text: 'Updated',
          fontSize: 48.0,
        );
        notifier.updateTextOverlay('text1', updatedOverlay);

        final state = container.read(editorProvider);
        expect(state.textOverlays, hasLength(1));
        expect(state.textOverlays.first.text, 'Updated');
        expect(state.textOverlays.first.fontSize, 48.0);
      });

      test('should not add overlay if id not found', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        notifier.updateTextOverlay('nonexistent', overlay);

        final state = container.read(editorProvider);
        expect(state.textOverlays, isEmpty);
      });

      test('should update correct overlay when multiple exist', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay1 = TextOverlay(
          id: 'text1',
          text: 'First',
          normalizedPosition: const Offset(0.5, 0.5),
        );
        final overlay2 = TextOverlay(
          id: 'text2',
          text: 'Second',
          normalizedPosition: const Offset(0.3, 0.3),
        );

        notifier.addTextOverlay(overlay1);
        notifier.addTextOverlay(overlay2);

        final updatedOverlay = overlay2.copyWith(text: 'Updated Second');
        notifier.updateTextOverlay('text2', updatedOverlay);

        final state = container.read(editorProvider);
        expect(state.textOverlays, hasLength(2));
        expect(state.textOverlays[0].text, 'First');
        expect(state.textOverlays[1].text, 'Updated Second');
      });
    });

    group('removeTextOverlay', () {
      test('should remove text overlay by id', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        notifier.addTextOverlay(overlay);
        notifier.removeTextOverlay('text1');

        final state = container.read(editorProvider);
        expect(state.textOverlays, isEmpty);
      });

      test('should not error when removing nonexistent id', () {
        final notifier = container.read(editorProvider.notifier);

        expect(() => notifier.removeTextOverlay('nonexistent'), returnsNormally);

        final state = container.read(editorProvider);
        expect(state.textOverlays, isEmpty);
      });

      test('should remove correct overlay when multiple exist', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay1 = TextOverlay(
          id: 'text1',
          text: 'First',
          normalizedPosition: const Offset(0.5, 0.5),
        );
        final overlay2 = TextOverlay(
          id: 'text2',
          text: 'Second',
          normalizedPosition: const Offset(0.3, 0.3),
        );

        notifier.addTextOverlay(overlay1);
        notifier.addTextOverlay(overlay2);
        notifier.removeTextOverlay('text1');

        final state = container.read(editorProvider);
        expect(state.textOverlays, hasLength(1));
        expect(state.textOverlays.first.id, 'text2');
      });

      test('should clear selectedTextId if removed overlay was selected', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        notifier.addTextOverlay(overlay);
        notifier.selectText('text1');
        notifier.removeTextOverlay('text1');

        final state = container.read(editorProvider);
        expect(state.selectedTextId, isNull);
      });
    });

    group('selectText', () {
      test('should select text by id', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.selectText('text1');

        final state = container.read(editorProvider);
        expect(state.selectedTextId, 'text1');
      });

      test('should deselect text when null provided', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.selectText('text1');
        notifier.selectText(null);

        final state = container.read(editorProvider);
        expect(state.selectedTextId, isNull);
      });

      test('should change selection', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.selectText('text1');
        notifier.selectText('text2');

        final state = container.read(editorProvider);
        expect(state.selectedTextId, 'text2');
      });
    });

    group('setSound', () {
      test('should set sound id', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setSound('sound1');

        final state = container.read(editorProvider);
        expect(state.selectedSoundId, 'sound1');
      });

      test('should clear sound when null provided', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setSound('sound1');
        notifier.setSound(null);

        final state = container.read(editorProvider);
        expect(state.selectedSoundId, isNull);
      });

      test('should change sound selection', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setSound('sound1');
        notifier.setSound('sound2');

        final state = container.read(editorProvider);
        expect(state.selectedSoundId, 'sound2');
      });
    });

    group('setExportStage', () {
      test('should set export stage and progress', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.concatenating, 0.25);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.concatenating);
        expect(state.exportProgress, 0.25);
        expect(state.isProcessing, isTrue);
      });

      test('should update stage and progress', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.concatenating, 0.25);
        notifier.setExportStage(ExportStage.mixingAudio, 0.75);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.mixingAudio);
        expect(state.exportProgress, 0.75);
        expect(state.isProcessing, isTrue);
      });

      test('should set isProcessing true during export', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.applyingTextOverlay, 0.5);

        final state = container.read(editorProvider);
        expect(state.isProcessing, isTrue);
      });

      test('should clear error when setting export stage', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setError('Previous error');
        notifier.setExportStage(ExportStage.concatenating, 0.0);

        final state = container.read(editorProvider);
        expect(state.errorMessage, isNull);
      });

      test('should complete export when stage is complete', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.complete, 1.0);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.complete);
        expect(state.exportProgress, 1.0);
        expect(state.isProcessing, isFalse);
      });

      test('should stop processing when stage is error', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.error, 0.5);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.error);
        expect(state.isProcessing, isFalse);
      });
    });

    group('setError', () {
      test('should set error message', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setError('Export failed');

        final state = container.read(editorProvider);
        expect(state.errorMessage, 'Export failed');
        expect(state.exportStage, ExportStage.error);
        expect(state.isProcessing, isFalse);
      });

      test('should clear error when null provided', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setError('Error');
        notifier.setError(null);

        final state = container.read(editorProvider);
        expect(state.errorMessage, isNull);
      });
    });

    group('reset', () {
      test('should reset to initial state', () {
        final notifier = container.read(editorProvider.notifier);
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        notifier.addTextOverlay(overlay);
        notifier.selectText('text1');
        notifier.setSound('sound1');
        notifier.setExportStage(ExportStage.concatenating, 0.5);
        notifier.setError('Test error');

        notifier.reset();

        final state = container.read(editorProvider);
        expect(state.textOverlays, isEmpty);
        expect(state.selectedTextId, isNull);
        expect(state.selectedSoundId, isNull);
        expect(state.isProcessing, isFalse);
        expect(state.exportStage, isNull);
        expect(state.exportProgress, 0.0);
        expect(state.errorMessage, isNull);
      });
    });
  });
}
