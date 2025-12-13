// ABOUTME: Unit tests for EditorState model validating state management and export tracking
// ABOUTME: Tests immutability, copyWith, computed properties, and state transitions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/editor_state.dart';
import 'package:openvine/models/text_overlay.dart';

void main() {
  group('EditorState', () {
    test('should create with default values', () {
      final state = EditorState();

      expect(state.textOverlays, isEmpty);
      expect(state.selectedTextId, isNull);
      expect(state.selectedSoundId, isNull);
      expect(state.isProcessing, isFalse);
      expect(state.exportStage, isNull);
      expect(state.exportProgress, 0.0);
      expect(state.errorMessage, isNull);
    });

    test('should create with provided values', () {
      final overlay = TextOverlay(
        id: 'text1',
        text: 'Hello',
        normalizedPosition: const Offset(0.5, 0.5),
      );

      final state = EditorState(
        textOverlays: [overlay],
        selectedTextId: 'text1',
        selectedSoundId: 'sound1',
        isProcessing: true,
        exportStage: ExportStage.concatenating,
        exportProgress: 0.5,
        errorMessage: 'Test error',
      );

      expect(state.textOverlays, hasLength(1));
      expect(state.textOverlays.first.id, 'text1');
      expect(state.selectedTextId, 'text1');
      expect(state.selectedSoundId, 'sound1');
      expect(state.isProcessing, isTrue);
      expect(state.exportStage, ExportStage.concatenating);
      expect(state.exportProgress, 0.5);
      expect(state.errorMessage, 'Test error');
    });

    group('copyWith', () {
      test('should copy with new text overlays', () {
        final state = EditorState();
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        final newState = state.copyWith(textOverlays: [overlay]);

        expect(newState.textOverlays, hasLength(1));
        expect(newState.textOverlays.first.id, 'text1');
        expect(state.textOverlays, isEmpty); // Original unchanged
      });

      test('should copy with new selected text id', () {
        final state = EditorState();
        final newState = state.copyWith(selectedTextId: 'text1');

        expect(newState.selectedTextId, 'text1');
        expect(state.selectedTextId, isNull);
      });

      test('should copy with null selected text id', () {
        final state = EditorState(selectedTextId: 'text1');
        final newState = state.copyWith(selectedTextId: null);

        expect(newState.selectedTextId, isNull);
      });

      test('should copy with new sound id', () {
        final state = EditorState();
        final newState = state.copyWith(selectedSoundId: 'sound1');

        expect(newState.selectedSoundId, 'sound1');
        expect(state.selectedSoundId, isNull);
      });

      test('should copy with processing state', () {
        final state = EditorState();
        final newState = state.copyWith(isProcessing: true);

        expect(newState.isProcessing, isTrue);
        expect(state.isProcessing, isFalse);
      });

      test('should copy with export stage', () {
        final state = EditorState();
        final newState = state.copyWith(exportStage: ExportStage.mixingAudio);

        expect(newState.exportStage, ExportStage.mixingAudio);
        expect(state.exportStage, isNull);
      });

      test('should copy with export progress', () {
        final state = EditorState();
        final newState = state.copyWith(exportProgress: 0.75);

        expect(newState.exportProgress, 0.75);
        expect(state.exportProgress, 0.0);
      });

      test('should copy with error message', () {
        final state = EditorState();
        final newState = state.copyWith(errorMessage: 'Error occurred');

        expect(newState.errorMessage, 'Error occurred');
        expect(state.errorMessage, isNull);
      });

      test('should copy multiple properties at once', () {
        final state = EditorState();
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );

        final newState = state.copyWith(
          textOverlays: [overlay],
          selectedTextId: 'text1',
          isProcessing: true,
          exportStage: ExportStage.applyingTextOverlay,
          exportProgress: 0.33,
        );

        expect(newState.textOverlays, hasLength(1));
        expect(newState.selectedTextId, 'text1');
        expect(newState.isProcessing, isTrue);
        expect(newState.exportStage, ExportStage.applyingTextOverlay);
        expect(newState.exportProgress, 0.33);
      });
    });

    group('computed properties', () {
      test('hasTextOverlays should return false when empty', () {
        final state = EditorState();
        expect(state.hasTextOverlays, isFalse);
      });

      test('hasTextOverlays should return true when overlays exist', () {
        final overlay = TextOverlay(
          id: 'text1',
          text: 'Hello',
          normalizedPosition: const Offset(0.5, 0.5),
        );
        final state = EditorState(textOverlays: [overlay]);
        expect(state.hasTextOverlays, isTrue);
      });

      test('hasSound should return false when no sound selected', () {
        final state = EditorState();
        expect(state.hasSound, isFalse);
      });

      test('hasSound should return true when sound selected', () {
        final state = EditorState(selectedSoundId: 'sound1');
        expect(state.hasSound, isTrue);
      });

      test('canExport should return true when not processing', () {
        final state = EditorState();
        expect(state.canExport, isTrue);
      });

      test('canExport should return false when processing', () {
        final state = EditorState(isProcessing: true);
        expect(state.canExport, isFalse);
      });

      test('canExport should return false during export', () {
        final state = EditorState(
          isProcessing: true,
          exportStage: ExportStage.concatenating,
        );
        expect(state.canExport, isFalse);
      });
    });

    group('ExportStage enum', () {
      test('should have all required stages', () {
        expect(ExportStage.values, contains(ExportStage.concatenating));
        expect(ExportStage.values, contains(ExportStage.applyingTextOverlay));
        expect(ExportStage.values, contains(ExportStage.mixingAudio));
        expect(ExportStage.values, contains(ExportStage.generatingThumbnail));
        expect(ExportStage.values, contains(ExportStage.complete));
        expect(ExportStage.values, contains(ExportStage.error));
      });

      test('should have exactly 6 stages', () {
        expect(ExportStage.values, hasLength(6));
      });
    });
  });
}
